import SwiftUI

/// Single source of truth for settings and usage, shared by the settings window
/// and the panel. Persists changes automatically. All access happens on the main
/// thread (driven by AppKit/SwiftUI), so no explicit actor isolation is needed.
final class AppState: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            PersistenceManager.shared.saveSettings(settings)
            onSettingsChanged?(settings)
        }
    }

    /// Live, UI-facing mirrors of system state (not persisted in our JSON).
    @Published var accessibilityTrusted: Bool
    @Published var loginItemEnabled: Bool

    private(set) var usage: UsageHistory
    @Published private(set) var clipboardHistory: ClipboardHistory

    /// Notifies the coordinator when trigger-relevant settings change.
    var onSettingsChanged: ((AppSettings) -> Void)?

    init() {
        settings         = PersistenceManager.shared.loadSettings()
        usage            = PersistenceManager.shared.loadUsage()
        clipboardHistory = PersistenceManager.shared.loadClipboard()
        accessibilityTrusted = PermissionManager.shared.isAccessibilityTrusted
        loginItemEnabled     = LoginItemManager.isEnabled
        setupClipboardMonitor()
    }

    // MARK: Clipboard monitoring

    private func setupClipboardMonitor() {
        let monitor = ClipboardMonitor.shared
        monitor.onNewText = { [weak self] text in
            DispatchQueue.main.async { self?.recordClipboardText(text) }
        }
        monitor.onNewImage = { [weak self] data, pbType in
            DispatchQueue.main.async { self?.recordClipboardImage(data, pasteboardType: pbType) }
        }
        monitor.start()
    }

    private func recordClipboardText(_ text: String) {
        clipboardHistory.addText(text)
        PersistenceManager.shared.saveClipboard(clipboardHistory)
    }

    private func recordClipboardImage(_ data: Data, pasteboardType: String) {
        clipboardHistory.addImage(data, pasteboardType: pasteboardType)
        PersistenceManager.shared.saveClipboard(clipboardHistory)
    }

    // MARK: Clipboard mutations

    func toggleClipboardPin(_ id: UUID) {
        clipboardHistory.togglePin(id)
        PersistenceManager.shared.saveClipboard(clipboardHistory)
    }

    func deleteClipboardEntry(_ id: UUID) {
        clipboardHistory.delete(id)
        PersistenceManager.shared.saveClipboard(clipboardHistory)
    }

    func clearClipboard(keepPinned: Bool) {
        clipboardHistory.clearAll(keepPinned: keepPinned)
        PersistenceManager.shared.saveClipboard(clipboardHistory)
    }

    /// The 11 single characters for the compact grid (the 12th slot is "More").
    func compactSlots() -> [String] {
        settings.prioritizeFrequentlyUsed
            ? usage.compactSlots()
            : Array(SymbolCatalog.compactDefaults.prefix(11))
    }

    func recordUsage(_ symbol: Symbol) {
        guard symbol.kind == .single else { return }
        usage.record(symbol.insert)
        PersistenceManager.shared.saveUsage(usage)
    }

    func resetUsage() {
        usage = UsageHistory()
        PersistenceManager.shared.saveUsage(usage)
    }

    func refreshSystemState() {
        accessibilityTrusted = PermissionManager.shared.isAccessibilityTrusted
        loginItemEnabled = LoginItemManager.isEnabled
    }

    func setLoginItem(_ enabled: Bool) {
        loginItemEnabled = LoginItemManager.setEnabled(enabled)
    }
}
