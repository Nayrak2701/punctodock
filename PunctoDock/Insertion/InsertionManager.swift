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

    /// Timing of the synthetic-paste sequence. Tuned for reliability across slow,
    /// asynchronous text surfaces (Mac Catalyst / Electron apps such as WhatsApp,
    /// Slack and Discord) without making insertion feel sluggish in fast apps.
    private enum Timing {
        /// Time for focus to settle on the target after `activate()` before ⌘V.
        static let settleWithTarget: TimeInterval = 0.08
        static let settleNoTarget:   TimeInterval = 0.03
        /// Gap after ⌘V before moving the caret between a pair.
        static let afterPaste: TimeInterval = 0.06
        /// Gap before restoring the user's clipboard. Must outlast the target's
        /// (possibly asynchronous) pasteboard read, or a slow app would paste the
        /// just-restored original clipboard instead of our content.
        static let beforeRestore: TimeInterval = 0.18
        /// How long the clipboard monitor ignores our own writes (write + restore).
        static let monitorSuppression: TimeInterval = 1.5
    }

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
        performPaste(into: targetApp, caretBackSteps: symbol.caretBackSteps) { pb in
            pb.setString(symbol.insert, forType: .string)
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
        performPaste(into: targetApp) { pb in
            pb.setString(text, forType: .string)
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
        performPaste(into: targetApp) { pb in
            let item = NSPasteboardItem()
            item.setData(data, forType: type)
            pb.writeObjects([item])
        }
    }

    // MARK: Shared paste sequence

    /// The single, hardened paste path used by every insertion: suppress the monitor,
    /// snapshot the clipboard, write our content, bring the target forward, paste with
    /// ⌘V after a settle delay, optionally reposition the caret, then restore the
    /// user's original clipboard once the target has had time to read ours.
    private func performPaste(into targetApp: NSRunningApplication?,
                              caretBackSteps: Int = 0,
                              write: (NSPasteboard) -> Void) {
        ClipboardMonitor.shared.suppress(for: Timing.monitorSuppression)
        let snapshot = ClipboardSnapshot.capture()

        // Make sure the intended target is frontmost before we paste.
        targetApp?.activate()

        let pb = NSPasteboard.general
        pb.clearContents()
        write(pb)

        let settle = targetApp == nil ? Timing.settleNoTarget : Timing.settleWithTarget
        DispatchQueue.main.asyncAfter(deadline: .now() + settle) { [weak self] in
            guard let self else { return }
            self.postCommandV()
            DispatchQueue.main.asyncAfter(deadline: .now() + Timing.afterPaste) {
                for _ in 0..<caretBackSteps {
                    self.postKey(CGKeyCode(kVK_LeftArrow))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Timing.beforeRestore) {
                    snapshot.restore()
                }
            }
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
