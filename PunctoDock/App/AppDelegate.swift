import AppKit

/// App entry point and lifecycle owner. Runs as an accessory app (no Dock icon),
/// wires the trigger sources to the panel, and manages the settings window.
/// AppKit invokes all delegate callbacks on the main thread.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private var appState: AppState!
    private var triggerManager: TriggerManager!
    private var panelController: PanelController!
    private var settingsWindow: SettingsWindowController!
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard. A second copy (e.g. an orphaned Xcode-run build still
        // alive when a new one launches) would register the same global hotkey and show
        // its own — possibly stale — panel, which is exactly what caused the "old panel
        // flashes first" symptom. If another PunctoDock is already running, terminate.
        if isAnotherInstanceRunning() {
            NSApp.terminate(nil)
            return
        }

        // Background utility: no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        appState = AppState()
        triggerManager = TriggerManager()
        panelController = PanelController(appState: appState)
        settingsWindow = SettingsWindowController(appState: appState)

        // Optional menu bar item for quick access (toggleable in Settings).
        updateStatusItem(visible: appState.settings.showStatusItem)

        // Any trigger toggles the panel (source is used for a mouse-only reopen guard).
        triggerManager.onTrigger = { [weak self] source in self?.panelController.toggle(source: source) }
        // Settings changes re-arm the hotkey / mouse monitor and sync the menu bar icon.
        appState.onSettingsChanged = { [weak self] settings in
            self?.triggerManager.apply(settings)
            self?.updateStatusItem(visible: settings.showStatusItem)
        }
        triggerManager.apply(appState.settings)

        // Always start the AX check so the grant persists across Xcode rebuilds.
        // Shows the system prompt once if not yet trusted, then polls until granted.
        PermissionManager.shared.startAccessibilityCheck()

        if !appState.settings.hasCompletedOnboarding {
            // First run: explain via the settings window.
            appState.settings.hasCompletedOnboarding = true
            settingsWindow.show()
        } else if !LoginItemManager.isEnabled {
            // Manual launches show settings. When "start at login" is on we stay quiet
            // (that launch is the login one); clicking the app icon re-opens settings.
            settingsWindow.show()
        }
    }

    // MARK: Status Bar

    /// Shows or hides the menu bar item to match the user's preference. Idempotent:
    /// calling it with the current state is a no-op.
    private func updateStatusItem(visible: Bool) {
        if visible {
            guard statusItem == nil else { return }
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            guard let button = statusItem?.button else { return }

            // Use a simple clipboard SF Symbol as template (adapts to light/dark menu bar automatically).
            let img = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "PunctoDock")
            img?.isTemplate = true
            button.image = img
            button.toolTip = "PunctoDock — Click: open panel  |  Right-click: menu"
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        } else {
            guard let item = statusItem else { return }
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Settings…",
                         action: #selector(openSettings),
                         keyEquivalent: ",")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit PunctoDock",
                         action: #selector(NSApplication.terminate(_:)),
                         keyEquivalent: "q")
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil   // detach so left-click still works next time
        } else {
            panelController.toggle(source: .keyboard)
        }
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    /// Clicking the app icon again while running re-opens the settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// True if another process with the same bundle identifier is already running.
    private func isAnotherInstanceRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        return !others.isEmpty
    }
}
