#!/usr/bin/env python3
"""Exercise the installed native server over its actual stdio transport."""
import argparse
import base64
import json
import os
import pathlib
import select
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--app', default=str(pathlib.Path.home() / 'Applications/Jarvisa Control.app'))
parser.add_argument('--output', default='verification-mcp')
parser.add_argument('--live-input', action='store_true')
opts = parser.parse_args()
out = pathlib.Path(opts.output)
out.mkdir(parents=True, exist_ok=True)
stderr = (out / 'server.stderr.log').open('wb')
proc = subprocess.Popen([opts.app + '/Contents/MacOS/JarvisaControl', '--mcp'],
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr)
buffer = b''
counter = 0
report = {'checks': [], 'nativeInputTest': 'not_requested'}

def send(method, params=None, request_id=None):
    global counter
    if request_id is None:
        counter += 1
        request_id = counter
    obj = {'jsonrpc': '2.0', 'id': request_id, 'method': method}
    if params is not None:
        obj['params'] = params
    proc.stdin.write(json.dumps(obj, ensure_ascii=False).encode() + b'\n')
    proc.stdin.flush()
    return request_id

def receive(timeout=25):
    global buffer
    deadline = time.monotonic() + timeout
    while b'\n' not in buffer:
        if time.monotonic() >= deadline:
            raise TimeoutError('MCP response timeout')
        ready, _, _ = select.select([proc.stdout], [], [], max(0, deadline-time.monotonic()))
        if ready:
            chunk = os.read(proc.stdout.fileno(), 65536)
            if not chunk:
                raise RuntimeError('MCP server closed stdout')
            buffer += chunk
    line, buffer = buffer.split(b'\n', 1)
    return json.loads(line)

def request(method, params=None):
    request_id = send(method, params)
    response = receive()
    assert response['id'] == request_id, response
    return response

def call(name, arguments=None):
    response = request('tools/call', {'name': name, 'arguments': arguments or {}})
    assert 'result' in response, response
    return response['result']

def check(label, condition):
    assert condition, label
    report['checks'].append(label)

try:
    check('requires initialization', request('tools/list')['error']['code'] == -32000)
    check('modern discovery falls back explicitly', request('server/discover')['error']['code'] == -32601)
    init = request('initialize', {'protocolVersion': '2025-11-25', 'capabilities': {},
                                'clientInfo': {'name': 'jarvisa-verification', 'version': '1'}})
    check('legacy negotiation', init['result']['protocolVersion'] == '2025-11-25')
    proc.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
    proc.stdin.flush()
    tools = request('tools/list')['result']['tools']
    check('nine discoverable tools', len(tools) == 9)
    report['tools'] = [t['name'] for t in tools]
    status = call('get_status')['structuredContent']
    report['permissions'] = status
    check('control starts disabled', status['controlEnabled'] is False)
    check('input rejected while disabled', call('type_text', {'target_app': 'com.apple.TextEdit', 'text': 'blocked'})['isError'])
    invalid = [('get_status', {'extra': 1}), ('capture_screen', {'display_id': True}),
               ('capture_screen', {'display_id': 0}), ('capture_screen', {'display_id': 2**32}),
               ('mouse', {'target_app': 'com.apple.TextEdit', 'x': -1, 'y': 1, 'action': 'move'}),
               ('type_text', {'target_app': 'com.apple.TextEdit', 'text': ''}),
               ('type_text', {'target_app': 'com.apple.TextEdit', 'text': 'x'*1001})]
    for i, (name, args) in enumerate(invalid):
        response = request('tools/call', {'name': name, 'arguments': args})
        check('invalid arguments rejected %d' % i, response['error']['code'] == -32602)
    check('non-object arguments rejected', request('tools/call', {'name':'get_status', 'arguments':[]})['error']['code'] == -32602)
    report['displays'] = call('list_displays')['structuredContent']
    report['apps'] = call('list_apps')['structuredContent']
    screenshot = call('capture_screen')
    report['capture'] = {'isError': screenshot['isError']}
    if not screenshot['isError']:
        png = base64.b64decode(next(c['data'] for c in screenshot['content'] if c['type'] == 'image'), validate=True)
        check('actual capture returns PNG', png.startswith(b'\x89PNG\r\n\x1a\n'))
        (out/'screen-from-mcp.png').write_bytes(png)
        report['capture'].update(screenshot['structuredContent'])
    else:
        report['capture']['message'] = screenshot['content'][0]['text']
    if opts.live_input and status['inputPermission']:
        # The only document changed is a new scratch document owned by this test.
        subprocess.run(['osascript', '-e', 'tell application "TextEdit"\nactivate\nmake new document with properties {text:""}\nset bounds of front window to {460,230,1100,660}\nend tell'], check=True, capture_output=True)
        check('enable control succeeds', not call('enable_control')['isError'])
        move = call('mouse', {'target_app':'com.apple.TextEdit','x':600,'y':400,'action':'click'})
        check('mouse events posted', not move['isError'])
        marker = 'Jarvisa MCP: è una prova 🎵'
        typed = call('type_text', {'target_app':'com.apple.TextEdit','text':marker})
        check('typing events posted', not typed['isError'])
        actual = subprocess.run(['osascript','-e','tell application "TextEdit" to get text of front document'], check=True,capture_output=True).stdout.decode().rstrip('\n')
        check('native Unicode delivery verified', actual == marker)
        (out/'input-delivered.txt').write_text(actual)
        pending = send('tools/call', {'name':'type_text','arguments':{'target_app':'com.apple.TextEdit','text':'THIS MUST NOT BE TYPED'}})
        time.sleep(.3)
        stopped = send('tools/call', {'name':'stop_control','arguments':{}})
        replies = {r['id']:r for r in [receive(), receive()]}
        check('stop cancels pending input', replies[pending]['result']['isError'])
        check('stop disarms control', replies[stopped]['result']['structuredContent']['controlEnabled'] is False)
        actual = subprocess.run(['osascript','-e','tell application "TextEdit" to get text of front document'], check=True,capture_output=True).stdout.decode().rstrip('\n')
        check('cancelled input leaves document unchanged', actual == marker)
        report['nativeInputTest'] = 'passed'
    elif opts.live_input:
        report['nativeInputTest'] = 'blocked_by_macos_permissions'
    call('stop_control')
finally:
    proc.stdin.close()
    try:
        proc.wait(timeout=8)
    except subprocess.TimeoutExpired:
        proc.terminate()
        proc.wait(timeout=5)
        report['forcedTermination'] = True
    report['exitCode'] = proc.returncode
    (out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    stderr.close()
print(json.dumps({'checks':len(report['checks']), 'permissions':report.get('permissions'),
                  'capture':report.get('capture'), 'nativeInputTest':report['nativeInputTest'],
                  'exitCode':report['exitCode']},ensure_ascii=False))
