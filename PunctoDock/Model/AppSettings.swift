import Foundation

/// All persisted user preferences. A plain Codable struct stored as JSON in
/// ~/Library/Application Support/com.punctodock.app/com.punctodock.settings.json.
///
/// Login-at-launch is intentionally NOT stored here: it is read live from
/// `SMAppService.mainApp.status` so the file never drifts from the real system state.
struct AppSettings: Codable, Equatable {
    // MARK: Triggers
    var keyboardTriggerEnabled: Bool
    var hotkey: KeyCombo
    var mouseMiddleDoubleClickEnabled: Bool

    // MARK: Behavior
    /// When true, the compact grid is reordered by usage frequency.
    var prioritizeFrequentlyUsed: Bool

    /// Whether the first-launch onboarding has been shown.
    var hasCompletedOnboarding: Bool

    /// When true, a clipboard history reset keeps pinned entries intact.
    var clipboardKeepPinnedOnReset: Bool

    /// When true, PunctoDock shows its icon in the menu bar (status item).
    var showStatusItem: Bool

    /// Fresh-install defaults: ⌥V on, mouse off, menu bar icon on.
    static let `default` = AppSettings(
        keyboardTriggerEnabled: true,
        hotkey: .defaultOptionV,
        mouseMiddleDoubleClickEnabled: false,
        prioritizeFrequentlyUsed: true,
        hasCompletedOnboarding: false,
        clipboardKeepPinnedOnReset: true,
        showStatusItem: true
    )

    // Tolerant decoding: missing keys fall back to defaults so older files keep working.
    init(keyboardTriggerEnabled: Bool, hotkey: KeyCombo,
         mouseMiddleDoubleClickEnabled: Bool, prioritizeFrequentlyUsed: Bool,
         hasCompletedOnboarding: Bool, clipboardKeepPinnedOnReset: Bool,
         showStatusItem: Bool) {
        self.keyboardTriggerEnabled = keyboardTriggerEnabled
        self.hotkey = hotkey
        self.mouseMiddleDoubleClickEnabled = mouseMiddleDoubleClickEnabled
        self.prioritizeFrequentlyUsed = prioritizeFrequentlyUsed
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.clipboardKeepPinnedOnReset = clipboardKeepPinnedOnReset
        self.showStatusItem = showStatusItem
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        keyboardTriggerEnabled = try c.decodeIfPresent(Bool.self, forKey: .keyboardTriggerEnabled) ?? d.keyboardTriggerEnabled
        hotkey = try c.decodeIfPresent(KeyCombo.self, forKey: .hotkey) ?? d.hotkey
        mouseMiddleDoubleClickEnabled = try c.decodeIfPresent(Bool.self, forKey: .mouseMiddleDoubleClickEnabled) ?? d.mouseMiddleDoubleClickEnabled
        prioritizeFrequentlyUsed = try c.decodeIfPresent(Bool.self, forKey: .prioritizeFrequentlyUsed) ?? d.prioritizeFrequentlyUsed
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? d.hasCompletedOnboarding
        clipboardKeepPinnedOnReset = try c.decodeIfPresent(Bool.self, forKey: .clipboardKeepPinnedOnReset) ?? d.clipboardKeepPinnedOnReset
        showStatusItem = try c.decodeIfPresent(Bool.self, forKey: .showStatusItem) ?? d.showStatusItem
    }
}
