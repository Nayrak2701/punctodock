import AppKit
import Carbon.HIToolbox

/// Global hotkey via Carbon's RegisterEventHotKey — the standard, battle-tested API
/// for system-wide shortcuts. It works without Accessibility permission and fires
/// even when our app is in the background. No third-party dependency needed.
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onTrigger: (() -> Void)?
    private let signature: OSType = 0x504E_4344 // 'PNCD'

    init() {
        installHandler()
    }

    deinit {
        unregister()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    func setHandler(_ handler: @escaping () -> Void) {
        onTrigger = handler
    }

    /// Registers (or re-registers) the given combo. Pass nil to disable.
    func update(combo: KeyCombo?) {
        unregister()
        guard let combo else { return }

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
        } else {
            NSLog("PunctoDock: failed to register hotkey \(combo.displayString) (status \(status))")
        }
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if hkID.signature == manager.signature {
                DispatchQueue.main.async { manager.onTrigger?() }
            }
            return noErr
        }, 1, &spec, context, &eventHandler)
    }
}
