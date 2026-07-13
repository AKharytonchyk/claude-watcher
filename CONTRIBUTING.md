# Contributing to Claude Watcher

Thanks for taking a look! This is a small, focused project — contributions that
keep it lean and Claude-Code-focused are very welcome.

## Getting set up

Requires the Xcode Command Line Tools (`xcode-select --install`); no full Xcode.

```sh
./build-app.sh                                   # build ClaudeWatcher.app
./ClaudeWatcher.app/Contents/MacOS/ClaudeWatcher # run in foreground to see logs
```

The whole app is plain Swift compiled with `swiftc` (see `build-app.sh`) — no
SwiftPM manifest, no Xcode project. Sources live in `Sources/ClaudeWatcher/`:

| File | Purpose |
|------|---------|
| `Session.swift`      | Read/parse `~/.claude/sessions`, liveness check |
| `Status.swift`       | State enum, counts, menu-bar rendering, context window |
| `Transcript.swift`   | Last intent / said / token usage from the transcript |
| `PRChecker.swift`    | Background open-PR lookup via `gh` (cached) |
| `TerminalFocus.swift`| PID → tty → focus the iTerm window/tab |
| `FileWatcher.swift`  | FSEvents wrapper for real-time updates |
| `AgentsModel.swift`  | `ObservableObject` snapshot feeding SwiftUI |
| `PopoverView.swift`  | SwiftUI popover UI |
| `AppDelegate.swift`  | Status item, watcher, popover host |

## Guidelines

- **Keep it lean.** The appeal is "one tiny binary that does the Claude thing
  well." Big additions (daemons, web dashboards, multi-agent adapters) are out
  of scope by design — see the README's "Why Claude Watcher".
- **No focus stealing.** Never `activate` the app or open a window over the
  user's work; prefer ambient signals.
- **Match the surrounding style** — comment density, naming, and idioms.
- **Verify UI changes** by actually opening the popover (the build script and a
  quick launch will do); note that SwiftUI render crashes only surface at
  runtime, not compile time.

## Submitting

1. Branch off `main`.
2. Keep commits focused; describe the user-facing change.
3. Open a PR describing what changed and how you verified it.
