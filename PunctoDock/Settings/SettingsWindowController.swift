import AppKit
import SwiftUI

/// Manages the one reusable settings window. Because the app is an accessory
/// (no Dock icon), we explicitly activate when showing so the window can take focus.
final class SettingsWindowController {
    private let appState: AppState
    private var window: NSWindow?

    init(appState: AppState) { self.appState = appState }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(appState: appState))
            let win = NSWindow(contentViewController: hosting)
            win.title = "PunctoDock"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.setContentSize(NSSize(width: 470, height: 600))
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
