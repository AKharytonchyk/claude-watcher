#!/bin/bash
# Compile the Swift sources and wrap the binary in a .app bundle.
# Uses swiftc directly (works with just the Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"

APP="ClaudeWatcher.app"
BIN_NAME="ClaudeWatcher"

echo "▸ compiling"
swiftc -O -framework AppKit -framework SwiftUI -framework CoreServices Sources/ClaudeWatcher/*.swift -o "$BIN_NAME"

echo "▸ assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mv "$BIN_NAME" "$APP/Contents/MacOS/$BIN_NAME"
cp Info.plist "$APP/Contents/Info.plist"

# Code signature. For a release, set CWATCH_SIGN_IDENTITY to a "Developer ID
# Application" identity — signs with Hardened Runtime + a secure timestamp (both
# required for notarization) and, if given, an entitlements file. Otherwise
# ad-hoc sign so local dev builds still launch without a certificate.
if [ -n "${CWATCH_SIGN_IDENTITY:-}" ]; then
  echo "▸ signing: $CWATCH_SIGN_IDENTITY"
  codesign --force --options runtime --timestamp \
    ${CWATCH_ENTITLEMENTS:+--entitlements "$CWATCH_ENTITLEMENTS"} \
    --sign "$CWATCH_SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
else
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "✓ built $APP"
echo "  run:  open $APP"
echo "  logs: ./$APP/Contents/MacOS/$BIN_NAME   (runs in foreground)"
