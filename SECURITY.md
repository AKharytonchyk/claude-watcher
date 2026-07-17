# Security Policy

## Scope & posture

Claude Watcher runs entirely on your machine. It:

- **Reads** `~/.claude/sessions/*.json` and session transcripts under
  `~/.claude/projects/` — read-only, never modified.
- **Runs** `gh` (in each repo directory) to check open-PR status, and
  `osascript` / `ps` to focus the iTerm tab for a session.
- Sends **no telemetry** and makes **no network calls** of its own; the only
  network access is whatever your own `gh` does to your GitHub host.

It requires no elevated privileges. The jump-to-iTerm feature uses macOS
Automation permission, which you grant explicitly on first use.

## Distribution & hardening

- The distributed build (the release DMG and the `.app` inside it) is signed
  with a **Developer ID** certificate and **notarized by Apple**, then stapled —
  so it launches without a Gatekeeper warning and needs no quarantine workaround.
- Inputs that cross a shell / AppleScript / filesystem boundary are validated
  before use: the controlling tty (before it reaches `osascript`) and the
  session id (before it becomes a transcript path component).

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Instead, use
GitHub's private **[Report a vulnerability](https://github.com/AKharytonchyk/claude-watcher/security/advisories/new)**
(Security → Advisories) so it can be handled privately.

Include repro steps and impact. You'll get an acknowledgement as soon as
possible, and credit in the fix unless you prefer to stay anonymous.
