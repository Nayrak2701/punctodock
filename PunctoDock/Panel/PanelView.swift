import SwiftUI
import AppKit

/// The floating panel content. Transparent Liquid-Glass look that follows the system
/// Light/Dark Mode, compact insets, a segmented glass tab capsule and slim clipboard
/// cards. UI/styling only — all behaviour is routed through the view model.
struct PanelView: View {
    @ObservedObject var vm: PanelViewModel

    private let outerRadius: CGFloat = 14

    var body: some View {
        // One cohesive Liquid Glass surface for the whole panel. The transparent NSPanel
        // lets the glass sample the desktop/apps behind it; the GlassEffectContainer keeps
        // the panel and the active-tab glass in a single sampling context so they read as
        // one continuous Apple material. Follows the system Light/Dark Mode automatically.
        GlassEffectContainer {
            mainContent
                .glassEffect(in: RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 7)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Tab Bar (segmented glass capsule)

    private var tabBar: some View {
        HStack(spacing: 2) {
            tabButton("Clipboard", tab: .clipboard)
            tabButton("Symbole",   tab: .symbols)
            tabButton("Emoji",     tab: .emoji)
        }
        .padding(2)
        // No track background: the tab row sits directly on the panel's Liquid Glass.
    }

    private func tabButton(_ title: String, tab: PanelViewModel.PanelTab) -> some View {
        let isActive = vm.activeTab == tab
        return Button { vm.selectTab(tab) } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .opacity(isActive ? 1.0 : 0.5)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(activePill(isActive))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)   // suppress blue NSFocusRing on tab buttons
    }

    @ViewBuilder private func activePill(_ isActive: Bool) -> some View {
        if isActive {
            // The selected segment lifts as its own glass element. It lives inside the
            // body's GlassEffectContainer, so it samples and merges with the panel glass
            // rather than stacking an opaque material on top.
            Color.clear
                .glassEffect(in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Color.clear
        }
    }

    // MARK: Tab Content

    @ViewBuilder private var tabContent: some View {
        switch vm.activeTab {
        case .clipboard: clipboardTab
        case .symbols:   symbolsTab
        case .emoji:     EmptyView()
        }
    }

    // ──────────────────────────────────────────
    // MARK: Clipboard Tab — slim cards, no header/title
    // ──────────────────────────────────────────

    private var clipboardTab: some View {
        Group {
            if vm.clipboardEntries.isEmpty {
                clipboardEmptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(vm.clipboardEntries) { entry in
                            ClipboardRow(
                                entry: entry,
                                onInsert:         { vm.insertClipboardEntry(entry) },
                                onTogglePin:      { vm.togglePin(entry.id) },
                                onDelete:         { vm.deleteClipboardEntry(entry.id) },
                                onClearKeepPins:  { vm.clearClipboard(keepPinned: true) },
                                onClearAll:       { vm.clearClipboard(keepPinned: false) }
                            )
                        }
                    }
                    // Suppress Liquid Glass motion-vector recalculations when the list mutates.
                    .animation(nil, value: vm.clipboardEntries)
                    .padding(.horizontal, 8)
                    .padding(.top, 1)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var clipboardEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clipboard")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)          // purely decorative — no disk symbol lookup
            Text("Noch nichts kopiert")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ──────────────────────────────────────────
    // MARK: Symbols Tab
    // ──────────────────────────────────────────

    private var symbolsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Zeichen")
                symbolGrid(vm.sortedSingles, startIndex: 0)

                Divider().opacity(0.35).padding(.vertical, 1)

                sectionLabel("Paare & Bausteine")
                symbolGrid(vm.pairs, startIndex: vm.singles.count)
            }
            .padding(.horizontal, 10)
            .padding(.top, 1)
            .padding(.bottom, 10)
        }
    }

    private func symbolGrid(_ symbols: [Symbol], startIndex: Int) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 5), count: vm.symbolColumns)
        return LazyVGrid(columns: cols, spacing: 5) {
            ForEach(Array(symbols.enumerated()), id: \.element.id) { i, symbol in
                let idx = startIndex + i
                SymbolTile(
                    label: symbol.label,
                    isSelected: idx == vm.selectedIndex && vm.activeTab == .symbols
                ) {
                    vm.onSelect?(symbol)
                }
                .frame(height: 38)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
    }
}

