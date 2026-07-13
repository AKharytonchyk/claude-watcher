# Distributing Claude Watcher

## TL;DR

```sh
./release.sh                       # → ClaudeWatcher-<version>.dmg + sha256
gh release create v0.1.0 ClaudeWatcher-0.1.0.dmg --title v0.1.0 --generate-notes
# then bump version + sha256 in Casks/claude-watcher.rb (and your tap)
```

## Cutting a release

1. Bump `CFBundleShortVersionString` in `Info.plist` and add a
   `CHANGELOG.md` entry.
2. `./release.sh` — builds the `.app`, wraps it in a drag-to-Applications DMG,
   and prints the sha256.
3. Tag and publish, attaching the DMG:
   ```sh
   git tag v0.1.0 && git push --tags
   gh release create v0.1.0 ClaudeWatcher-0.1.0.dmg --title v0.1.0 --generate-notes
   ```

## Homebrew cask

The cask source of truth is [`Casks/claude-watcher.rb`](../Casks/claude-watcher.rb).
To make `brew install --cask claude-watcher` work:

1. Create a public repo named **`homebrew-claude-watcher`**.
2. Put the cask at `Casks/claude-watcher.rb`, updating `version` + `sha256`.
3. Users then run:
   ```sh
   brew tap AKharytonchyk/claude-watcher
   brew install --cask claude-watcher
   ```

The cask clears the quarantine attribute in `postflight` so an unsigned build
still launches (see below).

## Code signing & notarization (important)

The DMG produced by `release.sh` is **ad-hoc signed and not notarized**. On
another Mac, Gatekeeper will warn ("Apple could not verify…") and may refuse to
open it. Options, cheapest first:

- **Nothing (works, with friction).** Tell users to right-click → Open the
  first time, or run:
  ```sh
  xattr -dr com.apple.quarantine /Applications/ClaudeWatcher.app
  ```
  The Homebrew cask does this automatically.
- **Notarize (removes the warning).** Requires an Apple Developer account
  ($99/yr). Once you have a "Developer ID Application" certificate:
  ```sh
  codesign --deep --force --options runtime \
    --sign "Developer ID Application: <NAME> (<TEAMID>)" ClaudeWatcher.app
  # build the DMG (release.sh), then:
  xcrun notarytool submit ClaudeWatcher-<v>.dmg \
    --apple-id <APPLE_ID> --team-id <TEAMID> --password <APP_SPECIFIC_PW> --wait
  xcrun stapler staple ClaudeWatcher-<v>.dmg
  ```
  After stapling, the DMG opens with no warning and the cask no longer needs the
  quarantine workaround.

Until you have a Developer ID, ship unsigned + the quarantine note — that's what
many small menu-bar tools do.
