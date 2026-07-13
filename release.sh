#!/bin/bash
# Build a distributable DMG (drag-to-Applications) from the .app.
# Usage: ./release.sh   → ClaudeWatcher-<version>.dmg + its sha256
set -euo pipefail
cd "$(dirname "$0")"

./build-app.sh >/dev/null
APP="ClaudeWatcher.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || echo "0.0.0")
DMG="ClaudeWatcher-${VERSION}.dmg"

echo "▸ packaging $DMG (v$VERSION)"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # drag-install target
rm -f "$DMG"
hdiutil create -volname "Claude Watcher" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "✓ built $DMG"
echo "  sha256: $(shasum -a 256 "$DMG" | awk '{print $1}')"
echo
echo "Next: create a GitHub release and attach the DMG, e.g."
echo "  gh release create v${VERSION} \"$DMG\" --title \"v${VERSION}\" --notes-from-tag"
echo "Then update Casks/claude-watcher.rb (version + sha256) in your tap."
