import Foundation

struct PRInfo {
    let number: Int
    let isDraft: Bool
    let url: String
}

/// Looks up whether a branch has an open PR via `gh`, in the background, with a
/// short-lived cache so the menu never blocks on the network.
final class PRChecker {
    private struct Entry {
        var branch: String
        var fetchedAt: Date
        var pr: PRInfo?
    }

    private var cache: [String: Entry] = [:]   // keyed by repo dir
    private var inFlight: Set<String> = []
    private let lock = NSLock()
    private let ttl: TimeInterval = 90
    private static let ghCandidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]

    /// The PR lookup (via `gh`) is the app's only outbound network path.
    /// Set CWATCH_OFFLINE to disable it entirely for a guaranteed zero-network run.
    private static let offline = ProcessInfo.processInfo.environment["CWATCH_OFFLINE"] != nil

    /// What we currently know for a dir+branch.
    /// `fetched == false` means "not looked up yet" (show nothing/placeholder).
    func status(dir: String, branch: String?) -> (fetched: Bool, pr: PRInfo?) {
        if Self.offline { return (true, nil) }
        guard let branch else { return (true, nil) }
        lock.lock(); defer { lock.unlock() }
        if let entry = cache[dir], entry.branch == branch,
           Date().timeIntervalSince(entry.fetchedAt) < ttl {
            return (true, entry.pr)
        }
        return (false, nil)
    }

    /// Refresh any stale/missing entries for the given sessions in the background.
    func refresh(_ sessions: [Session]) {
        guard !Self.offline, let gh = Self.gh else { return }
        var seenDirs = Set<String>()
        for session in sessions {
            guard let branch = session.gitBranch else { continue }
            let dir = session.cwd
            guard seenDirs.insert(dir).inserted else { continue }

            lock.lock()
            let entry = cache[dir]
            let fresh = entry?.branch == branch
                && (entry.map { Date().timeIntervalSince($0.fetchedAt) < ttl } ?? false)
            let already = inFlight.contains(dir)
            if !fresh && !already { inFlight.insert(dir) }
            lock.unlock()
            if fresh || already { continue }

            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self else { return }
                let pr = Self.fetch(gh: gh, dir: dir, branch: branch)
                self.lock.lock()
                self.cache[dir] = Entry(branch: branch, fetchedAt: Date(), pr: pr)
                self.inFlight.remove(dir)
                self.lock.unlock()
            }
        }
    }

    private static var gh: String? {
        ghCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func fetch(gh: String, dir: String, branch: String) -> PRInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gh)
        process.currentDirectoryURL = URL(fileURLWithPath: dir)
        process.arguments = ["pr", "list", "--head", branch, "--state", "open",
                             "--json", "number,isDraft,url", "--limit", "1"]
        // A GUI app inherits a minimal PATH; gh shells out to git, so widen it
        // (keeping HOME etc. so gh finds its auth config).
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = array.first,
              let number = first["number"] as? Int
        else { return nil }
        return PRInfo(number: number,
                      isDraft: first["isDraft"] as? Bool ?? false,
                      url: first["url"] as? String ?? "")
    }
}
