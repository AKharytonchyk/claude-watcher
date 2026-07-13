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
}

/// Observable snapshot of the running agents, refreshed on a timer.
final class AgentsModel: ObservableObject {
    @Published private(set) var agents: [AgentVM] = []
    @Published private(set) var counts = StatusCounts()

    private let store = SessionStore()
    private let transcripts = TranscriptReader()
    let prChecker = PRChecker()

    func refresh() {
        let sessions = store.loadLive()
        prChecker.refresh(sessions)  // warm PR cache in background

        // Urgency first (needs you → working → idle); longest-in-state on top.
        let ordered = sessions.sorted { a, b in
            let ra = classify(a).rawValue, rb = classify(b).rawValue
            if ra != rb { return ra < rb }
            return (a.statusDate ?? .distantPast) < (b.statusDate ?? .distantPast)
        }

        counts = countStates(sessions)
        agents = ordered.map { session in
            let state = classify(session)
            let branch = session.gitBranch
            let (fetched, pr) = prChecker.status(dir: session.cwd, branch: branch)
            let detail = transcripts.detail(for: session)

            let stateText: String
            switch state {
            case .waiting: stateText = "needs you — \(waitingReason(session.waitingFor))"
            case .working: stateText = "working"
            case .idle:    stateText = "idle"
            }

            let ctxTokens = detail.contextTokens
            let window = ctxTokens.map { contextWindow(observedTokens: $0) }
            let ctxPct: Double? = (ctxTokens != nil && window != nil)
                ? Double(ctxTokens!) / Double(window!) : nil

            return AgentVM(
                id: session.sessionId,
                name: session.displayName,
                state: state,
                stateText: stateText,
                timeText: elapsedShort(since: session.statusDate),
                intent: detail.lastPrompt.map { oneLine($0, max: 140) },
                branch: branch,
                pr: pr,
                prPending: branch != nil && !fetched,
                cwd: session.cwd,
                shortCwd: session.shortCwd,
                pid: session.pid,
                contextTokens: ctxTokens,
                contextWindow: window,
                contextPct: ctxPct
            )
        }
    }
}
