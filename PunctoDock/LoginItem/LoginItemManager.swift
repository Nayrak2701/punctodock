import Foundation
import ServiceManagement

/// Opt-in "Start at login" using the modern SMAppService API (macOS 13+).
/// No separate helper target or login-item plist is required.
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns the resulting enabled state; on failure it returns the unchanged state.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("PunctoDock: login item toggle failed: \(error.localizedDescription)")
        }
        return isEnabled
    }
}
