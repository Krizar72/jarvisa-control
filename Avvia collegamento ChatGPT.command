#!/bin/bash
set -euo pipefail
jarvisa_project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
exec /bin/bash "$jarvisa_project_dir/scripts/connect-chatgpt.sh"
