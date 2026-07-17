# Distributing Claude Watcher

Releases are **Developer ID-signed, notarized by Apple, and stapled**, so they
open with no Gatekeeper warning and need no quarantine workaround. `release.sh`
runs the whole pipeline.

## TL;DR

```sh
./release.sh          # build → sign → notarize → staple → verify; prints the DMG sha256
gh release create v0.3.0 ClaudeWatcher-0.3.0.dmg --title v0.3.0 --notes-file NOTES.md
# then set version + sha256 in Casks/claude-watcher.rb AND the homebrew-claude-watcher tap
```

## One-time setup (signing + notarization)

Needs an Apple Developer account ($99/yr) and two things on the build Mac:

1. A **Developer ID Application** certificate in your login keychain. Generate a
   CSR in Keychain Access (Certificate Assistant → *Request a Certificate From a
   Certificate Authority* → "Saved to disk"), upload it at developer.apple.com →
   Certificates → **Developer ID Application**, download the `.cer`, and
   double-click to install. If it shows "not trusted," also install the
   intermediate the cert points at — its "CA Issuers" URL, e.g.
   `http://certs.apple.com/devidg2.der`. Verify:
   ```sh
   security find-identity -v -p codesigning   # → Developer ID Application: <NAME> (<TEAMID>)
   ```

2. A **notarytool keychain profile** named `cw-notary`, using an App Store
   Connect API key (keeps your personal Apple ID out of the tooling):
   ```sh
   xcrun notarytool store-credentials "cw-notary" \
     --key AuthKey_XXXX.p8 --key-id <KEYID> --issuer <ISSUER-UUID>
   ```

`release.sh` auto-detects the Developer ID identity and uses the `cw-notary`
profile; override with `CWATCH_SIGN_IDENTITY` / `CWATCH_NOTARY_PROFILE`.

Back up the signing identity (Keychain Access → export it as a password-protected
`.p12`) and the `.p8` key — together they restore signing on a new Mac.

## Cutting a release

1. Bump `CFBundleShortVersionString` (and `CFBundleVersion`) in `Info.plist`, and
   add a `CHANGELOG.md` entry.
2. `./release.sh` — builds + signs the `.app`, notarizes and staples it, wraps it
   in a drag-to-Applications DMG, signs + notarizes + staples the DMG, verifies
   both with `spctl`, and prints the DMG's sha256. (The first run prompts once to
   let `codesign` use the key → click **Always Allow**.)
3. Publish, attaching the DMG:
   ```sh
   gh release create v<VERSION> ClaudeWatcher-<VERSION>.dmg --title v<VERSION> --notes-file NOTES.md
   ```
4. Update the cask `version` + `sha256` in **both** `Casks/claude-watcher.rb`
   (source of truth) and the `homebrew-claude-watcher` tap (below).

## Homebrew cask

The cask source of truth is [`Casks/claude-watcher.rb`](../Casks/claude-watcher.rb),
but `brew install --cask claude-watcher` installs from the **tap** — so both must
be bumped on each release.

1. The tap is a public repo named **`homebrew-claude-watcher`** with the cask at
   `Casks/claude-watcher.rb`.
2. On each release, set its `version` + `sha256` to match the new DMG.
3. Users then run:
   ```sh
   brew tap AKharytonchyk/claude-watcher
   brew install --cask claude-watcher
   ```

Because the build is notarized, the cask needs **no** quarantine workaround — it
does not touch `com.apple.quarantine`.
