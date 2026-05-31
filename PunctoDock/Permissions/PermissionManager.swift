import AppKit
import ApplicationServices

/// Wraps the Accessibility (AX) trust check used to synthesise the paste keystroke.
/// Accessibility is required ONLY for inserting into other apps (posting CGEvents);
/// it is not needed merely to show the panel or to detect the mouse trigger.
final class PermissionManager {
    static let shared = PermissionManager()
    private init() {}

    /// True when this process is trusted for Accessibility / control of the computer.
    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the system prompt that offers to open Accessibility settings.
    /// Safe to call repeatedly; macOS shows the prompt at most once per session.
    @discardableResult
    func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Opens System Settings directly at Privacy → Accessibility.
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
