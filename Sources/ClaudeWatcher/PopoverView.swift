import SwiftUI

/// GitHub-flavored, system-theme-adaptive agent list shown in the popover.
struct PopoverView: View {
    @ObservedObject var model: AgentsModel
    var onOpen: (AgentVM) -> Void
    var onOpenPR: (String) -> Void
    var onQuit: () -> Void

    /// Active state filter (single-select, toggleable). nil = show all.
    @State private var filter: AgentState?
    /// Measured height of the row list, so the popover fits the content
    /// (up to `maxListHeight`) instead of a greedy scroll view leaving a gap.
    @State private var listHeight: CGFloat = 0
    private let maxListHeight: CGFloat = 440

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340, alignment: .topLeading)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("Claude Agents")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .help("Filter by state")
                    .padding(.trailing, 1)
                ForEach(chipStates, id: \.state) { entry in
                    FilterChip(state: entry.state, count: entry.count,
                               selected: filter == entry.state) {
                        filter = (filter == entry.state) ? nil : entry.state
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// States to show as chips: present states, plus the active filter even if
    /// it just emptied out (so it stays visible to toggle off).
    private var chipStates: [(state: AgentState, count: Int)] {
        var list = model.counts.present
        if let filter, !list.contains(where: { $0.state == filter }) {
            list.append((state: filter, count: 0))
            list.sort { $0.state.rawValue < $1.state.rawValue }
        }
        return list
    }

    private var visibleAgents: [AgentVM] {
        guard let filter else { return model.agents }
        return model.agents.filter { $0.state == filter }
    }

    /// Only surface the provider glyph when more than one agent type is present
    /// — otherwise it's redundant noise on every row.
    private var showProvider: Bool {
        Set(model.agents.map(\.providerID)).count > 1
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        let agents = visibleAgents
        if agents.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: filter != nil ? "line.3.horizontal.decrease.circle" : "moon.zzz")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                Text(filter != nil ? "No \(filter!.summaryWord) agents" : "No running agents")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(agents) { agent in
                        if let caption = agent.groupCaption {
                            Text(caption)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.top, 4)
                        }
                        AgentRowView(agent: agent, showProvider: showProvider,
                                     onOpen: onOpen, onOpenPR: onOpenPR)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ListHeightKey.self, value: proxy.size.height)
                })
            }
            .frame(height: min(max(listHeight, 1), maxListHeight))
            .onPreferenceChange(ListHeightKey.self) { listHeight = $0 }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button(action: onQuit) {
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .pointerStyleLink()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// One agent row: status dot, name + state, last intent, branch chip + PR pill.
/// Tapping the row jumps to iTerm; tapping the PR pill opens the PR.
struct AgentRowView: View {
    let agent: AgentVM
    var showProvider: Bool = false
    var onOpen: (AgentVM) -> Void
    var onOpenPR: (String) -> Void
    @State private var hovering = false

    var body: some View {
        Button { onOpen(agent) } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(color(agent.state))
                    .frame(width: 9, height: 9)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if showProvider {
                            Image(systemName: agent.providerSymbol)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .help("Agent: \(agent.providerName)")
                        }
                        Text(agent.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(stateLine)
                            .font(.system(size: 11, weight: agent.state == .waiting ? .semibold : .regular))
                            .foregroundStyle(agent.state == .waiting ? AnyShapeStyle(color(.waiting)) : AnyShapeStyle(.secondary))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if agent.hostKind != .unknown {
                            Image(systemName: agent.hostKind.symbol)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .help("Running in \(agent.hostKind.label)")
                        }
                    }

                    if let intent = agent.intent {
                        Text(intent)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    metaLine
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering ? Color.primary.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var stateLine: String {
        agent.timeText.isEmpty ? agent.stateText : "\(agent.stateText) · \(agent.timeText)"
    }

    @ViewBuilder private var metaLine: some View {
        HStack(spacing: 8) {
            if let branch = agent.branch {
                Label(branch, systemImage: "arrow.triangle.branch")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            } else {
                Text(agent.shortCwd)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let pr = agent.pr {
                PRPill(pr: pr) { onOpenPR(pr.url) }
            } else if agent.prPending {
                Text("PR …")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
            // Context pressure — quiet until it's actually close to compacting.
            if let pct = agent.contextPct, pct >= 0.6 {
                ContextText(pct: pct, tokens: agent.contextTokens, window: agent.contextWindow)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Context-pressure indicator: stays quiet (grey) until ~85%, then warms to
/// orange/red near the auto-compact cliff. No filled chip — deference.
struct ContextText: View {
    let pct: Double
    let tokens: Int?
    let window: Int?

    private var tint: AnyShapeStyle {
        if pct >= 0.95 { return AnyShapeStyle(.red) }
        if pct >= 0.85 { return AnyShapeStyle(.orange) }
        return AnyShapeStyle(.secondary)
    }

    var body: some View {
        Text("ctx \(Int((pct * 100).rounded()))%")
            .font(.system(size: 10, weight: pct >= 0.85 ? .semibold : .regular))
            .foregroundStyle(tint)
            .help(helpText)
    }

    private var helpText: String {
        guard let tokens, let window else { return "context usage" }
        return "\(formatTokens(tokens)) / \(formatTokens(window)) tokens — /compact before it auto-compacts"
    }
}

/// PR indicator: a tinted-outline pill (green = open, grey = draft) with the
/// pull-request glyph — quiet enough not to compete with the status dot.
/// Clickable to open the PR in the browser.
struct PRPill: View {
    let pr: PRInfo
    var action: () -> Void
    @State private var hovering = false

    private var tint: Color { pr.isDraft ? .secondary : .green }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.pull")
                Text("#\(pr.number)")
                if pr.isDraft { Text("draft").opacity(0.9) }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(tint.opacity(hovering ? 0.12 : 0), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Open PR #\(pr.number)")
    }
}

/// Measures the row list's natural height so the popover can fit it.
private struct ListHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// A single-select filter chip in the header: dot + count, highlighted when
/// active. Tap to filter to that state; tap again to clear.
struct FilterChip: View {
    let state: AgentState
    let count: Int
    let selected: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle().fill(color(state)).frame(width: 7, height: 7)
                Text("\(count)")
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? .primary : .secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? color(state).opacity(0.18)
                                   : (hovering ? Color.primary.opacity(0.12)
                                               : Color.primary.opacity(0.05)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selected ? color(state).opacity(0.55) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointerStyleLink()
        .help(selected ? "Show all agents" : "Show only \(state.summaryWord)")
    }
}

/// Traffic-light color for a state (system colors → light/dark automatic).
func color(_ state: AgentState) -> Color {
    switch state {
    case .waiting: return .red
    case .working: return .yellow
    case .idle:    return .green
    }
}

private extension View {
    /// Show the link/hand cursor on hover where available; no-op otherwise.
    @ViewBuilder func pointerStyleLink() -> some View {
        if #available(macOS 15.0, *) { self.pointerStyle(.link) } else { self }
    }
}
