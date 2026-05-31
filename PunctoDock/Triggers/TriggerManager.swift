import AppKit

/// Which input produced a trigger. The panel uses this to apply a mouse-only
/// reopen guard (see PanelController.toggle).
enum TriggerSource {
    case keyboard
    case mouse
}

/// Coordinates the two trigger sources (global hotkey + middle-button double-click)
/// and fires a single closure when either activates. Both may run in parallel.
/// Handlers are delivered on the main thread by the underlying monitors.
final class TriggerManager {
    private let hotkey = HotkeyManager()
    private let mouse = MouseTriggerMonitor()

    /// Invoked when any enabled trigger fires, with the source that fired it.
    var onTrigger: ((TriggerSource) -> Void)?

    init() {
        hotkey.setHandler { [weak self] in self?.onTrigger?(.keyboard) }
        mouse.setHandler  { [weak self] in self?.onTrigger?(.mouse) }
    }

    /// (Re)configure both trigger sources from the current settings.
    func apply(_ settings: AppSettings) {
        hotkey.update(combo: settings.keyboardTriggerEnabled ? settings.hotkey : nil)
        mouse.setEnabled(settings.mouseMiddleDoubleClickEnabled)
    }
}
