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

# Ad-hoc code signature so macOS is happy launching it locally.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ built $APP"
echo "  run:  open $APP"
echo "  logs: ./$APP/Contents/MacOS/$BIN_NAME   (runs in foreground)"
