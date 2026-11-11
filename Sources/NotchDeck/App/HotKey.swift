import Carbon.HIToolbox

/// A system-wide keyboard shortcut (⌃⌥N by default) through the Carbon
/// hot key API, which needs no Accessibility permission.
final class HotKey {
    static let displayText = "⌃⌥N"

    private var ref: EventHotKeyRef?
    /// False when another app already owns these keys.
    private(set) var isRegistered = false
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(keyCode: UInt32 = UInt32(kVK_ANSI_N), modifiers: UInt32 = UInt32(controlKey | optionKey), action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &spec, me, &handler)
        let id = EventHotKeyID(signature: OSType(0x4E444B59), id: 1) // "NDKY"
        isRegistered = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
