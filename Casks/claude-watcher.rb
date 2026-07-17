# Homebrew cask for Claude Watcher.
#
# This lives here as the source of truth. To let people `brew install`, copy it
# into a tap repo named `homebrew-claude-watcher` (path `Casks/claude-watcher.rb`),
# then users run:
#
#   brew tap AKharytonchyk/claude-watcher
#   brew install --cask claude-watcher
#
# Update `version` and `sha256` on each release (release.sh prints the sha256).
cask "claude-watcher" do
  version "0.3.0"
  # TODO(release): replace with the sha256 that release.sh prints for
  # ClaudeWatcher-0.3.0.dmg before merging this PR.
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/AKharytonchyk/claude-watcher/releases/download/v#{version}/ClaudeWatcher-#{version}.dmg"
  name "Claude Watcher"
  desc "Menu-bar app that shows which Claude Code agent needs you"
  homepage "https://github.com/AKharytonchyk/claude-watcher"

  depends_on macos: :ventura # macOS 13 (Ventura) or later

  app "ClaudeWatcher.app"

  # The build is signed with a Developer ID cert and notarized, so Gatekeeper
  # accepts it — no quarantine stripping needed.

  zap trash: [
    "~/Library/Application Support/ClaudeWatcher",
    "~/Library/Preferences/com.akh.claude-watcher.plist",
  ]
end
