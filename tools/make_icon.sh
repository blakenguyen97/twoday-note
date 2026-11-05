#!/bin/zsh
# Builds Resources/AppIcon.icns from Icon/AppIcon.iconset (PNGs, 16 to 1024 px)
# with iconutil, which ships with macOS. build.sh runs this when a PNG changed.
set -euo pipefail
repo=${0:A:h:h}
mkdir -p "$repo/Resources"
iconutil -c icns "$repo/Icon/AppIcon.iconset" -o "$repo/Resources/AppIcon.icns"
echo "wrote Resources/AppIcon.icns"
