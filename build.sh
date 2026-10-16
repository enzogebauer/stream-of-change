#!/bin/bash
# Builds "Stream of change.app" and puts it on your Desktop.
# Requires Xcode command line tools (xcode-select --install).
set -e
cd "$(dirname "$0")"
swift build -c release

APP="$HOME/Desktop/Stream of change.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/StreamOfChange "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/Info.plist"

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
touch "$APP"
echo "Built: $APP"
