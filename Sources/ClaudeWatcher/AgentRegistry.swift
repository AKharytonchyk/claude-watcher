import Foundation

/// The set of enabled agent adapters — the source of truth for what the
/// listener watches and where sessions come from.
final class AgentRegistry {
    let adapters: [AgentAdapter]

    init(adapters: [AgentAdapter]) {
        self.adapters = adapters
    }

    /// Build from `CWATCH_AGENTS` (comma-separated ids; default "claude").
    static func enabled() -> AgentRegistry {
        let ids = ProcessInfo.processInfo.environment["CWATCH_AGENTS"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            ?? ["claude"]

        var adapters: [AgentAdapter] = []
        for id in ids {
            switch id {
            case "claude": adapters.append(ClaudeAdapter())
            // case "codex": adapters.append(CodexAdapter())   // specs/0001
            default: break
            }
        }
        if adapters.isEmpty { adapters.append(ClaudeAdapter()) }
        return AgentRegistry(adapters: adapters)
    }

    /// All declared watch paths (unconditional — a not-yet-created dir should
    /// still be watched so the first session is caught instantly).
    func allWatchPaths() -> [String] {
        adapters.flatMap { $0.watchPaths }
    }

    /// Live sessions across available adapters.
    func liveSessions() -> [AgentSession] {
        adapters.filter { $0.isAvailable }.flatMap { $0.liveSessions() }
    }
}
