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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard. A second copy (e.g. an orphaned Xcode-run build still
        // alive when a new one launches) would register the same global hotkey and show
        // its own — possibly stale — panel, which is exactly what caused the "old panel
        // flashes first" symptom. If another PunctoDock is already running, terminate.
        if isAnotherInstanceRunning() {
            NSApp.terminate(nil)
            return
        }

        // Background utility: no Dock icon, no menu bar. The app icon still launches it.
        NSApp.setActivationPolicy(.accessory)

        appState = AppState()
        triggerManager = TriggerManager()
        panelController = PanelController(appState: appState)
        settingsWindow = SettingsWindowController(appState: appState)

        // Any trigger toggles the panel (source is used for a mouse-only reopen guard).
        triggerManager.onTrigger = { [weak self] source in self?.panelController.toggle(source: source) }
        // Trigger-relevant settings changes re-arm the hotkey / mouse monitor.
        appState.onSettingsChanged = { [weak self] settings in self?.triggerManager.apply(settings) }
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
