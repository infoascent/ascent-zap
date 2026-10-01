#!/bin/bash
# Builds a universal (Apple Silicon + Intel) Ascent Zap.app and a DMG into ./build
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Ascent Zap.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts" build/obj

for arch in arm64 x86_64; do
  swiftc -O -target $arch-apple-macos12.0 -module-name AscentZap \
    -framework AppKit -framework Carbon Sources/*.swift -o build/obj/AscentZap-$arch
done
lipo -create build/obj/AscentZap-arm64 build/obj/AscentZap-x86_64 -output "$APP/Contents/MacOS/AscentZap"

cp Resources/Info.plist "$APP/Contents/"
cp Resources/Fonts/*.ttf "$APP/Contents/Resources/Fonts/"

# App icon
ICONSET=build/obj/AppIcon.iconset && mkdir -p $ICONSET
swift scripts/make-icon.swift build/obj/icon1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/obj/icon1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) build/obj/icon1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"

# DMG with an Applications shortcut
STAGE=build/obj/dmg && mkdir -p $STAGE && cp -R "$APP" $STAGE/ && ln -s /Applications $STAGE/Applications
hdiutil create -volname "Ascent Zap" -srcfolder $STAGE -ov -format UDZO build/AscentZap-mac.dmg >/dev/null
echo "Built: $APP and build/AscentZap-mac.dmg"
