# AGENTS.md

Canonical guidance for AI coding agents (and humans) working on **Claude Watcher**.
Read this first. The non-negotiable principles live in [CONSTITUTION.md](CONSTITUTION.md);
larger features get a spec under [`specs/`](specs/).

## What this is

A tiny macOS menu-bar app (Swift + SwiftUI/AppKit) that shows which running
Claude Code agent needs you, read from `~/.claude/sessions`. One binary, no
daemon, local-first.

## Build · run · verify

```sh
./build-app.sh                                   # compile + bundle ClaudeWatcher.app
open ClaudeWatcher.app                            # launch into the menu bar
./ClaudeWatcher.app/Contents/MacOS/ClaudeWatcher  # run in foreground to see logs
./release.sh                                      # sign + notarize + staple a DMG (needs a Developer ID cert + the cw-notary profile)
```

- **One instance at a time.** A launch exits immediately if another instance is
  already running (single-instance guard in `main.swift`) — quit the menu-bar
  app before running the binary for logs, or the foreground process just quits.

- **Compiles with `swiftc`, not SwiftPM.** A `Package.swift` manifest fails to
  link with only the Command Line Tools installed — do **not** reintroduce one.
  Frameworks: `-framework AppKit -framework SwiftUI -framework CoreServices`
  (see `build-app.sh`). **No full Xcode required.**
- **Verify UI changes by driving the real UI.** SwiftUI render errors only
  surface at runtime, not at compile time. Before shipping a UI change, launch
  and open the popover. In a headless/sandbox context, temporarily gate an
  auto-open on a `CWATCH_AUTOOPEN` env var, confirm the process survives opening
  the popover, then remove the hook.

## Source layout

| File | Purpose |
|------|---------|
| `AgentAdapter.swift` | Adapter protocol + normalized `AgentSession` + `AgentBrand` |
| `AgentRegistry.swift`| Enabled adapters (`CWATCH_AGENTS`), watch-path + session aggregation |
| `ClaudeAdapter.swift`| Claude Code source, behind the adapter protocol |
| `Session.swift`      | Read `~/.claude/sessions/*.json`, liveness (`kill`), git branch |
| `Status.swift`       | State enum, counts, menu-bar rendering, context-window inference |
| `Transcript.swift`   | Last intent / said / token usage from the session transcript |
| `PRChecker.swift`    | Background open-PR lookup via `gh` (cached; gated by `CWATCH_OFFLINE`) |
| `TerminalFocus.swift`| PID → tty → focus the iTerm tab |
| `HostDetector.swift` | Which app hosts a session (iTerm/VS Code/…), via a `ps` process-tree walk |
| `FileWatcher.swift`  | FSEvents wrapper for real-time updates |
| `AgentsModel.swift`  | `ObservableObject` snapshot (`AgentVM`) feeding SwiftUI |
| `PopoverView.swift`  | SwiftUI popover UI |
| `AppDelegate.swift`  | Status item, watcher, popover host, "needs you" pulse |

## Data source facts

- Each live Claude Code process writes `~/.claude/sessions/<pid>.json` with
  `status` ∈ {`busy`, `idle`, `waiting`}; when `waiting`, `waitingFor` says why.
- Transcripts: `~/.claude/projects/<cwd-with-non-alnum→->/<sessionId>.jsonl`
  (assistant `message.usage` carries token counts; `ai-title`/`last-prompt`
  entries carry the topic/prompt).

## How to work here

- **Match the surrounding style** — comment density, naming, idioms.
- **Simplicity first** — minimum code that solves it; no speculative abstractions.
- **Surface tradeoffs, don't hide confusion** — state assumptions; if unclear, ask.
- **Small changes stay lightweight**; only real subsystems get a `specs/` doc.

## Gotchas (learned the hard way)

- **Never `git add -A`.** The working tree contains local tooling
  (`.claude/`, `.entire/`) that must not be committed — they're gitignored, but
  stage explicit paths anyway.
- End commit messages with the `Co-Authored-By` trailer.
- Env vars: `CWATCH_CONTEXT_WINDOW` (force the ctx gauge window),
  `CWATCH_OFFLINE` (disable the only network path).
- Releases update the cask `version`+`sha256` in **both** this repo's `Casks/`
  and the `homebrew-claude-watcher` tap (see `docs/DISTRIBUTION.md`).

## Out of scope (by design — see the Constitution)

Daemon/background service, web dashboard, telemetry/analytics, any UI that
steals focus, and broad multi-agent support (that only lands via
[`specs/0001-agent-adapters.md`](specs/0001-agent-adapters.md), not ad-hoc).
