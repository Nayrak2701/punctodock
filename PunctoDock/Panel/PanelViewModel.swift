import SwiftUI

/// Drives the panel UI: which tab is active, keyboard selection in the symbols grid,
/// and the live list of clipboard entries. Pure view state — side effects are routed
/// through callbacks to PanelController / AppState.
final class PanelViewModel: ObservableObject {

    enum PanelTab { case clipboard, symbols, emoji }

    @Published var activeTab: PanelTab = .clipboard
    @Published var selectedIndex: Int  = 0
    @Published var clipboardEntries: [ClipboardEntry] = []

    let symbolColumns = 6
    let singles = SymbolCatalog.singles
    let pairs   = SymbolCatalog.pairs
    /// Re-ordered by usage frequency each time the panel opens; falls back to catalog order.
    @Published var sortedSingles: [Symbol] = SymbolCatalog.singles

    var allSymbols: [Symbol] { sortedSingles + pairs }

    // MARK: Callbacks

    var onSelect:          ((Symbol) -> Void)?
    var onOpenEmoji:       (() -> Void)?
    var onInsertClipboard: ((ClipboardEntry) -> Void)?
    var onTogglePin:       ((UUID) -> Void)?
    var onDeleteClipboard: ((UUID) -> Void)?
    var onClearClipboard:  ((Bool) -> Void)?

    // MARK: Lifecycle

    func reset() {
        activeTab    = .clipboard
        selectedIndex = 0
    }

    // MARK: Tab selection

    func selectTab(_ tab: PanelTab) {
        if tab == .emoji { onOpenEmoji?(); return }
        withAnimation(.easeOut(duration: 0.12)) { activeTab = tab }
        selectedIndex = 0
    }

    // MARK: Symbol keyboard navigation (symbols tab only)

    func activateSelection() {
        guard activeTab == .symbols else { return }
        guard allSymbols.indices.contains(selectedIndex) else { return }
        onSelect?(allSymbols[selectedIndex])
    }

    func moveLeft()  { move(by: -1) }
    func moveRight() { move(by:  1) }
    func moveUp()    { move(by: -symbolColumns) }
    func moveDown()  { move(by:  symbolColumns) }

    private func move(by delta: Int) {
        guard activeTab == .symbols else { return }
        let count = allSymbols.count
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
    }

    // MARK: Clipboard actions (forwarded to controller)

    func insertClipboardEntry(_ entry: ClipboardEntry) { onInsertClipboard?(entry) }
    func togglePin(_ id: UUID)                         { onTogglePin?(id) }
    func deleteClipboardEntry(_ id: UUID)              { onDeleteClipboard?(id) }
    func clearClipboard(keepPinned: Bool)              { onClearClipboard?(keepPinned) }
}
