# Constitution

The non-negotiable principles for Claude Watcher. Any change — by a human or an
agent — must uphold these. When a request conflicts with one, stop and surface it.

### 1. Privacy-first
Local-only. No telemetry, no analytics, no network of our own. Read the user's
`~/.claude` and repos **read-only**; write nothing to disk. The single outbound
path (the `gh` PR lookup) must stay optional and disable-able (`CWATCH_OFFLINE`).
→ see [PRIVACY.md](PRIVACY.md).

### 2. Never steal focus
This is an ambient status object, not a foreground app. Never call
`NSApp.activate`, never open a window/popover unprompted, never use a modal.
Alerts are ambient (menu-bar pulse). Any focus change must be user-initiated
(they clicked a row or a link).

### 3. Lean & Claude-focused
One `swiftc`-built binary, no daemon, no bundled runtime, minimal dependencies.
Resist scope creep: no web dashboard, no analytics stack, no background service.
Broad multi-agent support lands only through a spec (`specs/`), never ad-hoc.

### 4. Native, not templated
Follow the Apple HIG. System font (SF Pro), system materials, semantic colors
that adapt to light/dark. Defer to content; be restrained with color (one color
system = the state dot); take away until only the signal remains.

### 5. Verify before shipping
Drive the real thing — build and open the popover — before declaring a UI change
done. Compiling is not verifying. Report outcomes honestly (what was tested,
what was skipped).

### 6. Small stays small
Right-size the process. Trivial changes ship directly; only genuine subsystems
get a `specs/` document. Governance should never cost more than the work.
