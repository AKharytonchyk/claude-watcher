# Privacy

Claude Watcher is **local-first**. It has **no telemetry, no analytics, and
makes no network requests of its own** — verified: the source contains no
`URLSession`/socket/HTTP code, no analytics SDKs, and no hardcoded URLs.

## What it reads (local, read-only)

- `~/.claude/sessions/*.json` — the status files running Claude Code processes
  write (name, cwd, `busy`/`idle`/`waiting`, timestamps).
- `~/.claude/projects/<project>/<sessionId>.jsonl` — the session transcript,
  from which it extracts your **last prompt**, the **last assistant text**, and
  **token usage** (for the context gauge). This stays on your machine and is
  shown only in the local popover.
- `<repo>/.git/HEAD` — to display the current branch.

It never modifies these files.

## What it writes

**Nothing.** No caches, no preferences, no logs, no persisted state. Everything
is held in memory while the app runs.

## Processes it runs (and what data they receive)

| Command | When | Data passed | Network? |
|---------|------|-------------|----------|
| `ps -o tty= -p <pid>` | you click a row | a process id | no (local) |
| `osascript` (AppleScript) | you click a row | a tty like `/dev/ttys001` | no (local) |
| `gh pr list --head <branch> …` | background, cached ~90s | **only the branch name** (gh reads the repo from your local git remote) | **yes** |

The **only** outbound traffic is that `gh` call, which talks to **your own**
GitHub host with **your own** `gh` credentials, and sends only the repo +
branch. Your prompts, transcripts, session contents, and file paths are **never**
sent anywhere.

Clicking a row opens your terminal (iTerm) locally; clicking the PR pill opens
that PR URL in your browser — both are actions you initiate.

## Turning off all network

Set `CWATCH_OFFLINE` to disable the PR lookup entirely — then the app makes
**zero** network calls and spawns no `gh`:

```sh
launchctl setenv CWATCH_OFFLINE 1   # then relaunch Claude Watcher
```

(The app also stays fully offline automatically if `gh` isn't installed.)

## Permissions

- **Automation → iTerm2**: requested on first row-click, only to focus the tab.
- No other entitlements; no accessibility, camera, mic, contacts, or location.
