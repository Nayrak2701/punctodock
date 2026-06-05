import AppKit
import SwiftUI
import Carbon.HIToolbox
import UniformTypeIdentifiers
import Combine

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

    // MARK: Image preview (separate NSPanel above .floating)
    /// Dedicated panel at .popUpMenu level so the preview is always rendered in its own
    /// compositing layer, visually in front of the transparent main panel. Mouse events
    /// pass through (ignoresMouseEvents = true) so hover tracking continues beneath.
    private var previewPanel: NSPanel?
    private var previewCancellable: AnyCancellable?

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

        // Observe previewEntry: show/hide the dedicated preview NSPanel.
        // receive(on: main) because @Published sinks can fire on any queue.
        previewCancellable = vm.$previewEntry
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entry in
                if let entry { self?.showPreviewPanel(for: entry) }
                else         { self?.hidePreviewPanel() }
            }
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
        hidePreviewPanel()         // always dismiss the preview when the main panel closes
        vm.previewEntry = nil      // keep vm state in sync
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
        guard entry.contentType == .image else { return }
        let ext = Self.fileExtension(forPasteboardType: entry.imagePasteboardType)
        let name = "PunctoDock-image-\(entry.id.uuidString.prefix(8)).\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        // Read the (up-to-10 MB) bytes and write the temp copy off the main thread; only
        // the Finder reveal hops back to main. Finder activation is inherently async and
        // far slower than this hop, so the result is imperceptible while the disk I/O no
        // longer blocks the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = entry.imageData else { return }
            do {
                try data.write(to: url, options: .atomic)
                DispatchQueue.main.async {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } catch {
                NSLog("PunctoDock: reveal-in-Finder export failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Image preview panel

    /// Shows (or repositions) a dedicated NSPanel at .popUpMenu level centred over the
    /// main panel. Because the preview panel has its own compositing context and sits
    /// above the transparent main panel in the window server order, the image is always
    /// rendered in front — unlike a SwiftUI overlay inside the main panel which is
    /// subject to the same Vibrancy/transparency compositing as the rest of the glass.
    private func showPreviewPanel(for entry: ClipboardEntry) {
        guard let mainPanel = panel else { return }

        let size = NSSize(width: 320, height: 320)

        if previewPanel == nil {
            let p = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            p.level         = .popUpMenu        // above .floating — always in front
            p.isFloatingPanel = true
            p.isOpaque      = true              // own compositing layer, no see-through
            p.backgroundColor = NSColor(white: 0.13, alpha: 1)   // dark opaque card
            p.hasShadow     = true
            p.hidesOnDeactivate = false
            p.collectionBehavior = [.canJoinAllSpaces, .transient]
            p.ignoresMouseEvents = true         // events pass through → hover in main panel stays active
            previewPanel = p
        }

        let p = previewPanel!
        // Centre over the main panel
        let mf = mainPanel.frame
        let origin = NSPoint(x: mf.midX - size.width / 2, y: mf.midY - size.height / 2)
        p.setFrameOrigin(origin)
        p.setContentSize(size)

        // Rebuild content for this entry (cheap; only called on hover)
        let hosting = NSHostingView(rootView: ImageLightboxContent(entry: entry))
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 14
        hosting.layer?.masksToBounds = true
        hosting.autoresizingMask = [.width, .height]
        p.contentView = hosting

        p.orderFront(nil)
    }

    private func hidePreviewPanel() {
        previewPanel?.orderOut(nil)
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

    func windowDidResignKey(_ notification: Notification) {
        // When the user drags an image from the panel to another app the panel
        // transiently loses key status. NSEvent.pressedMouseButtons bit-0 is the
        // left button; if it is still held the user is mid-drag — don't close.
        guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
        onResignKey()
    }
}
