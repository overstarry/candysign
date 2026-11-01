#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_image="Resources/AppIcon-v1.png"
iconset=".build/icons/AppIcon-v1.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$source_image" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$source_image" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Resources/AppIcon-v1.icns
