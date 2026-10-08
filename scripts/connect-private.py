#!/usr/bin/env python3
"""Receive one credential via a private local socket; never save its value."""
import json
import os
import pathlib
import shutil
import socket
import subprocess
import tempfile

support = pathlib.Path.home() / 'Library/Application Support/JarvisaControl'
client = support / 'tunnel-client/tunnel-client'
tunnel_id = (support / 'tunnel-id').read_text().strip()
app = pathlib.Path.home() / 'Applications/Jarvisa Control.app/Contents/MacOS/JarvisaControl'
directory = pathlib.Path(tempfile.mkdtemp(prefix='jarvisa-connect-', dir='/tmp'))
directory.chmod(0o700)
path = directory / 'credential.sock'
listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
listener.bind(str(path))
path.chmod(0o600)
listener.listen(1)
listener.settimeout(120)
print(json.dumps({'socketPath':str(path)}),flush=True)
try:
    connection, _ = listener.accept()
    connection.settimeout(10)
    chunks = []
    with connection:
        while True:
            chunk = connection.recv(4096)
            if not chunk:
                break
            chunks.append(chunk)
            if sum(map(len,chunks)) > 8192:
                raise ValueError('Credential exceeds expected length')
    key = b''.join(chunks).decode('ascii').strip()
    if not key.startswith('sk-') or len(key) < 30 or any(c.isspace() for c in key):
        raise ValueError('Invalid credential format')
    environment = os.environ.copy()
    environment['CONTROL_PLANE_API_KEY'] = key
    command = [str(client),'runtimes','connect','--alias','jarvisa-control','--profile','jarvisa-control',
               '--tunnel-id',tunnel_id,'--runtime-api-key','env:CONTROL_PLANE_API_KEY',
               '--mcp-command','"%s" --mcp' % app,'--json']
    result = subprocess.run(command,env=environment,capture_output=True,text=True,timeout=70)
    def summary(result):
        try:
            data = json.loads(result.stdout)
            names = ['alias','healthy','ready','process_running','runtime_state','error','remote_error','ui_url']
            return {name:data[name] for name in names if name in data}
        except ValueError:
            return {'error':result.stderr.replace(key,'[REDACTED]')[-1200:]}
    print(json.dumps({'connectExitCode':result.returncode,'status':summary(result)}),flush=True)
    if result.returncode == 0:
        result = subprocess.run([str(client),'runtimes','status','jarvisa-control','--json'],
                                env=environment,capture_output=True,text=True,timeout=25)
        print(json.dumps({'statusExitCode':result.returncode,'status':summary(result)}),flush=True)
    environment.pop('CONTROL_PLANE_API_KEY',None)
    key = ''
finally:
    listener.close()
    shutil.rmtree(directory)
