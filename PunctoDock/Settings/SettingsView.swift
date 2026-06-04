import SwiftUI
import Carbon.HIToolbox

/// The single, small settings window. Plain, friendly wording throughout so the app is
/// easy for everyone, including non-technical users. Trigger, login item, symbol
/// behaviour, the menu bar icon and the permission status — plus a short first-run intro.
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
                Text("Press your shortcut to open a small window next to your mouse. Pick a symbol, sign, or emoji and it drops straight into the app you're typing in — no copy and paste. You can choose your own shortcut below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Trigger

    private var triggerSection: some View {
        Section("How to open it") {
            Toggle("Open with a keyboard shortcut", isOn: $appState.settings.keyboardTriggerEnabled)

            HStack {
                Text("Your shortcut")
                Spacer()
                Button {
                    toggleRecording()
                } label: {
                    Text(recording ? "Press any keys…" : appState.settings.hotkey.displayString)
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

            Toggle("Open by double-clicking the mouse wheel", isOn: $appState.settings.mouseMiddleDoubleClickEnabled)

            if noTriggerActive {
                Label("Nothing can open PunctoDock right now. Turn on the shortcut or the mouse option above.",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: Login

    private var loginSection: some View {
        Section {
            Toggle("Open automatically when I turn on my Mac", isOn: Binding(
                get: { appState.loginItemEnabled },
                set: { appState.setLoginItem($0) }
            ))
        } footer: {
            Text("PunctoDock starts quietly in the background after you log in. You won't see a window.")
        }
    }

    // MARK: Characters

    private var charactersSection: some View {
        Section("Symbols") {
            Toggle("Show the symbols I use most at the top", isOn: $appState.settings.prioritizeFrequentlyUsed)
            Button("Forget which symbols I use most") { appState.resetUsage() }
        }
    }

    // MARK: Clipboard

    private var clipboardSection: some View {
        Section("Copy history") {
            Toggle("Keep pinned items when I clear the list",
                   isOn: $appState.settings.clipboardKeepPinnedOnReset)
            Button("Clear the copy history") {
                appState.clearClipboard(keepPinned: appState.settings.clipboardKeepPinnedOnReset)
            }
        }
    }

    // MARK: Menu bar

    private var menuBarSection: some View {
        Section {
            Toggle("Show the icon in the top menu bar", isOn: $appState.settings.showStatusItem)
        } footer: {
            Text("Click the menu bar icon to open PunctoDock. Right-click it for settings or to quit. Your shortcut keeps working either way.")
        }
    }

    // MARK: Permission

    private var permissionSection: some View {
        Section("Permission to type for you") {
            HStack {
                Image(systemName: appState.accessibilityTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(appState.accessibilityTrusted ? .green : .red)
                Text(appState.accessibilityTrusted
                     ? "Allowed to type into other apps"
                     : "Not allowed yet")
                Spacer()
                Button("Check again") { appState.refreshSystemState() }
            }
            if !appState.accessibilityTrusted {
                Text("To put symbols into other apps, macOS needs your permission. Without it, PunctoDock just copies the symbol so you can paste it yourself with Cmd+V.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open the setting…") {
                    PermissionManager.shared.requestAccessibility()
                    PermissionManager.shared.openAccessibilitySettings()
                }
            }
        }
    }

    // MARK: Footer

    private var storageFooter: some View {
        Section {
            Text("Everything stays on your Mac, in your own user folder. No internet, no tracking.")
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
