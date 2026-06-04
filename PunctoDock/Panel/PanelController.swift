import AppKit
import SwiftUI
import Carbon.HIToolbox
import UniformTypeIdentifiers

/// Owns the floating panel: shows/hides it near the mouse, wires keyboard navigation
/// and outside-click dismissal, and routes selections to InsertionManager / AppState.
///
/// Toggle behaviour: if the panel is already open when a trigger fires, it closes.
/// Mouse middle double-click needs a reopen guard (see `toggle(source:)`) because the
/// first click of the double-click can dismiss the panel before the second click's
/// trigger arrives — without the guard, the panel would immediately reopen.
final class PanelController {
    private let appState: AppState
    private var panel: FloatingPanel?
    private let vm = PanelViewModel()

    private var keyMonitor: Any?
    private var globalClickMonitor: Any?
    private var targetApp: NSRunningApplication?
    private var isClosing = false

    /// Uptime of the last *outside* dismissal (click elsewhere / key resignation).
    /// Used only to suppress a mouse-trigger reopen that belongs to the same gesture.
    private var lastOutsideDismissUptime: TimeInterval = 0
    /// Max gap covered by the reopen guard — must exceed the system double-click gap.
    private let reopenGuard: TimeInterval = 0.7

    private let panelSize = NSSize(width: 360, height: 430)

    init(appState: AppState) {
        self.appState = appState

        vm.onSelect = { [weak self] symbol in self?.commit(symbol) }
        vm.onOpenEmoji = { [weak self] in self?.openCharacterViewer() }

        vm.onInsertClipboard = { [weak self] entry in
            self?.commitClipboard(entry)
        }
        vm.onTogglePin = { [weak self] id in
            guard let self else { return }
            self.appState.toggleClipboardPin(id)
            self.vm.clipboardEntries = self.appState.clipboardHistory.entries
        }
        vm.onDeleteClipboard = { [weak self] id in
            guard let self else { return }
            self.appState.deleteClipboardEntry(id)
            self.vm.clipboardEntries = self.appState.clipboardHistory.entries
        }
        vm.onClearClipboard = { [weak self] keepPinned in
            guard let self else { return }
            self.appState.clearClipboard(keepPinned: keepPinned)
            self.vm.clipboardEntries = self.appState.clipboardHistory.entries
        }
        vm.onRevealInFinder = { [weak self] entry in self?.revealInFinder(entry) }
    }

    var isVisible: Bool { panel?.isVisible == true }

    // MARK: Trigger entry point

    /// True toggle. For mouse triggers, a reopen that lands right after an outside
    /// dismissal is treated as the second half of the same close gesture and ignored.
    func toggle(source: TriggerSource = .keyboard) {
        if isVisible { close(); return }

        if source == .mouse,
           ProcessInfo.processInfo.systemUptime - lastOutsideDismissUptime < reopenGuard {
            lastOutsideDismissUptime = 0
            return
        }
        show()
    }

    func show() {
        guard !isVisible else { return }
        targetApp = NSWorkspace.shared.frontmostApplication

        // Push fresh state into the view BEFORE the panel is on screen.
        vm.reset()
        vm.clipboardEntries = appState.clipboardHistory.entries

        // Sort singles by usage count (most-used first); Swift sort is stable so
        // symbols with equal counts keep their original catalog order.
        let counts = appState.usage.counts
        vm.sortedSingles = SymbolCatalog.singles.sorted {
            (counts[$0.insert] ?? 0) > (counts[$1.insert] ?? 0)
        }

        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.setContentSize(panelSize)
        positionNearMouse(panel)

        // Flash fix: reveal only after SwiftUI has rendered the reset state.
        // Showing at alpha 0 first hides any stale backing-store frame; we force a
        // layout pass, then flip to opaque on the next run loop (instant, no fade).
        panel.alphaValue = 0
        isClosing = false
        panel.makeKeyAndOrderFront(nil)
        panel.contentView?.layoutSubtreeIfNeeded()
        installMonitors()
        lastOutsideDismissUptime = 0

        DispatchQueue.main.async { [weak panel] in
            panel?.alphaValue = 1
        }
    }

    /// Plain close (selection / Escape / explicit toggle). Does NOT arm the reopen guard.
    func close() {
        guard let panel, !isClosing else { return }
        isClosing = true
        removeMonitors()
        panel.orderOut(nil)
        panel.alphaValue = 1   // reset so the next show() starts clean
        isClosing = false
    }

