import SwiftUI
import Carbon.HIToolbox

/// The single, small settings window. Trigger config, login item, character logic,
/// the menu bar icon and the Accessibility permission status — plus a short
/// first-run explainer.
struct SettingsView: View {
    @ObservedObject var appState: AppState

    @State private var recording = false
    @State private var keyMonitor: Any?

    private var noTriggerActive: Bool {
        !appState.settings.keyboardTriggerEnabled && !appState.settings.mouseMiddleDoubleClickEnabled
    }

    var body: some View {
        Form {
            intro
            triggerSection
            loginSection
            charactersSection
            clipboardSection
            menuBarSection
            permissionSection
            storageFooter
        }
        .formStyle(.grouped)
        .frame(width: 470)
        .frame(minHeight: 560)
        .onAppear { appState.refreshSystemState() }
        .onDisappear { stopRecording() }
    }

    // MARK: Intro

    private var intro: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("PunctoDock")
                    .font(.headline)
                Text("Press the trigger (default: ⌥V) to open a panel of punctuation and special characters near your cursor. The character you pick is inserted into the app where your text cursor is.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Trigger

    private var triggerSection: some View {
        Section("Trigger") {
            Toggle("Keyboard trigger", isOn: $appState.settings.keyboardTriggerEnabled)

            HStack {
                Text("Shortcut")
                Spacer()
                Button {
                    toggleRecording()
                } label: {
                    Text(recording ? "Press a key…" : appState.settings.hotkey.displayString)
                        .frame(minWidth: 70)
                        .monospacedDigit()
                }
                .disabled(!appState.settings.keyboardTriggerEnabled)
                if appState.settings.hotkey != .defaultOptionV {
                    Button(KeyCombo.defaultOptionV.displayString) {
                        appState.settings.hotkey = .defaultOptionV
                    }
                    .disabled(!appState.settings.keyboardTriggerEnabled)
                }
            }

            Toggle("Middle-click double-press", isOn: $appState.settings.mouseMiddleDoubleClickEnabled)

            if noTriggerActive {
                Label("No trigger active — the panel can't be opened.",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: Login

    private var loginSection: some View {
        Section {
            Toggle("Start at login", isOn: Binding(
                get: { appState.loginItemEnabled },
                set: { appState.setLoginItem($0) }
            ))
        } footer: {
            Text("Optional. Launches PunctoDock automatically in the background after you log in.")
        }
    }

    // MARK: Characters

    private var charactersSection: some View {
        Section("Characters") {
            Toggle("Most-used characters first", isOn: $appState.settings.prioritizeFrequentlyUsed)
            Button("Reset usage history") { appState.resetUsage() }
        }
    }

    // MARK: Clipboard

    private var clipboardSection: some View {
        Section("Clipboard") {
            Toggle("Keep pinned entries when clearing",
                   isOn: $appState.settings.clipboardKeepPinnedOnReset)
            Button("Clear history") {
                appState.clearClipboard(keepPinned: appState.settings.clipboardKeepPinnedOnReset)
            }
        }
    }

    // MARK: Menu bar

    private var menuBarSection: some View {
        Section {
            Toggle("Show menu bar icon", isOn: $appState.settings.showStatusItem)
        } footer: {
            Text("The menu bar icon opens the panel on click and shows a menu on right-click. The keyboard shortcut keeps working either way.")
        }
    }

    // MARK: Permission

    private var permissionSection: some View {
        Section("Permission") {
            HStack {
                Image(systemName: appState.accessibilityTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(appState.accessibilityTrusted ? .green : .red)
                Text(appState.accessibilityTrusted
                     ? "Accessibility enabled"
                     : "Accessibility not enabled")
                Spacer()
                Button("Refresh status") { appState.refreshSystemState() }
            }
            if !appState.accessibilityTrusted {
                Text("To insert into other apps, PunctoDock must be enabled under Accessibility. Without it, the character is only placed on the clipboard.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility settings…") {
                    PermissionManager.shared.requestAccessibility()
                    PermissionManager.shared.openAccessibilitySettings()
                }
            }
        }
    }

    // MARK: Footer

    private var storageFooter: some View {
        Section {
            Text("All data stays local in ~/Library/Application Support/com.punctodock.app/. No cloud, no telemetry.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Hotkey recording

    private func toggleRecording() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            self.capture(event)
            return nil
        }
    }

    private func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        recording = false
    }

    private func capture(_ event: NSEvent) {
        // Escape cancels recording without changing the shortcut.
        if Int(event.keyCode) == kVK_Escape { stopRecording(); return }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        appState.settings.hotkey = KeyCombo(
            keyCode: UInt32(event.keyCode),
            modifierFlags: mods,
            keyLabel: Self.label(for: event)
        )
        stopRecording()
    }

    private static func label(for event: NSEvent) -> String {
        if let chars = event.charactersIgnoringModifiers,
           let first = chars.unicodeScalars.first,
           first.value >= 0x20 { // printable
            return chars.uppercased()
        }
        return KeyCodeNames.name(for: UInt32(event.keyCode))
    }
}
