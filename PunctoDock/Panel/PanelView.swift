import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
        // Preview is now a separate NSPanel at .popUpMenu level (above .floating),
        // managed by PanelController. Nothing to render here.
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
            tabButton("Symbols",   tab: .symbols)
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
                            // .equatable() lets SwiftUI skip the render when the row
                            // has not visually changed. This prevents a full 50-row
                            // re-render (with expensive per-row accessibility lookups)
                            // every time a single new entry is added.
                            ClipboardRow(
                                entry: entry,
                                onInsert:         { vm.insertClipboardEntry(entry) },
                                onTogglePin:      { vm.togglePin(entry.id) },
                                onDelete:         { vm.deleteClipboardEntry(entry.id) },
                                onClearKeepPins:  { vm.clearClipboard(keepPinned: true) },
                                onClearAll:       { vm.clearClipboard(keepPinned: false) },
                                onReveal:         { vm.revealInFinder(entry) },
                                onPreview:        { showing in vm.previewEntry = showing ? entry : nil }
                            )
                            .equatable()
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
            Text("Nothing copied yet")
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
                sectionLabel("Symbols")
                symbolGrid(vm.sortedSingles, startIndex: 0)

                Divider().opacity(0.35).padding(.vertical, 1)

                sectionLabel("Pairs")
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
///
/// Conforms to `Equatable` so that `.equatable()` can tell SwiftUI "this row has not
/// changed" when unrelated entries are added/removed. Without this, a single new entry
/// causes all 50 rows to re-render and compute expensive SF-Symbol accessibility labels
/// for every menu item — which blocked the main thread for ~1.5 s in profiling.
/// We compare only the fields that actually affect the visual: `id`, `isPinned`, and
/// `contentType`. Closures are intentionally excluded (they don't affect rendering).
private struct ClipboardRow: View, Equatable {
    let entry: ClipboardEntry
    let onInsert: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onClearKeepPins: () -> Void
    let onClearAll: () -> Void
    let onReveal: () -> Void
    let onPreview: (Bool) -> Void

