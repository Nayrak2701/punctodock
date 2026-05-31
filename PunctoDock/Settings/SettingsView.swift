import SwiftUI
import Carbon.HIToolbox

/// The single, small settings window. Trigger config, login item, character logic
/// and the Accessibility permission status — plus a short first-run explainer.
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
                Text("Puncto-dock")
                    .font(.headline)
                Text("Drücke den Trigger (Standard: F7), um in der Nähe des Mauszeigers ein Feld mit Satz- und Sonderzeichen zu öffnen. Das gewählte Zeichen wird in die App eingefügt, in der dein Textcursor steht.")
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
            Toggle("Tastatur-Trigger aktiv", isOn: $appState.settings.keyboardTriggerEnabled)

            HStack {
                Text("Tastenkürzel")
                Spacer()
                Button {
                    toggleRecording()
                } label: {
                    Text(recording ? "Taste drücken…" : appState.settings.hotkey.displayString)
                        .frame(minWidth: 70)
                        .monospacedDigit()
                }
                .disabled(!appState.settings.keyboardTriggerEnabled)
                if appState.settings.hotkey != .defaultF7 {
                    Button("F7") { appState.settings.hotkey = .defaultF7 }
                        .disabled(!appState.settings.keyboardTriggerEnabled)
                }
            }

            Toggle("Mausrad-Doppelklick", isOn: $appState.settings.mouseMiddleDoubleClickEnabled)

            if noTriggerActive {
                Label("Kein Trigger aktiv – das Panel lässt sich nicht öffnen.",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: Login

    private var loginSection: some View {
        Section {
            Toggle("Beim Anmelden starten", isOn: Binding(
                get: { appState.loginItemEnabled },
                set: { appState.setLoginItem($0) }
            ))
        } footer: {
            Text("Optional. Startet Puncto-dock automatisch im Hintergrund nach der Anmeldung.")
        }
    }

    // MARK: Characters

    private var charactersSection: some View {
        Section("Zeichen") {
            Toggle("Häufig genutzte Zeichen zuerst", isOn: $appState.settings.prioritizeFrequentlyUsed)
            Button("Nutzungsverlauf zurücksetzen") { appState.resetUsage() }
        }
    }

    // MARK: Clipboard

    private var clipboardSection: some View {
        Section("Zwischenablage") {
            Toggle("Gepinnte Einträge beim Zurücksetzen behalten",
                   isOn: $appState.settings.clipboardKeepPinnedOnReset)
            Button("Verlauf zurücksetzen") {
                appState.clearClipboard(keepPinned: appState.settings.clipboardKeepPinnedOnReset)
            }
        }
    }

    // MARK: Permission

    private var permissionSection: some View {
        Section("Berechtigung") {
            HStack {
                Image(systemName: appState.accessibilityTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(appState.accessibilityTrusted ? .green : .red)
                Text(appState.accessibilityTrusted
                     ? "Bedienungshilfen aktiviert"
                     : "Bedienungshilfen nicht aktiviert")
                Spacer()
                Button("Status aktualisieren") { appState.refreshSystemState() }
            }
            if !appState.accessibilityTrusted {
                Text("Zum Einfügen in andere Apps muss Puncto-dock unter „Bedienungshilfen“ freigegeben sein. Ohne Freigabe wird das Zeichen nur in die Zwischenablage gelegt.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("In den Systemeinstellungen freigeben…") {
                    PermissionManager.shared.requestAccessibility()
                    PermissionManager.shared.openAccessibilitySettings()
                }
            }
        }
    }

    // MARK: Footer

    private var storageFooter: some View {
        Section {
            Text("Alle Daten bleiben lokal in ~/Library/Application Support/com.punctodock.app/. Keine Cloud, keine Telemetrie.")
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