// MARK: - ClipboardRow

/// One clipboard entry as a slim, lightly tinted glass card. Tap inserts; the
/// hamburger button and a right-click context menu expose pin/delete. Hover and
/// press are reflected only through subtle material brightness (handled in the style).
private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let onInsert: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onClearKeepPins: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // contextMenu lives on the Button (not the ZStack) so left-click fires
            // onInsert directly; right-click shows the context menu.
            Button(action: onInsert) { content }
                .buttonStyle(CardButtonStyle())
                .contextMenu { menuItems }

            menuButton
                .padding(.top, 5)
                .padding(.trailing, 5)
        }
    }

    // Card body. Text uses nearly the full width up to the hamburger area.
    private var content: some View {
        Group {
            switch entry.contentType {
            case .text:
                Text(entry.text ?? "")
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .image:
                ClipboardImageView(entry: entry)     // async load — no main-thread disk read
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 30)   // keep text clear of the hamburger
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var menuButton: some View {
        Menu { menuItems } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
                .accessibilityHidden(true)          // label provided on the Menu; avoids disk lookup
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Optionen")             // static string, no SF-Symbol bundle read
    }

    @ViewBuilder private var menuItems: some View {
        Button(entry.isPinned ? "Lösen" : "Anpinnen", action: onTogglePin)
        Divider()
        Button("Löschen", role: .destructive, action: onDelete)
        Divider()
        Button("Alle löschen (Pins behalten)", action: onClearKeepPins)
        Button("Alle löschen (auch Pins)", role: .destructive, action: onClearAll)
    }
}

// MARK: - CardButtonStyle

/// Subtle, scroll-safe card styling: lightly tinted glass that brightens a touch on
/// hover and a bit more while pressed. No motion animations.
private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CardButtonBody(configuration: configuration)
    }
}

/// Separate view so it can hold `@State` for hover; named to avoid colliding with
/// ButtonStyle's `Body` associated type.
private struct CardButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovering = false

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(fill)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .onHover { hovering = $0 }
    }

    // Cards are content, not navigation: per Apple's Materials guidance they carry only a
    // very light tint and let the panel's Liquid Glass show through. At rest the card is
    // nearly clear; hover and press add a faint lift. No border — definition comes from
    // the glass behind it and the row spacing, not a drawn grey box.
    private var fill: Color {
        if configuration.isPressed { return Color.primary.opacity(0.10) }
        if hovering                { return Color.primary.opacity(0.06) }
        return Color.primary.opacity(0.03)
    }
}

// MARK: - ClipboardImageView

/// Loads the image for a clipboard entry asynchronously so the main thread never
/// blocks on a disk read. Shows a neutral placeholder while loading.
private struct ClipboardImageView: View {
    let entry: ClipboardEntry
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Bild")
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 40)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 70, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .task(id: entry.id) {
            // Disk read on a background thread; only Data (Sendable) crosses the boundary.
            let data = await Task.detached(priority: .utility) {
                entry.imageData
            }.value
            guard let data else { return }
            image = NSImage(data: data)
        }
    }
}

// MARK: - SymbolTile

struct SymbolTile: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(fill)
        )
        .overlay(
            // Edge only on the selected tile (functional accent). Unselected tiles stay
            // borderless so the panel's Liquid Glass shows through instead of a grey box.
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 1.5)
                .opacity(isSelected ? 1 : 0)
        )
        .onHover { hovering = $0 }
    }

    private var fill: Color {
        if isSelected { return Color.accentColor.opacity(0.16) }   // functional selection tint
        if hovering   { return Color.primary.opacity(0.08) }
        return Color.primary.opacity(0.03)
    }
}
