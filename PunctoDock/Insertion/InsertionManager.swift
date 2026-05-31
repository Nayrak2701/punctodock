import AppKit
import Carbon.HIToolbox

/// Inserts a symbol into whatever app currently has the text caret, via the
/// save-clipboard → set → ⌘V → (optional caret move) → restore-clipboard strategy.
///
/// This is the most reliable approach that works in arbitrary third-party apps
/// (Word, browsers, Notes, web text fields): it relies only on the standard Paste
/// command, which essentially every text surface implements. The user's original
/// clipboard is always restored.
final class InsertionManager {
    static let shared = InsertionManager()
    private init() {}

    enum Result {
        case inserted
        case copiedOnly   // no Accessibility permission: text left on clipboard as fallback
    }

    private let eventSource = CGEventSource(stateID: .combinedSessionState)

    /// Inserts `symbol` into `targetApp` (the app that was frontmost at trigger time).
    /// Returns immediately; the paste/restore happens on a short timed sequence.
    @discardableResult
    func insert(_ symbol: Symbol, into targetApp: NSRunningApplication?) -> Result {
        guard PermissionManager.shared.isAccessibilityTrusted else {
            // Honest fallback: at least leave the character on the clipboard so the
            // user can paste it manually. We do NOT pretend the insert succeeded.
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(symbol.insert, forType: .string)
            return .copiedOnly
        }

        ClipboardMonitor.shared.suppress(for: 1.0)
        let snapshot = ClipboardSnapshot.capture()

        // Make sure the intended target is frontmost before we paste.
        targetApp?.activate()

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(symbol.insert, forType: .string)

        // Give focus a moment to settle on the target, then paste.
        let pasteDelay: TimeInterval = targetApp == nil ? 0.02 : 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) { [weak self] in
            guard let self else { return }
            self.postCommandV()

            // After the paste lands, optionally move the caret between a pair.
            let afterPaste: TimeInterval = 0.06
            DispatchQueue.main.asyncAfter(deadline: .now() + afterPaste) {
                for _ in 0..<symbol.caretBackSteps {
                    self.postKey(CGKeyCode(kVK_LeftArrow))
                }
                // Restore only after the target has finished reading the pasteboard.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    snapshot.restore()
                }
            }
        }
        return .inserted
    }

    // MARK: Clipboard-entry insertion

    func insertText(_ text: String, into targetApp: NSRunningApplication?) {
        guard PermissionManager.shared.isAccessibilityTrusted else {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
            return
        }
        let snapshot = ClipboardSnapshot.capture()
        targetApp?.activate()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        let delay: TimeInterval = targetApp == nil ? 0.02 : 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.postCommandV()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { snapshot.restore() }
        }
    }

    func insertImageData(_ data: Data, as type: NSPasteboard.PasteboardType,
                         into targetApp: NSRunningApplication?) {
        guard PermissionManager.shared.isAccessibilityTrusted else {
            let pb = NSPasteboard.general
            pb.clearContents()
            let item = NSPasteboardItem()
            item.setData(data, forType: type)
            pb.writeObjects([item])
            return
        }
        let snapshot = ClipboardSnapshot.capture()
        targetApp?.activate()
        let pb = NSPasteboard.general
        pb.clearContents()
        let item = NSPasteboardItem()
        item.setData(data, forType: type)
        pb.writeObjects([item])
        let delay: TimeInterval = targetApp == nil ? 0.02 : 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.postCommandV()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { snapshot.restore() }
        }
    }

    // MARK: CGEvent helpers

    private func postCommandV() {
        guard let down = CGEvent(keyboardEventSource: eventSource,
                                 virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let up = CGEvent(keyboardEventSource: eventSource,
                               virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func postKey(_ key: CGKeyCode) {
        guard let down = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: false)
        else { return }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

/// A best-effort snapshot of the general pasteboard that preserves every concrete
/// data representation we can read, so clipboard managers and rich content survive.
struct ClipboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture() -> ClipboardSnapshot {
        let pb = NSPasteboard.general
        let saved = (pb.pasteboardItems ?? []).map { item -> [NSPasteboard.PasteboardType: Data] in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            return dict
        }
        return ClipboardSnapshot(items: saved)
    }

    func restore() {
        let pb = NSPasteboard.general
        pb.clearContents()
        guard !items.isEmpty else { return }
        let restored = items.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(restored)
    }
}
