import Foundation

/// Which terminal/app is hosting a session — for the row glyph and to route
/// "jump to it" correctly (iTerm tab vs. activating VS Code, etc.).
enum TerminalHost {
    case iterm, vscode, terminal, otherApp, unknown

    /// Monochrome SF Symbol for the row glyph.
    var symbol: String {
        switch self {
        case .iterm, .terminal: return "terminal"
        case .vscode:           return "chevron.left.forwardslash.chevron.right"
        case .otherApp:         return "macwindow"
        case .unknown:          return "questionmark"
        }
    }

    var label: String {
        switch self {
        case .iterm:    return "iTerm"
        case .vscode:   return "VS Code"
        case .terminal: return "Terminal"
        case .otherApp: return "app window"
        case .unknown:  return "unknown host"
        }
    }
}

struct HostInfo {
    let kind: TerminalHost
    let appPath: String?   // .app bundle to activate (nil when unknown)
}

/// Resolves a session's host by walking the process tree to the first ancestor
/// that lives inside a `.app` bundle. Uses a single `ps` snapshot per batch and
/// caches per pid (host doesn't change over a process's life).
enum HostDetector {
    private static var cache: [Int32: HostInfo] = [:]

    static func detect(pids: [Int]) -> [Int: HostInfo] {
        let uncached = pids.filter { cache[Int32($0)] == nil }
        let snap = uncached.isEmpty ? [:] : snapshot()
        var out: [Int: HostInfo] = [:]
        for pid in pids {
            let key = Int32(pid)
            if let hit = cache[key] { out[pid] = hit; continue }
            let info = resolve(pid: key, snap: snap)
            cache[key] = info
            out[pid] = info
        }
        return out
    }

    // MARK: - Process tree

    private static func snapshot() -> [Int32: (ppid: Int32, comm: String)] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,comm="]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return [:] }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return [:] }

        var map: [Int32: (Int32, String)] = [:]
        for line in text.split(separator: "\n") {
            var rest = line.drop { $0 == " " }
            func nextInt() -> Int32? {
                rest = rest.drop { $0 == " " }
                let digits = rest.prefix { $0.isNumber }
                rest = rest.dropFirst(digits.count)
                return Int32(digits)
            }
            guard let pid = nextInt(), let ppid = nextInt() else { continue }
            let comm = String(rest.drop { $0 == " " })
            map[pid] = (ppid, comm)
        }
        return map
    }

    private static func resolve(pid: Int32, snap: [Int32: (ppid: Int32, comm: String)]) -> HostInfo {
        var cur = pid
        var hops = 0
        while let node = snap[cur], hops < 64 {
            if let bundle = appBundle(from: node.comm) {
                return HostInfo(kind: classify(bundle), appPath: bundle)
            }
            if node.ppid <= 1 { break }
            cur = node.ppid
            hops += 1
        }
        return HostInfo(kind: .unknown, appPath: nil)
    }

    /// The enclosing `.app` bundle path from an executable path, if any.
    private static func appBundle(from comm: String) -> String? {
        if let r = comm.range(of: ".app/") {
            return String(comm[comm.startIndex..<r.lowerBound]) + ".app"
        }
        return comm.hasSuffix(".app") ? comm : nil
    }

    private static func classify(_ appPath: String) -> TerminalHost {
        let name = (appPath as NSString).lastPathComponent.lowercased()
        if name.contains("iterm") { return .iterm }
        if name.contains("code") || name.contains("cursor") || name.contains("vscodium") { return .vscode }
        if name.contains("terminal") { return .terminal }
        return .otherApp
    }
}