    /// Close caused by an outside click or key resignation. Arms the mouse reopen
    /// guard so the second click of a middle double-click doesn't immediately reopen.
    private func dismissFromOutside() {
        guard isVisible else { return }
        lastOutsideDismissUptime = ProcessInfo.processInfo.systemUptime
        close()
    }

    // MARK: Build

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: panelSize))
        let hosting = NSHostingView(rootView: PanelView(vm: vm))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = CGColor.clear  // no opaque backing → clean rounded corners
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.delegate = panelDelegate
        return panel
    }

    private lazy var panelDelegate = PanelWindowDelegate { [weak self] in
        self?.dismissFromOutside()
    }

    // MARK: Insertion — symbols

    private func commit(_ symbol: Symbol) {
        let target = targetApp
        close()
        appState.recordUsage(symbol)
        InsertionManager.shared.insert(symbol, into: target)
    }

    // MARK: Insertion — clipboard entries

    private func commitClipboard(_ entry: ClipboardEntry) {
        let target = targetApp
        close()
        ClipboardMonitor.shared.suppress(for: 1.0)
        switch entry.contentType {
        case .text:
            guard let text = entry.text else { return }
            InsertionManager.shared.insertText(text, into: target)
        case .image:
            guard let data = entry.imageData else { return }
            let pbType = NSPasteboard.PasteboardType(
                rawValue: entry.imagePasteboardType ?? NSPasteboard.PasteboardType.tiff.rawValue
            )
            InsertionManager.shared.insertImageData(data, as: pbType, into: target)
        }
    }

    private func openCharacterViewer() {
        close()
        NSApplication.shared.orderFrontCharacterPalette(nil)
    }

    // MARK: Reveal image in Finder

    /// Exports the stored image to a temp file with a sensible extension and reveals it
    /// in Finder. Stored entries are opaque `.bin` blobs, so we write a nicely-named
    /// copy the user can actually open or drag out.
    private func revealInFinder(_ entry: ClipboardEntry) {
        close()
        guard entry.contentType == .image, let data = entry.imageData else { return }
        let ext = Self.fileExtension(forPasteboardType: entry.imagePasteboardType)
        let name = "PunctoDock-image-\(entry.id.uuidString.prefix(8)).\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSLog("PunctoDock: reveal-in-Finder export failed: \(error.localizedDescription)")
        }
    }

    /// Maps a stored pasteboard-type identifier (e.g. "public.png") to a file extension.
    private static func fileExtension(forPasteboardType raw: String?) -> String {
        guard let raw, let ut = UTType(raw) else { return "png" }
        return ut.preferredFilenameExtension ?? "png"
    }

    // MARK: Positioning

    private func positionNearMouse(_ panel: FloatingPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = panel.frame.size
        let offset: CGFloat = 14

        var origin = NSPoint(x: mouse.x + offset, y: mouse.y - size.height - offset)

        if origin.x + size.width > visible.maxX { origin.x = mouse.x - size.width - offset }
        origin.x = min(max(origin.x, visible.minX + 4), visible.maxX - size.width - 4)

        if origin.y < visible.minY { origin.y = mouse.y + offset }
        origin.y = min(max(origin.y, visible.minY + 4), visible.maxY - size.height - 4)

        panel.setFrameOrigin(origin)
    }

    // MARK: Event monitors

    private func installMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            switch Int(event.keyCode) {
            case kVK_Escape:
                self.close(); return nil
            case kVK_LeftArrow:
                self.vm.moveLeft(); return nil
            case kVK_RightArrow:
                self.vm.moveRight(); return nil
            case kVK_UpArrow:
                self.vm.moveUp(); return nil
            case kVK_DownArrow:
                self.vm.moveDown(); return nil
            case kVK_Return, kVK_ANSI_KeypadEnter:
                self.vm.activateSelection(); return nil
            default:
                return event
            }
        }

        // Any click in another app dismisses the panel (and arms the reopen guard).
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.dismissFromOutside()
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        keyMonitor = nil
        globalClickMonitor = nil
    }
}

private final class PanelWindowDelegate: NSObject, NSWindowDelegate {
    private let onResignKey: () -> Void
    init(onResignKey: @escaping () -> Void) { self.onResignKey = onResignKey }
    func windowDidResignKey(_ notification: Notification) { onResignKey() }
}
