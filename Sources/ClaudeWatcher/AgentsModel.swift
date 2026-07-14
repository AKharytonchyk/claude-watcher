import Foundation
import Combine

/// Everything one row needs to render, precomputed off the SwiftUI thread.
struct AgentVM: Identifiable {
    let id: String          // sessionId
    let name: String
    let state: AgentState
    let stateText: String   // "needs you — awaiting your response" / "working" / "idle"
    let timeText: String    // "3m", "1d 2h"
    let intent: String?     // last user prompt
    let branch: String?
    let pr: PRInfo?
    let prPending: Bool      // branch exists but PR not looked up yet
    let cwd: String
    let shortCwd: String
    let pid: Int
    let contextTokens: Int?  // most recent turn's context size
    let contextWindow: Int?  // inferred window
    let contextPct: Double?  // contextTokens / window (0...1)
    let hostKind: TerminalHost
    let hostAppPath: String? // .app to activate on click (non-iTerm hosts)
    let groupCaption: String? // dim project label — only on the first of a ≥2 group
}

/// Observable snapshot of the running agents, refreshed on a timer / FS event.
final class AgentsModel: ObservableObject {
    @Published private(set) var agents: [AgentVM] = []
    @Published private(set) var counts = StatusCounts()

    private let registry = AgentRegistry.enabled()
    let prChecker = PRChecker()

    /// Directories the file listener should watch (union across adapters).
    var watchPaths: [String] { registry.allWatchPaths() }

    func refresh() {
        let sessions = registry.liveSessions()

        // git branch per session (agent-agnostic), computed once.
        let branches = Dictionary(sessions.map { ($0.id, ClaudeWatcher_gitBranch(at: $0.cwd)) },
                                  uniquingKeysWith: { a, _ in a })
        prChecker.refresh(sessions.map { (dir: $0.cwd, branch: branches[$0.id] ?? nil) })
        let hosts = HostDetector.detect(pids: sessions.map(\.pid))

        // Per-project aggregates so groups (same cwd) stay adjacent, ordered by
        // their most-urgent member, then most-recent activity.
        var groupRank: [String: Int] = [:]
        var groupLatest: [String: Date] = [:]
        var groupCount: [String: Int] = [:]
        for s in sessions {
            groupRank[s.cwd] = min(groupRank[s.cwd] ?? .max, s.state.rawValue)
            groupLatest[s.cwd] = max(groupLatest[s.cwd] ?? .distantPast, s.stateSince ?? .distantPast)
            groupCount[s.cwd, default: 0] += 1
        }

        let ordered = sessions.sorted { a, b in
            if a.cwd != b.cwd {
                let ra = groupRank[a.cwd] ?? .max, rb = groupRank[b.cwd] ?? .max
                if ra != rb { return ra < rb }
                let la = groupLatest[a.cwd] ?? .distantPast, lb = groupLatest[b.cwd] ?? .distantPast
                if la != lb { return la > lb }
                return a.cwd < b.cwd
            }
            if a.state.rawValue != b.state.rawValue { return a.state.rawValue < b.state.rawValue }
            return (a.stateSince ?? .distantPast) < (b.stateSince ?? .distantPast) // longest-in-state on top
        }

        counts = countStates(sessions.map(\.state))
        var seenCwd = Set<String>()
        agents = ordered.map { session in
            let branch = branches[session.id] ?? nil
            let (fetched, pr) = prChecker.status(dir: session.cwd, branch: branch)
            let host = hosts[session.pid] ?? HostInfo(kind: .unknown, appPath: nil)

            let stateText: String
            switch session.state {
            case .waiting: stateText = "needs you — \(session.waitingReason ?? "awaiting your input")"
            case .working: stateText = "working"
            case .idle:    stateText = "idle"
            }

            let ctxTokens = session.contextTokens
            let window = ctxTokens.map { contextWindow(observedTokens: $0) }
            let ctxPct: Double? = (ctxTokens != nil && window != nil)
                ? Double(ctxTokens!) / Double(window!) : nil

            let firstOfGroup = seenCwd.insert(session.cwd).inserted
            let caption = (firstOfGroup && (groupCount[session.cwd] ?? 0) >= 2)
                ? session.projectName : nil

            return AgentVM(
                id: session.id,
                name: session.name,
                state: session.state,
                stateText: stateText,
                timeText: elapsedShort(since: session.stateSince),
                intent: session.lastIntent.map { oneLine($0, max: 140) },
                branch: branch,
                pr: pr,
                prPending: branch != nil && !fetched,
                cwd: session.cwd,
                shortCwd: session.shortCwd,
                pid: session.pid,
                contextTokens: ctxTokens,
                contextWindow: window,
                contextPct: ctxPct,
                hostKind: host.kind,
                hostAppPath: host.appPath,
                groupCaption: caption
            )
        }
    }
}
