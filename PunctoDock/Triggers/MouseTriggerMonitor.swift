import AppKit

/// Detects a double-click of the middle mouse button (the scroll-wheel click).
/// Uses passive NSEvent monitors, which for mouse events do NOT require
/// Accessibility permission. Global monitor catches clicks in other apps;
/// the local monitor covers clicks while one of our own windows is frontmost.
final class MouseTriggerMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var onTrigger: (() -> Void)?

    private var lastMiddleDownTime: TimeInterval = 0
    /// Max gap between the two clicks. Falls back to the system double-click
    /// interval, clamped so it never gets unusably short or long.
    private var doubleClickInterval: TimeInterval {
        min(max(NSEvent.doubleClickInterval, 0.25), 0.6)
    }

    private let middleButtonNumber = 2

    func setHandler(_ handler: @escaping () -> Void) {
        onTrigger = handler
    }

    func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    private func start() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        lastMiddleDownTime = 0
    }

    private func handle(_ event: NSEvent) {
        guard event.buttonNumber == middleButtonNumber else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastMiddleDownTime <= doubleClickInterval {
            lastMiddleDownTime = 0 // consume, so a triple-click doesn't double-fire
            DispatchQueue.main.async { [weak self] in self?.onTrigger?() }
        } else {
            lastMiddleDownTime = now
        }
    }

    deinit { stop() }
}
