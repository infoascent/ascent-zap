#!/bin/bash
# One-shot install: builds Ascent Zap from source and installs it into /Applications (or $INSTALL_DIR).
set -euo pipefail
cd "$(dirname "$0")"
DEST="${INSTALL_DIR:-/Applications}"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools missing. Launching installer: accept the popup, then re-run ./install.sh"
  xcode-select --install || true
  exit 1
fi

./build.sh
osascript -e 'quit app "Ascent Zap"' >/dev/null 2>&1 || true
rm -rf "$DEST/Ascent Zap.app"
cp -R "build/Ascent Zap.app" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/Ascent Zap.app" 2>/dev/null || true
[ "$DEST" = "/Applications" ] && open "$DEST/Ascent Zap.app"
echo "Installed: $DEST/Ascent Zap.app (bolt icon in the menu bar)"
