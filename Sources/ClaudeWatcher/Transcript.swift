import Foundation

/// Details mined from a session's transcript (~/.claude/projects/<enc>/<id>.jsonl).
struct SessionDetail {
    var title: String?        // ai-generated session title
    var lastPrompt: String?   // user's most recent prompt
    var lastSaid: String?     // most recent assistant text
}

/// Reads transcript detail on demand, cached by file modification time so
/// repeatedly opening the menu doesn't re-parse an unchanged file.
final class TranscriptReader {
    private var cache: [String: (mtime: Date, detail: SessionDetail)] = [:]
    private static let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

    func detail(for session: Session) -> SessionDetail {
        guard let url = transcriptURL(for: session) else { return SessionDetail() }
        let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? .distantPast
        if let cached = cache[session.sessionId], cached.mtime == mtime {
            return cached.detail
        }
        let detail = parse(url)
        cache[session.sessionId] = (mtime, detail)
        return detail
    }

    /// Claude Code stores transcripts under a folder that is the cwd with every
    /// non-alphanumeric character replaced by "-".
    private func transcriptURL(for session: Session) -> URL? {
        let encoded = String(session.cwd.map { Self.allowed.contains($0) ? $0 : "-" })
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects/\(encoded)/\(session.sessionId).jsonl")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Scan from the end so we hit the most recent entries first, stopping as
    /// soon as all three fields are found.
    private func parse(_ url: URL) -> SessionDetail {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return SessionDetail()
        }
        var detail = SessionDetail()
        for line in content.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            if detail.title != nil, detail.lastPrompt != nil, detail.lastSaid != nil { break }

            if detail.title == nil, line.contains("\"ai-title\""),
               let obj = json(line), let t = obj["aiTitle"] as? String, !t.isEmpty {
                detail.title = t
            }
            if detail.lastPrompt == nil, line.contains("\"last-prompt\""),
               let obj = json(line), let p = obj["lastPrompt"] as? String, !p.isEmpty {
                detail.lastPrompt = p
            }
            if detail.lastSaid == nil, line.contains("\"role\":\"assistant\""),
               let text = assistantText(line) {
                detail.lastSaid = text
            }
        }
        return detail
    }

    private func json(_ line: Substring) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
    }

    /// Concatenated text blocks of an assistant message line, if any.
    private func assistantText(_ line: Substring) -> String? {
        guard let obj = json(line),
              let msg = obj["message"] as? [String: Any],
              msg["role"] as? String == "assistant",
              let content = msg["content"] as? [[String: Any]]
        else { return nil }
        let text = content
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

/// One-line, length-capped version of a possibly multi-line string.
func oneLine(_ text: String, max: Int) -> String {
    let flat = text.replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return flat.count <= max ? flat : String(flat.prefix(max - 1)) + "…"
}
