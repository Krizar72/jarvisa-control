#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
mkdir -p "$project_dir/.build"
xcrun swiftc -swift-version 5 "$project_dir/Sources/ControlCore.swift" "$project_dir/Tests/main.swift" \
    -o "$project_dir/.build/CoreTests"
"$project_dir/.build/CoreTests"
