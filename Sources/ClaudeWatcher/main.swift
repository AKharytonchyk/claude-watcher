import AppKit

// Single-instance: if another copy is already running, quit before creating a
// status item — otherwise you get two menu-bar icons and two FSEvents watchers.
let bundleID = Bundle.main.bundleIdentifier ?? "com.akh.claude-watcher"
let myPID = ProcessInfo.processInfo.processIdentifier
if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    .contains(where: { $0.processIdentifier != myPID }) {
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
