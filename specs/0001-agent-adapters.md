# 0001 — Agent adapter layer (multi-agent support)

- **Status:** Proposed (not started)
- **Owner:** —
- **Gate:** Phase 3 spike must prove a Codex "needs-you" signal is derivable
  before the Codex adapter is built. Multi-agent conflicts with Constitution §3,
  so it lands only via this spec.

## Problem

The model is hard-wired to Claude Code's format (`SessionStore`, `classify()`
on `status`). We want to add other agent types (Codex first) without touching
the UI/model, and let the file listener watch whatever paths the enabled
adapters declare.

## Goals

- A source abstraction so a new agent = one file, no UI changes.
- The listener (FSEvents) fed by adapter-declared watch paths, not a hardcoded dir.
- A normalized session model the UI already understands (`AgentVM`), gaining a
  provider badge.

## Non-goals

- Cost history, DORA metrics, web dashboard, subagent trees (that's Irrlicht).
- A daemon or SDK instrumentation. Stay lean (Constitution §3).

## Design

```swift
protocol AgentAdapter {
    var id: String { get }                 // "claude", "codex"
    var brand: AgentBrand { get }          // display name + badge symbol/color
    var isAvailable: Bool { get }          // data dir exists
    var watchPaths: [String] { get }       // dirs the listener should watch
    func liveSessions() -> [AgentSession]  // enumerate + normalize (cached internally)
}
```

- **`AgentSession`** — normalized fields (providerID, id, name, pid, cwd, state,
  waitingReason, lastIntent, lastSaid, contextTokens, model). The adapter owns
  native parsing **and** state, because state detection differs per agent.
- **`AgentRegistry`** — holds the enabled adapters (`CWATCH_AGENTS`, default
  `claude`), aggregates `allWatchPaths()` (→ one `FileWatcher`) and
  `liveSessions()`.
- **`AgentsModel`** stays the enrichment/view-model layer: git branch, PR lookup,
  context-window %, elapsed formatting, host detection → maps `AgentSession` →
  `AgentVM` (+ `provider`).
- **`ClaudeAdapter`** = today's logic behind the protocol (no behavior change).
- **`CodexAdapter`** = tails `~/.codex/sessions/YYYY/MM/DD/*.jsonl`.

### State detection

- Claude: explicit `status: waiting` (reliable).
- Codex and other statusless agents: infer via a shared **waiting-cue** heuristic
  (trailing question `?` + imperative cues on the last assistant text; skip when a
  blocking tool is open) — the approach Irrlicht uses in
  `core/domain/session/waiting_cue.go`.

## Phases

1. Refactor behind the abstraction, **Claude-only**; verify identical behavior.
2. Provider badge in the UI (even with one provider).
3. **Spike** the Codex source — replay a real `~/.codex/sessions/…` file; confirm
   live-session + needs-you are derivable. Decision gate.
4. `CodexAdapter` + `WaitingCue.swift`; enable via `CWATCH_AGENTS=claude,codex`.
5. Golden fixtures under `Tests/` + a `swiftc` verify harness (no XCTest).

## Acceptance

- With `CWATCH_AGENTS=claude` the popover is byte-for-byte behaviorally identical
  to today (regression gate for Phase 1).
- With Codex enabled, its sessions appear with correct state + a provider badge,
  and clicking focuses the right host.

## Risks / open questions

- Codex has no PID-in-filename and no `status` field; liveness + "needs you" must
  be inferred (fuzzier). `codex` may not even be a watchable CLI on a given
  machine (the local `~/.codex` is the ChatGPT desktop Electron variant).
- Waiting-cue false positives/negatives; fixtures keep it honest.
- Naming: the repo is `claude-watcher`; multi-agent strains that.
