#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
output_app="$project_dir/dist/Jarvisa Control.app"
target_arch="${1:-$(uname -m)}"
sdk_path="$(xcrun --show-sdk-path)"
mkdir -p "$output_app/Contents/MacOS" "$output_app/Contents/Resources" "$project_dir/.build"
cp "$project_dir/Info.plist" "$output_app/Contents/Info.plist"
if [[ "$target_arch" == "universal" ]]; then
    for arch in x86_64 arm64; do
        xcrun swiftc -swift-version 5 -O -whole-module-optimization -sdk "$sdk_path" -target "$arch-apple-macos13.0" \
            "$project_dir"/Sources/*.swift -o "$project_dir/.build/JarvisaControl-$arch"
    done
    lipo -create "$project_dir/.build/JarvisaControl-x86_64" "$project_dir/.build/JarvisaControl-arm64" \
        -output "$output_app/Contents/MacOS/JarvisaControl"
else
    xcrun swiftc -swift-version 5 -O -whole-module-optimization -sdk "$sdk_path" -target "$target_arch-apple-macos13.0" \
        "$project_dir"/Sources/*.swift -o "$output_app/Contents/MacOS/JarvisaControl"
fi
xattr -cr "$output_app"
codesign --force --sign - --identifier it.krizar.jarvisa-control "$output_app"
printf '%s\n' "$output_app"
