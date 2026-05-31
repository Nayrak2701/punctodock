import AppKit

/// A borderless, non-activating floating panel. `nonactivatingPanel` lets it become
/// the key window (so it can receive arrow/Enter/Escape) WITHOUT activating our app,
/// which keeps the target app frontmost so the synthesized paste lands there.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow
        // No forced appearance — panel follows the system Light/Dark Mode.
    }

    // Borderless windows return false by default; we need key status for keyboard nav.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
