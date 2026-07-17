# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and this project aims to follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-07-17

### Added
- Distributed builds are now **Developer ID-signed, notarized by Apple, and
  stapled** — both the `.app` and the DMG. Gatekeeper accepts them with no
  warning and no quarantine workaround. `release.sh` signs → notarizes →
  staples → verifies end-to-end.

### Changed
- Single-instance guard: launching a second copy now exits immediately instead
  of adding a duplicate menu-bar item and FSEvents watcher.

### Security
- Validate the controlling tty before it reaches the jump-to-terminal
  AppleScript — closes an AppleScript-injection vector.
- Validate the session id before using it as a transcript path component —
  closes a path-traversal vector. Both surfaced by a peer security review.

### Removed
- The Homebrew cask no longer strips the Gatekeeper quarantine flag in
  `postflight` — unnecessary now that the build is notarized.

## [0.2.0] - 2026-07-16

### Fixed
- Context-window inference is now keyed off the model (Opus 4.x → 1M) instead of
  guessed from observed tokens. A 1M-context session no longer reads as a pinned
  ~100% while it's really ~20% full, and the jarring 100%→20% jump at the 200K
  mark is gone. Other/unknown models keep the observed-size fallback, and
  `CWATCH_CONTEXT_WINDOW` still overrides.

### Added
- Per-agent model label (e.g. "Opus 4.8"), shown beside the host icon only when
  more than one distinct model is running — invisible on a single-model fleet so
  it never crowds the session name.

## [0.1.0] - 2026-07-13

First release.

### Added
- Menu-bar breakdown of running Claude Code agents by state (🔴 needs you /
  🟡 working / 🟢 idle), read from `~/.claude/sessions`.
- Real-time updates via FSEvents (sub-second, no polling loop).
- Native SwiftUI popover (GitHub-flavored, light/dark adaptive): last intent,
  git branch, open-PR pill, and single-select filter chips.
- Click a row to jump to the agent's iTerm tab; click the PR pill to open the PR.
- Context-pressure gauge per agent (`ctx %`) that warns before the auto-compact
  cliff; inferred context window with a `CWATCH_CONTEXT_WINDOW` override.
- Ambient menu-bar pulse when a new agent enters `waiting` (no focus stealing).
- Open-PR status via `gh` (background, cached; works with GitHub Enterprise).

[0.3.0]: https://github.com/AKharytonchyk/claude-watcher/releases/tag/v0.3.0
[0.2.0]: https://github.com/AKharytonchyk/claude-watcher/releases/tag/v0.2.0
[0.1.0]: https://github.com/AKharytonchyk/claude-watcher/releases/tag/v0.1.0
