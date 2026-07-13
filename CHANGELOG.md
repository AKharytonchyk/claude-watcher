# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and this project aims to follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Real-time updates via FSEvents (sub-second, no polling loop).
- Context-pressure gauge per agent (`ctx %`) that warns before the auto-compact
  cliff; inferred context window with a `CWATCH_CONTEXT_WINDOW` override.
- Native SwiftUI popover: last intent, git branch, open-PR pill, filter chips.
- Click a row to jump to the agent's iTerm tab; click the PR pill to open the PR.
- Ambient menu-bar pulse when a new agent enters `waiting` (no focus stealing).
- Open-PR status via `gh` (background, cached; works with GitHub Enterprise).

### Notes
- First tagged release will be `v0.1.0`.