    static func == (lhs: ClipboardRow, rhs: ClipboardRow) -> Bool {
        lhs.entry.id          == rhs.entry.id       &&
        lhs.entry.isPinned    == rhs.entry.isPinned  &&
        lhs.entry.contentType == rhs.entry.contentType
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // contextMenu lives on the Button (not the ZStack) so left-click fires
            // onInsert directly; right-click shows the context menu.
            Button(action: onInsert) { content }
                .buttonStyle(CardButtonStyle())
                .contextMenu { menuItems }

            HStack(spacing: 2) {
                // Subtle pin indicator — only visible when the entry is pinned.
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.55))
                        .accessibilityHidden(true)
                }
                menuButton
            }
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
                ClipboardImageView(entry: entry, onPreview: onPreview)  // async load — no main-thread disk read
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
        .accessibilityLabel("Options")              // static string, no SF-Symbol bundle read
    }

    @ViewBuilder private var menuItems: some View {
        Button(entry.isPinned ? "Unpin" : "Pin", action: onTogglePin)
        if entry.contentType == .image {
            Button("Show in Finder", action: onReveal)
        }
        Divider()
        Button("Delete", role: .destructive, action: onDelete)
        Divider()
        Button("Clear all (keep pinned)", action: onClearKeepPins)
        Button("Clear all (with pinned)", role: .destructive, action: onClearAll)
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
///
/// Supports drag-and-drop: the user can drag a copied image directly onto a browser
/// upload field, Finder folder, or any image-accepting drop target. A subtle icon
/// appears on hover to hint at this capability. The image is exported to a temp file
/// with the correct extension (`.png`, `.jpg`, etc.) so all targets can read it.
private struct ClipboardImageView: View {
    let entry: ClipboardEntry
    /// Hover callback for the enlarge affordance: true while the pointer is over the
    /// expand badge (show the lightbox), false when it leaves (hide it). No click needed.
    let onPreview: (Bool) -> Void
    @State private var image: NSImage?
    @State private var hovering = false

    private let thumbSize: CGFloat = 60

    // Horizontal media card: preview on the LEFT, caption + file type stacked next to it.
    // The hamburger menu (owned by ClipboardRow) stays in the top-right corner untouched.
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 0) {
                Text(label)                         // Beschriftung — top of the tile
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(typeToken)                     // Dateiart — bottom of the tile
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(height: thumbSize, alignment: .leading)
            .opacity(0.8)                           // ~20% more subtle / less glaring
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .task(id: entry.id) {
            // Disk read on a background thread; only Data (Sendable) crosses the boundary.
            let data = await Task.detached(priority: .utility) {
                entry.imageData
            }.value
            guard let data else { return }
            image = NSImage(data: data)
        }
    }

    // Left-aligned, fixed-size preview tile so the medium never floats centred in free
    // space. Still draggable (drag-to-upload preserved). On hover it reveals the expand
    // badge in its bottom-right corner.
    private var thumbnail: some View {
        Group {
            if let img = image {
                imageContent(img)
            } else {
                Color.clear
            }
        }
        .frame(width: thumbSize, height: thumbSize)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if hovering, image != nil { expandBadge }
        }
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { h in
            hovering = h
            if !h { onPreview(false) }   // leaving the medium always closes the lightbox
        }
        // Drag-to-upload: drag this image to a browser upload field, Finder, or any
        // image-accepting app. The temp file is kept until the next app launch.
        .onDrag { Self.dragProvider(for: entry) }
    }

    // Expand affordance: bottom-right, inside the medium, hover-only. Hovering it shows
    // the lightbox; un-hovering hides it again — no click involved.
    private var expandBadge: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .padding(4)
            .contentShape(Rectangle())
            .onHover { onPreview($0) }
            .help("Show a larger preview")
            .accessibilityLabel("Enlarge image")
    }

    // GIFs render through an NSImageView (animates = true) so they keep playing while the
    // panel is open; everything else uses the cheaper static SwiftUI Image. Both fit
    // inside the tile.
    @ViewBuilder private func imageContent(_ img: NSImage) -> some View {
        if isAnimated {
            AnimatedImageView(image: img)
                .accessibilityLabel("Animated image")
        } else {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("Image")
        }
    }

    // MARK: Caption helpers

    /// Top line ("Beschriftung"): pixel size when known, else a neutral label.
    private var label: String { dimensionText ?? "Image" }

    /// Bottom line ("Dateiart"): short uppercase file-type token, e.g. PNG / GIF / JPEG.
    private var typeToken: String {
        guard let raw = entry.imagePasteboardType, let ut = UTType(raw) else { return "IMG" }
        if ut.conforms(to: .jpeg) { return "JPEG" }
        return (ut.preferredFilenameExtension ?? "img").uppercased()
    }

    private var isAnimated: Bool {
        guard let raw = entry.imagePasteboardType, let ut = UTType(raw) else { return false }
        return ut.conforms(to: .gif)
    }

    /// Pixel dimensions read from the largest representation, e.g. "1280 × 720".
    private var dimensionText: String? {
        guard let rep = image?.representations.first, rep.pixelsWide > 0 else { return nil }
        return "\(rep.pixelsWide) × \(rep.pixelsHigh)"
    }

    // MARK: Drag provider

    /// Builds an NSItemProvider that delivers a real file on disk so drop targets
    /// (Finder, WhatsApp, browsers, image editors) all receive a proper file reference.
    ///
    /// Root cause of the previous version: registering under the IMAGE type identifier
    /// (e.g. "public.png") does NOT put "public.file-url" on the drag pasteboard —
    /// Finder and Electron/Catalyst apps look for "public.file-url" and reject the drop
    /// when it isn't there.
    ///
    /// Fix: NSItemProvider(object: NSURL) uses NSURL's NSItemProviderWriting conformance,
    /// which correctly advertises "public.file-url" on the drag pasteboard. We also
    /// register a lazy image-data representation so apps that prefer raw bytes (Sketch,
    /// Preview, Affinity …) can accept the drop without reading the file themselves.
    private static func dragProvider(for entry: ClipboardEntry) -> NSItemProvider {
        let typeStr = entry.imagePasteboardType ?? UTType.png.identifier
        let utType  = UTType(typeStr) ?? .png
        let ext     = utType.preferredFilenameExtension ?? "png"

        // Stable per-entry URL — hovering several times doesn't re-copy the file.
        let dragDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PunctoDock-drag", isDirectory: true)
        let tempURL = dragDir
            .appendingPathComponent(entry.id.uuidString)
            .appendingPathExtension(ext)

        let fm = FileManager.default
        if !fm.fileExists(atPath: tempURL.path) {
            guard let src = entry.imageFileURL, fm.fileExists(atPath: src.path) else {
                return NSItemProvider()
            }
            do {
                try fm.createDirectory(at: dragDir, withIntermediateDirectories: true)
                try fm.copyItem(at: src, to: tempURL)
            } catch {
                return NSItemProvider()
            }
        }

        // NSItemProvider(object: NSURL) is the correct way to drag a file on macOS.
        // NSURL's NSItemProviderWriting puts "public.file-url" on the pasteboard, which
        // Finder, Electron (WhatsApp, Slack …), and browser upload fields all require.
        let provider = NSItemProvider(object: tempURL as NSURL)
        provider.suggestedName = "image.\(ext)"

        // Lazy image-data fallback for apps that ask for the raw pixel type directly
        // (e.g. "public.png") instead of going via the file URL. Loaded from disk only
        // when the drop target actually requests it — no RAM cost until then.
        provider.registerDataRepresentation(
            forTypeIdentifier: utType.identifier,
            visibility: .all
        ) { completion in
            if let data = try? Data(contentsOf: tempURL) {
                completion(data, nil)
            } else {
                completion(nil, NSError(domain: "com.punctodock.drag", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "Image not found"]))
            }
            return nil
        }

        return provider
    }

}

// MARK: - AnimatedImageView

/// Thin AppKit bridge that plays animated GIFs. SwiftUI's `Image(nsImage:)` shows only
/// the first frame; `NSImageView.animates = true` plays every frame of a multi-frame
/// NSImage. Used for both the thumbnail and the enlarged preview.
/// Internal (not private) so PanelController can embed it in the preview NSPanel.
struct AnimatedImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        v.animates = true
        v.image = image
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return v
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image !== image { nsView.image = image }
        nsView.animates = true
    }
}

// MARK: - ImageLightboxContent

/// Content view for the enlarged image preview. Rendered inside its OWN NSPanel
/// (managed by PanelController at .popUpMenu level), so it is completely independent
/// from the transparent main panel and always renders in front of it.
/// Internal so PanelController.showPreviewPanel() can embed it via NSHostingView.
struct ImageLightboxContent: View {
    let entry: ClipboardEntry
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let img = image {
                previewContent(img)
                    .padding(14)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: entry.id) {
            let data = await Task.detached(priority: .utility) {
                entry.imageData
            }.value
            guard let data else { return }
            image = NSImage(data: data)
        }
    }

    @ViewBuilder private func previewContent(_ img: NSImage) -> some View {
        let animated = (entry.imagePasteboardType.flatMap { UTType($0) }?.conforms(to: .gif)) ?? false
        if animated {
            AnimatedImageView(image: img)
        } else {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
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
