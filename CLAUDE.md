# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

# Project: claude-watcher

A macOS menu-bar app (native Swift + AppKit `NSStatusItem`) that shows a compact
per-state breakdown of running Claude Code agents (🔴 needs-you / 🟡 working /
🟢 idle). Clicking the status icon opens a SwiftUI popover (`NSPopover` +
`NSHostingController`), not an `NSMenu`.

## Build & run

- **Build:** `./build-app.sh` — compiles with `swiftc` directly and wraps the
  binary in `ClaudeWatcher.app`. Only Command Line Tools are installed (no full
  Xcode); SwiftUI still compiles and links fine.
- **Do NOT reintroduce `Package.swift`.** SwiftPM's manifest fails to link
  without full Xcode (`PackageDescription.Package` undefined symbol). Compile via
  `swiftc`, as `build-app.sh` does.
- **Run:** `open ClaudeWatcher.app`, or run the binary in the foreground for logs:
  `./ClaudeWatcher.app/Contents/MacOS/ClaudeWatcher`.
- **Verifying UI changes:** screen capture is unavailable in this environment
  (Screen Recording TCC denied). Verify by confirming the process survives opening
  the popover (no render crash), not by screenshot. `CWATCH_AUTOOPEN` auto-opens
  the popover on launch to exercise the render path.

## Non-negotiable: no focus-stealing UI

Never grab focus or cover the user's active work. For any notification/alert/UI:
never call `NSApp.activate(...)`, never raise/open a window or popover unprompted,
never use modal dialogs. Prefer ambient signals — menu-bar icon state/pulse,
system notification banners (which don't change focus), optional sound. Any focus
change must be user-initiated (e.g. they click a row or banner).

## Data source

Each live Claude Code process writes `~/.claude/sessions/<pid>.json` with `name`,
`cwd`, `status`, and timestamps. `status` is `"busy"` (🟡), `"idle"`/`"shell"`
(🟢), or `"waiting"` (🔴). When `waiting`, `waitingFor` says why — this is the
reliable "needs you" signal. Interactive questions and tool approvals both surface
as `permission prompt`, so red is worded neutrally ("needs you"), never
"permission". Dead PIDs are dropped via `kill(pid, 0)`.

Per-agent detail (title, last prompt, token usage) comes from the transcript at
`~/.claude/projects/<enc>/<sessionId>.jsonl`, where `<enc>` is the cwd with every
non-alphanumeric char replaced by `-`. Read lazily on popover open, cached by
file mtime.

## Source map (`Sources/ClaudeWatcher/`)

- `main.swift` / `AppDelegate.swift` — entry point, status item, lifecycle.
- `AgentsModel.swift` — `ObservableObject` feeding the SwiftUI popover live.
- `PopoverView.swift` — SwiftUI popover UI.
- `Session.swift` / `Status.swift` — session model & status parsing.
- `Transcript.swift` — lazy transcript reader (title, last prompt, ctx usage).
- `PRChecker.swift` — background `gh pr list` on a TTL cache (never on the open path).
- `TerminalFocus.swift` — click-to-focus: pid → tty → AppleScript iTerm jump.
- `FileWatcher.swift` — FSEvents real-time watch (`-framework CoreServices`).

## Release

Bump `version` in `Info.plist`, run `release.sh` to rebuild + package the DMG,
then update the cask `version` + `sha256` in **both** the repo `Casks/` and the
Homebrew tap repo. Builds are unsigned/ad-hoc (notarization needs a paid Apple
Developer cert). See `docs/DISTRIBUTION.md` and `PRIVACY.md`.
