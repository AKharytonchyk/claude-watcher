import Foundation

/// Adapter for Claude Code sessions under ~/.claude.
final class ClaudeAdapter: AgentAdapter {
    let brand = AgentBrand(id: "claude", displayName: "Claude Code")

    private let store = SessionStore()
    private let transcripts = TranscriptReader()

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: SessionStore.sessionsDir.path)
    }

    var watchPaths: [String] { [SessionStore.sessionsDir.path] }

    func liveSessions() -> [AgentSession] {
        store.loadLive().map { session in
            let state = classify(session)
            let detail = transcripts.detail(for: session)
            return AgentSession(
                providerID: brand.id,
                id: session.sessionId,
                name: session.displayName,
                pid: session.pid,
                cwd: session.cwd,
                state: state,
                waitingReason: state == .waiting ? waitingReason(session.waitingFor) : nil,
                stateSince: session.statusDate,
                startedAt: session.startedDate,
                lastIntent: detail.lastPrompt,
                lastSaid: detail.lastSaid,
                contextTokens: detail.contextTokens,
                model: detail.model
            )
        }
    }
}
