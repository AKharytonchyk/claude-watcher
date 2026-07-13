# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and this project aims to follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[0.1.0]: https://github.com/AKharytonchyk/claude-watcher/releases/tag/v0.1.0
