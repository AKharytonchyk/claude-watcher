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
  version "0.2.0"
  sha256 "0a2013e37c6ead139f9033d445c93600f46e16fac17af976eb90ba495319e0b8"

  url "https://github.com/AKharytonchyk/claude-watcher/releases/download/v#{version}/ClaudeWatcher-#{version}.dmg"
  name "Claude Watcher"
  desc "Menu-bar app that shows which Claude Code agent needs you"
  homepage "https://github.com/AKharytonchyk/claude-watcher"

  depends_on macos: :ventura # macOS 13 (Ventura) or later

  app "ClaudeWatcher.app"

  # Not yet notarized — clear quarantine so Gatekeeper doesn't block launch.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/ClaudeWatcher.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/ClaudeWatcher",
    "~/Library/Preferences/com.akh.claude-watcher.plist",
  ]
end
