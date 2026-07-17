#!/bin/bash
# Build a signed, notarized, stapled DMG (drag-to-Applications) from the .app.
# Usage: ./release.sh   → ClaudeWatcher-<version>.dmg + its sha256
#
# One-time setup:
#   - A "Developer ID Application" certificate in your login keychain.
#   - A notarytool keychain profile (default "cw-notary"):
#       xcrun notarytool store-credentials "cw-notary" \
#         --key AuthKey_XXXX.p8 --key-id KEYID --issuer ISSUER-UUID
# Overrides: CWATCH_SIGN_IDENTITY (identity string), CWATCH_NOTARY_PROFILE.
set -euo pipefail
cd "$(dirname "$0")"

APP="ClaudeWatcher.app"
ENT="$(pwd)/ClaudeWatcher.entitlements"
NOTARY_PROFILE="${CWATCH_NOTARY_PROFILE:-cw-notary}"

# Resolve the Developer ID signing identity (explicit override or auto-detect).
SIGN_ID="${CWATCH_SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
  | awk -F'"' '/Developer ID Application/{print $2; exit}')}"
if [ -z "$SIGN_ID" ]; then
  echo "✗ No 'Developer ID Application' identity found. Install your Developer ID" >&2
  echo "  certificate, or set CWATCH_SIGN_IDENTITY explicitly." >&2
  exit 1
fi
echo "▸ signing identity: $SIGN_ID"
echo "▸ notary profile:   $NOTARY_PROFILE"

# 1) Build + sign (Hardened Runtime + timestamp + entitlements).
CWATCH_SIGN_IDENTITY="$SIGN_ID" CWATCH_ENTITLEMENTS="$ENT" ./build-app.sh >/dev/null
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || echo "0.0.0")
DMG="ClaudeWatcher-${VERSION}.dmg"
echo "✓ built + signed $APP (v$VERSION)"

# 2) Notarize the app and staple it, so the .app carries its own ticket — the
#    Homebrew cask extracts the .app from the DMG, so it needs to be stapled.
echo "▸ notarizing $APP (this waits on Apple; ~1-3 min) …"
ZIPDIR="$(mktemp -d)"; ZIP="$ZIPDIR/ClaudeWatcher.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
rm -rf "$ZIPDIR"

# 3) Package the stapled app into a drag-install DMG.
echo "▸ packaging $DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # drag-install target
rm -f "$DMG"
hdiutil create -volname "Claude Watcher" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

# 4) Notarize + staple the DMG too, for the direct-download path.
echo "▸ notarizing $DMG …"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

# 5) Verify Gatekeeper accepts both, offline.
echo "▸ verifying …"
spctl --assess --type execute -vv "$APP"
spctl --assess --type open --context context:primary-signature -vv "$DMG"

echo "✓ built $DMG (signed · notarized · stapled)"
echo "  sha256: $(shasum -a 256 "$DMG" | awk '{print $1}')"
echo
echo "Next: create a GitHub release and attach the DMG, e.g."
echo "  gh release create v${VERSION} \"$DMG\" --title \"v${VERSION}\" --notes-from-tag"
echo "Then bump Casks/claude-watcher.rb (version + sha256). Now that the build is"
echo "notarized, you can also drop the postflight 'xattr' quarantine strip."
