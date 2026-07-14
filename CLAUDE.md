# CLAUDE.md

Agent guidance for this repo is canonical in **[AGENTS.md](AGENTS.md)** — read
it first (build/run/verify, source layout, conventions, gotchas). The
non-negotiable principles are in **[CONSTITUTION.md](CONSTITUTION.md)**.

Quick reminders:
- Build with `./build-app.sh` (swiftc, **not** SwiftPM). Verify UI by opening the popover.
- Keep it lean; never steal focus; local-first, read-only. Don't `git add -A`.
