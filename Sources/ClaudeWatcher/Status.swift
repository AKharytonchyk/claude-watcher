import AppKit

/// State of a single agent (and, aggregated, the fleet).
/// Ordered by urgency — `waiting` (blocked on you) first.
enum AgentState: Int, CaseIterable {
    case waiting = 0  // red    — blocked on the user (permission prompt, question, …)
    case working = 1  // yellow — actively busy
    case idle    = 2  // green  — done / waiting quietly

    var color: NSColor {
        switch self {
        case .waiting: return .systemRed
        case .working: return .systemYellow
        case .idle:    return .systemGreen
        }
    }

    var emoji: String {
        switch self {
        case .waiting: return "🔴"
        case .working: return "🟡"
        case .idle:    return "🟢"
        }
    }

    /// Short label for the human-readable summary line.
    var summaryWord: String {
        switch self {
        case .waiting: return "needs you"
        case .working: return "working"
        case .idle:    return "idle"
        }
    }
}

/// Classify one session from its reported status. `waiting` is the reliable
/// "blocked on the user" signal Claude Code writes to the session file.
/// ("shell" is idle-in-a-shell, so it groups with idle.)
func classify(_ session: Session) -> AgentState {
    switch session.status {
    case "waiting": return .waiting
    case "busy":    return .working
    default:        return .idle
    }
}

/// Friendly wording for `waitingFor`. Claude Code emits one of:
/// "permission prompt", "worker request", "sandbox request", "dialog open",
/// "input needed". Note: interactive *questions* and tool *approvals* both
/// surface as "permission prompt", so we phrase that one neutrally — it's
/// always "you need to respond", whether that's answering or approving.
func waitingReason(_ raw: String?) -> String {
    switch raw {
    case "permission prompt": return "awaiting your response"
    case "input needed":      return "awaiting your input"
    case "dialog open":       return "dialog open"
    case "worker request":    return "worker request"
    case "sandbox request":   return "sandbox approval"
    case let other?:          return other
    default:                  return "awaiting your input"
    }
}

/// How many agents are in each state.
struct StatusCounts {
    var waiting = 0
    var working = 0
    var idle = 0

    var total: Int { waiting + working + idle }

    /// (state, count) pairs in urgency order, only for states with any agents.
    var present: [(state: AgentState, count: Int)] {
        [(.waiting, waiting), (.working, working), (.idle, idle)]
            .filter { $0.1 > 0 }
    }
}

func countStates(_ sessions: [Session]) -> StatusCounts {
    var counts = StatusCounts()
    for session in sessions {
        switch classify(session) {
        case .waiting: counts.waiting += 1
        case .working: counts.working += 1
        case .idle:    counts.idle += 1
        }
    }
    return counts
}

// MARK: - Rendering

private let dotFont = NSFont.systemFont(ofSize: 11)
private let countFont = NSFont.menuBarFont(ofSize: 0)

private func dot(_ color: NSColor) -> NSAttributedString {
    NSAttributedString(string: "●", attributes: [
        .foregroundColor: color,
        .font: dotFont,
        .baselineOffset: 0.5,
    ])
}

/// A filled circle image for use as a menu-item icon.
func dotImage(_ color: NSColor, diameter: CGFloat = 10) -> NSImage {
    let size = NSSize(width: diameter, height: diameter)
    let image = NSImage(size: size)
    image.lockFocus()
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: diameter, height: diameter).insetBy(dx: 0.5, dy: 0.5)).fill()
    image.unlockFocus()
    image.isTemplate = false
    return image
}

/// Compact breakdown for the menu bar, e.g. "● 1  ● 2" with per-state colors.
/// Shows every non-empty state so a single color never implies "all agents".
func menuBarTitle(_ counts: StatusCounts) -> NSAttributedString {
    let result = NSMutableAttributedString()

    guard counts.total > 0 else {
        result.append(dot(.tertiaryLabelColor))
        result.append(NSAttributedString(string: " 0", attributes: [
            .foregroundColor: NSColor.tertiaryLabelColor, .font: countFont,
        ]))
        return result
    }

    for (index, entry) in counts.present.enumerated() {
        if index > 0 {
            result.append(NSAttributedString(string: "  ", attributes: [.font: countFont]))
        }
        result.append(dot(entry.state.color))
        result.append(NSAttributedString(string: "\u{2009}\(entry.count)", attributes: [
            .font: countFont,
        ]))
    }
    return result
}

/// Human-readable one-liner, e.g. "1 needs you · 2 working · 3 idle".
func summaryText(_ counts: StatusCounts) -> String {
    guard counts.total > 0 else { return "No running agents" }
    var parts: [String] = []
    if counts.waiting > 0 { parts.append("\(counts.waiting) needs you") }
    if counts.working > 0 { parts.append("\(counts.working) working") }
    if counts.idle > 0 { parts.append("\(counts.idle) idle") }
    return parts.joined(separator: " · ")
}
