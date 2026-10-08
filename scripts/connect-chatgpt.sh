#!/bin/bash
set -euo pipefail

jarvisa_support_dir="$HOME/Library/Application Support/JarvisaControl"
jarvisa_tunnel_bin="$jarvisa_support_dir/tunnel-client/tunnel-client"
jarvisa_app_path="${JARVISA_APP_PATH:-$HOME/Applications/Jarvisa Control.app}"
jarvisa_mcp_executable="$jarvisa_app_path/Contents/MacOS/JarvisaControl"

if [[ ! -x "$jarvisa_tunnel_bin" || ! -x "$jarvisa_mcp_executable" ]]; then
    echo 'Manca il client ufficiale del tunnel o Jarvisa Control.' >&2
    exit 1
fi
if [[ ! -t 0 ]]; then
    echo 'Esegui questo script in Terminale per inserire la chiave localmente.' >&2
    exit 1
fi
jarvisa_tunnel_id="${JARVISA_TUNNEL_ID:-}"
if [[ -z "$jarvisa_tunnel_id" && -f "$jarvisa_support_dir/tunnel-id" ]]; then
    IFS= read -r jarvisa_tunnel_id < "$jarvisa_support_dir/tunnel-id"
fi
if [[ -z "$jarvisa_tunnel_id" ]]; then
    read -r -p 'ID del tunnel creato in OpenAI Platform: ' jarvisa_tunnel_id
fi
if [[ ! "$jarvisa_tunnel_id" =~ ^tunnel_[A-Za-z0-9_-]+$ ]]; then
    echo 'ID del tunnel non valido.' >&2
    exit 1
fi
if [[ -z "${CONTROL_PLANE_API_KEY:-}" ]]; then
    read -r -s -p 'Incolla la chiave runtime OpenAI e premi Invio (non viene mostrata): ' CONTROL_PLANE_API_KEY
    echo
fi
if [[ -z "$CONTROL_PLANE_API_KEY" ]]; then
    echo 'Chiave runtime mancante.' >&2
    exit 1
fi
export CONTROL_PLANE_API_KEY
trap 'unset CONTROL_PLANE_API_KEY' EXIT

"$jarvisa_tunnel_bin" runtimes connect \
    --alias jarvisa-control --profile jarvisa-control \
    --tunnel-id "$jarvisa_tunnel_id" \
    --runtime-api-key env:CONTROL_PLANE_API_KEY \
    --mcp-command "\"$jarvisa_mcp_executable\" --mcp" --json
"$jarvisa_tunnel_bin" runtimes status jarvisa-control --json
