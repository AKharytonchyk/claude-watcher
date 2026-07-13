# Claude Watcher

A macOS menu bar app that shows how many Claude Code agents are running,
broken down by state as a compact set of colored dots + counts — e.g.
`🟡1 🟢2` means one working and two idle.

- 🔴 **needs you** — blocked on you (`status: waiting`, e.g. a permission
  prompt or a question); the row shows *what* it's waiting for
- 🟡 **working** — actively busy
- 🟢 **idle** — done / waiting quietly

Only states that actually have agents are shown, most-urgent first, so a
single color never implies "all agents are the same".

Clicking the icon opens a **SwiftUI popover** — a native, system-material panel
with a GitHub-flavored layout that adapts to light/dark automatically. One row
per agent, sorted by urgency (needs-you → working → idle, longest-in-state
first):

```
 Claude Agents                    [🔴1] 🟡1  🟢2   ← click a chip to filter
 ───────────────────────────────────────────────
 🔴  payments-api-7   needs you — awaiting your response · 3m
     add retry + backoff to the upload queue…
     ⎇ feat/onboarding      ⇅ #142
 ───────────────────────────────────────────────
 4 agents                                     Quit
```

The header state chips double as a **single-select filter**: click one to show
only that state, click it again to clear (only one active at a time).

- **Line 1** = name + state + time-in-state (red when it needs you).
- **Line 2** = your last intent (the last thing you asked it to do).
- **Line 3** = the git branch chip, plus a GitHub-style **PR pill** (solid
  green for open, gray for draft) when the branch has an open PR. Not a git
  repo? Line 3 shows the folder.

**Clicking a row jumps to that agent's iTerm window/tab** (matched by the
process's controlling tty). **Clicking the PR pill opens the PR** in your
browser.

PR status is looked up with `gh` in the background (cached ~90s) so the panel
never blocks; it works with github.com and GitHub Enterprise. No `gh` / no
open PR → no pill.

If the session isn't found in iTerm (e.g. it's in another terminal, or you
haven't granted automation access yet), clicking falls back to revealing the
project folder in Finder.

> **First click on a row** triggers a macOS prompt: *"ClaudeWatcher wants to
> control iTerm2."* Approve it (System Settings → Privacy & Security →
> Automation) for the jump-to-tab feature to work.

The panel updates live while open (every few seconds); transcript detail is
read with an mtime cache so refreshes stay cheap.

## How it works

Every running Claude Code process writes a live status file to
`~/.claude/sessions/<pid>.json` containing `name`, `cwd`, `status`
(`busy`/`idle`/`waiting`), version, and timestamps. Claude Watcher polls that
folder every few seconds, drops entries whose process is no longer alive
(`kill(pid, 0)`), and rolls the rest up into the icon + popover. Per-agent
"last intent" comes from the session transcript; PR status from `gh`.

## Build & run

Requires the Xcode Command Line Tools (`xcode-select --install`). **No full
Xcode needed** — the UI is SwiftUI, but it compiles and links with `swiftc`
alone (`-framework SwiftUI`).

```sh
./build-app.sh        # compiles + produces ClaudeWatcher.app
open ClaudeWatcher.app # launches it into the menu bar
```

To see logs / debug, run the binary in the foreground instead:

```sh
./ClaudeWatcher.app/Contents/MacOS/ClaudeWatcher
```

Quit from the **Quit** button in the popover footer.

## Start at login (optional)

1. System Settings → General → Login Items → **+** → pick `ClaudeWatcher.app`.

Or via `launchd` — see roadmap.

## Layout

| File | Purpose |
|------|---------|
| `Sources/ClaudeWatcher/Session.swift`      | Session model + reader (`~/.claude/sessions`) |
| `Sources/ClaudeWatcher/Status.swift`       | State enum, counts, menu-bar dot rendering |
| `Sources/ClaudeWatcher/Transcript.swift`   | Last intent / said, from the session transcript |
| `Sources/ClaudeWatcher/PRChecker.swift`    | Background open-PR lookup via `gh` (cached) |
| `Sources/ClaudeWatcher/TerminalFocus.swift`| PID → tty → focus the iTerm window/tab |
| `Sources/ClaudeWatcher/AgentsModel.swift`  | `ObservableObject` snapshot feeding SwiftUI |
| `Sources/ClaudeWatcher/PopoverView.swift`  | SwiftUI popover (GitHub-flavored, theme-adaptive) |
| `Sources/ClaudeWatcher/AppDelegate.swift`  | Status item, refresh timer, popover host |
| `Sources/ClaudeWatcher/main.swift`         | Entry point |
| `Info.plist`                               | `LSUIElement` (menu-bar-only, no Dock icon) |
| `build-app.sh`                             | Compile + bundle |

## Roadmap

**Phase 1 (done) — MVP**
- [x] Per-state compact breakdown in the menu bar (🔴/🟡/🟢 + counts)
- [x] Real `waiting` state — surfaces agents blocked on you + the reason
- [x] Rich rows: state + time · last intent · branch + open-PR badge
- [x] Click a row → jump to that agent's iTerm window/tab (tty match)
- [x] Click the PR pill → open the PR in the browser
- [x] SwiftUI popover UI — native materials, GitHub vibe, light/dark adaptive
- [x] Background PR lookup via `gh` (cached); lazy mtime-cached transcript reads
- [x] Stale-process cleanup

**Phase 2 — next**
- [x] Ambient icon pulse when a new agent enters `waiting` (no focus steal,
      edge-triggered, no permission). Banner/sound intentionally not added.
- [ ] "Just finished" detection: flag busy→idle transitions since you looked
- [ ] Row actions: focus the agent's terminal/IDE window, copy path/session id
- [ ] Preferences: refresh interval, which states to notify on
- [ ] Watch the folder with FSEvents instead of polling
- [ ] Launch-at-login toggle (`SMAppService`)

## Known limitations

- Session files are keyed by PID; a crashed process's file lingers until
  a PID is reused, but the liveness check filters those out.
- Git branch is read from `.git/HEAD`; git worktrees (where `.git` is a file)
  show no branch.
