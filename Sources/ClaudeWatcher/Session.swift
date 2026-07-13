import Foundation

/// One entry from ~/.claude/sessions/<pid>.json — a live Claude Code session.
struct Session: Decodable {
    let pid: Int
    let sessionId: String
    let cwd: String
    let name: String?
    let version: String?
    let status: String?          // "busy" | "idle" | "waiting"
    let waitingFor: String?      // e.g. "permission prompt" (when status == "waiting")
    let kind: String?            // "interactive", ...
    let startedAt: Double?       // epoch ms
    let updatedAt: Double?       // epoch ms
    let statusUpdatedAt: Double? // epoch ms
}

extension Session {
    /// Project folder name derived from the working directory.
    var projectName: String { (cwd as NSString).lastPathComponent }

    var displayName: String { name ?? projectName }

    var isBusy: Bool { status == "busy" }

    /// When the status last changed, if known.
    var statusDate: Date? {
        guard let ms = statusUpdatedAt ?? updatedAt else { return nil }
        return Date(timeIntervalSince1970: ms / 1000.0)
    }

    /// When the process started, if known.
    var startedDate: Date? {
        guard let ms = startedAt else { return nil }
        return Date(timeIntervalSince1970: ms / 1000.0)
    }

    /// Working directory with $HOME collapsed to `~`.
    var shortCwd: String {
        let home = NSHomeDirectory()
        if cwd == home { return "~" }
        if cwd.hasPrefix(home + "/") { return "~" + cwd.dropFirst(home.count) }
        return cwd
    }

    /// Current git branch of the working directory, if any.
    var gitBranch: String? { ClaudeWatcher_gitBranch(at: cwd) }

    /// Whether the owning process is still running.
    /// kill(pid, 0): 0 => alive; EPERM => alive but not ours; ESRCH => gone.
    var isAlive: Bool {
        if kill(pid_t(pid), 0) == 0 { return true }
        return errno == EPERM
    }
}

/// Best-effort current branch by reading `.git/HEAD`. Returns a short SHA for
/// detached HEAD, or nil when there's no plain git dir (e.g. worktrees).
func ClaudeWatcher_gitBranch(at path: String) -> String? {
    let head = (path as NSString).appendingPathComponent(".git/HEAD")
    guard let contents = try? String(contentsOfFile: head, encoding: .utf8) else { return nil }
    let line = contents.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefix = "ref: refs/heads/"
    if line.hasPrefix(prefix) { return String(line.dropFirst(prefix.count)) }
    return line.count >= 7 ? String(line.prefix(7)) : nil
}

/// Compact elapsed time since `date`: "<1m", "4m", "2h 3m", "1d 4h".
func elapsedShort(since date: Date?, now: Date = Date()) -> String {
    guard let date else { return "" }
    let seconds = max(0, now.timeIntervalSince(date))
    let minutes = Int(seconds / 60)
    if minutes < 1 { return "<1m" }
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h \(minutes % 60)m" }
    let days = hours / 24
    return "\(days)d \(hours % 24)h"
}

/// Reads and filters the sessions written by running Claude Code processes.
final class SessionStore {
    static let sessionsDir = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/sessions")

    /// All sessions whose process is still alive, oldest first.
    func loadLive() -> [Session] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: Self.sessionsDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let decoder = JSONDecoder()
        var sessions: [Session] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let session = try? decoder.decode(Session.self, from: data),
                  session.isAlive
            else { continue }
            sessions.append(session)
        }
        return sessions.sorted { ($0.startedAt ?? 0) < ($1.startedAt ?? 0) }
    }
}
