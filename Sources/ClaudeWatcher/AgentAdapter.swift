import Foundation

/// Identity/branding for an agent type.
struct AgentBrand {
    let id: String
    let displayName: String
    let symbol: String   // monochrome SF Symbol for the provider badge
}

/// One running agent session, normalized so the model/UI never see an agent's
/// native format. Adapters own native parsing *and* state (state detection
/// differs per agent — Claude reads a `status` field; others must infer it).
struct AgentSession {
    let providerID: String
    let providerName: String
    let providerSymbol: String
    let id: String
    let name: String
    let pid: Int
    let cwd: String
    let state: AgentState
    let waitingReason: String?   // friendly reason, when .waiting
    let stateSince: Date?
    let startedAt: Date?
    let lastIntent: String?      // raw last user prompt (model trims for display)
    let lastSaid: String?
    let contextTokens: Int?
    let model: String?

    var projectName: String { (cwd as NSString).lastPathComponent }

    var shortCwd: String {
        let home = NSHomeDirectory()
        if cwd == home { return "~" }
        if cwd.hasPrefix(home + "/") { return "~" + cwd.dropFirst(home.count) }
        return cwd
    }
}

/// A source of agent sessions. Each agent type ships one adapter.
protocol AgentAdapter {
    var brand: AgentBrand { get }
    /// Whether this agent's data is present on the machine.
    var isAvailable: Bool { get }
    /// Directories the file listener should watch for real-time updates.
    var watchPaths: [String] { get }
    /// Enumerate + normalize the currently-live sessions (cached internally).
    func liveSessions() -> [AgentSession]
}
