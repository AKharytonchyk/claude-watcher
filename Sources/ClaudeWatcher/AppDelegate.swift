import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let model = AgentsModel()
    private let popover = NSPopover()
    private var timer: Timer?
    private var watcher: FileWatcher?
    // FSEvents handles instant state changes; the timer only keeps the
    // "time in state" labels fresh, so it can be slow.
    private let refreshInterval: TimeInterval = 15.0

    // Edge-triggered "needs you" pulse.
    private var knownWaiting: Set<String> = []
    private var baselineTaken = false
    private var pulseTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu bar only, no Dock icon

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .transient
        popover.animates = true
        let hosting = NSHostingController(rootView: PopoverView(
            model: model,
            onOpen: { [weak self] agent in self?.focusSession(agent) },
            onOpenPR: { [weak self] url in self?.openPR(url) },
            onQuit: { NSApp.terminate(nil) }
        ))
        // Track the SwiftUI content's size so the popover resizes cleanly when
        // the (filtered) list grows/shrinks — otherwise the content drifts and
        // loses its padding.
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = [.preferredContentSize]
        }
        popover.contentViewController = hosting

        tick()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }

        // Instant updates the moment a watched session file changes.
        watcher = FileWatcher(paths: model.watchPaths) { [weak self] in
            self?.tick()
        }
        watcher?.start()
    }

    /// Refresh the model, repaint the menu bar icon, and pulse if a new agent
    /// just started needing you.
    private func tick() {
        model.refresh()
        if let button = statusItem.button {
            button.image = nil
            button.attributedTitle = menuBarTitle(model.counts)
            button.toolTip = summaryText(model.counts)
        }

        let waitingNow = Set(model.agents.filter { $0.state == .waiting }.map(\.id))
        if baselineTaken, !waitingNow.subtracting(knownWaiting).isEmpty {
            pulseIcon() // a NEW agent entered `waiting`
        }
        knownWaiting = waitingNow
        baselineTaken = true // don't pulse for agents already waiting at launch
    }

    /// Gentle "breathing" pulse of the menu-bar icon — ambient, no focus change.
    private func pulseIcon() {
        guard let button = statusItem.button else { return }
        pulseTimer?.invalidate()
        var step = 0
        let steps = 6 // ~3 fades over ~2.4s
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self, weak button] t in
            guard let button else { t.invalidate(); return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.38
                button.animator().alphaValue = (step % 2 == 0) ? 0.3 : 1.0
            }
            step += 1
            if step >= steps {
                t.invalidate()
                self?.pulseTimer = nil
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.25
                    button.animator().alphaValue = 1.0
                }
            }
        }
    }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        tick()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: - Actions

    private func focusSession(_ agent: AgentVM) {
        popover.performClose(nil)
        // iTerm → precise tab focus.
        if agent.hostKind == .iterm,
           let tty = TerminalFocus.tty(forPID: agent.pid),
           TerminalFocus.focusITerm(tty: tty) {
            return
        }
        // Other hosts (VS Code, Terminal, …) → bring the owning app forward.
        if let appPath = agent.hostAppPath {
            NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
            return
        }
        // Last resort → reveal the project folder.
        NSWorkspace.shared.open(URL(fileURLWithPath: agent.cwd))
    }

    private func openPR(_ urlString: String) {
        popover.performClose(nil)
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
