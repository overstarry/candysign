#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
case "$configuration" in release|debug) ;; *) exit 2 ;; esac
swift build -c "$configuration" --product CandySign
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
bundle="$(pwd)/dist/CandySign.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$binary_dir/CandySign" "$bundle/Contents/MacOS/CandySign"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
cp Resources/AppIcon-v1.icns "$bundle/Contents/Resources/AppIcon-v1.icns"
ditto "$binary_dir/CandySign_CandySignCore.bundle" "$bundle/Contents/Resources/CandySign_CandySignCore.bundle"
codesign --force --sign - --identifier com.candysign.CandySign "$bundle"
printf '%s\n' "$bundle"
