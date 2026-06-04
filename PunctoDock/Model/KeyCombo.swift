import AppKit
import Carbon.HIToolbox

/// A keyboard shortcut: a virtual key code plus modifier flags.
/// Used for both the default ⌥V trigger and any user-defined alternative.
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    /// Cocoa device-independent modifier flags, stored as raw UInt for Codable.
    var modifierFlagsRaw: UInt
    /// Base key label captured while recording (e.g. "7", "A", "F7"). Optional;
    /// falls back to a static name table when absent.
    var keyLabel: String?

    init(keyCode: UInt32, modifierFlags: NSEvent.ModifierFlags, keyLabel: String? = nil) {
        self.keyCode = keyCode
        self.modifierFlagsRaw = modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        self.keyLabel = keyLabel
    }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRaw).intersection(.deviceIndependentFlagsMask)
    }

    /// Default trigger: ⌥V (Option+V). An ergonomic combo that rarely collides with
    /// app shortcuts, while staying easy to reach one-handed.
    static let defaultOptionV = KeyCombo(keyCode: UInt32(kVK_ANSI_V), modifierFlags: .option, keyLabel: "V")

    /// Carbon modifier mask for RegisterEventHotKey.
    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        let f = modifierFlags
        if f.contains(.command) { m |= UInt32(cmdKey) }
        if f.contains(.option)  { m |= UInt32(optionKey) }
        if f.contains(.control) { m |= UInt32(controlKey) }
        if f.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }

    /// Human-readable representation, e.g. "⌃⌥7" or "F7".
    var displayString: String {
        modifierSymbols + (keyLabel ?? KeyCodeNames.name(for: keyCode))
    }

    private var modifierSymbols: String {
        var s = ""
        let f = modifierFlags
        if f.contains(.control) { s += "⌃" }
        if f.contains(.option)  { s += "⌥" }
        if f.contains(.shift)   { s += "⇧" }
        if f.contains(.command) { s += "⌘" }
        return s
    }
}

/// Minimal virtual-key-code → display-name table for keys we want to show nicely.
/// For ordinary character keys we instead store `keyLabel` at record time, so this
/// only needs to cover function/navigation keys and a sensible fallback.
enum KeyCodeNames {
    private static let table: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫",
        kVK_Escape: "⎋", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟"
    ]

    static func name(for keyCode: UInt32) -> String {
        table[Int(keyCode)] ?? "Key \(keyCode)"
    }
}
