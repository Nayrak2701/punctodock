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

    /// Shows the system Accessibility prompt (if not yet trusted) and then polls every
    /// 2 s until trust is granted. When granted, posts `AccessibilityGranted` on the
    /// default NotificationCenter so subscribers can react without polling themselves.
    func startAccessibilityCheck() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        if AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) { return }
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AccessibilityGranted"), object: nil
                    )
                }
            }
        }
    }

    /// Opens System Settings directly at Privacy → Accessibility.
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
