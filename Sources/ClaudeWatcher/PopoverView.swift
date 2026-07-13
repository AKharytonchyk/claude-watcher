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
                        AgentRowView(agent: agent, onOpen: onOpen, onOpenPR: onOpenPR)
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
            Text("\(model.agents.count) agent\(model.agents.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
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
                        Text(agent.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(stateLine)
                            .font(.system(size: 11, weight: agent.state == .waiting ? .semibold : .regular))
                            .foregroundStyle(agent.state == .waiting ? AnyShapeStyle(color(.waiting)) : AnyShapeStyle(.secondary))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }

                    if let intent = agent.intent {
                        Text(intent)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
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
            Spacer(minLength: 0)
        }
    }
}

/// GitHub-style PR pill: solid green (open) / gray (draft), with the
/// pull-request glyph. Clickable to open the PR in the browser.
struct PRPill: View {
    let pr: PRInfo
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.pull")
                Text("#\(pr.number)")
                if pr.isDraft {
                    Text("draft").opacity(0.9)
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(pr.isDraft ? Color.gray : Color(red: 0.13, green: 0.55, blue: 0.24),
                        in: Capsule())
            .opacity(hovering ? 0.85 : 1)
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
