import Foundation

/// Brings the terminal hosting a Claude session to the front by matching the
/// process's controlling tty to an iTerm2 session.
enum TerminalFocus {
    /// Controlling tty of a pid, e.g. "/dev/ttys001", or nil if it has none.
    static func tty(forPID pid: Int) -> String? {
        guard let raw = run("/bin/ps", ["-o", "tty=", "-p", "\(pid)"])?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty, raw != "??"
        else { return nil }
        return raw.hasPrefix("/dev/") ? raw : "/dev/\(raw)"
    }

    /// Focus the iTerm2 window/tab whose session has this tty.
    /// Returns true if a matching session was found and selected.
    @discardableResult
    static func focusITerm(tty: String) -> Bool {
        let script = """
        tell application "iTerm2"
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                if (tty of s) is "\(tty)" then
                  select w
                  select t
                  select s
                  activate
                  return "ok"
                end if
              end repeat
            end repeat
          end repeat
        end tell
        return "notfound"
        """
        return run("/usr/bin/osascript", ["-e", script])?.contains("ok") ?? false
    }

    private static func run(_ launchPath: String, _ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
