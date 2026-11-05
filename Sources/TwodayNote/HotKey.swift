import Carbon.HIToolbox

/// One global shortcut through Carbon's RegisterEventHotKey. It needs no
/// Accessibility permission and works while another app is in front.
final class HotKey {
    static let keyN = UInt32(kVK_ANSI_N)
    static let controlOption = UInt32(controlKey | optionKey)

    fileprivate static var current: HotKey?
    private static var handlerInstalled = false

    private var ref: EventHotKeyRef?
    fileprivate let action: () -> Void

    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        if !Self.handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), hotKeyPressed, 1, &spec, nil, nil)
            Self.handlerInstalled = true
        }
        let id = EventHotKeyID(signature: OSType(0x5457_4E54), id: 1) // "TWNT"
        guard RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr else {
            print("Could not register the global shortcut; another app may own it")
            return nil
        }
        Self.current = self
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        if Self.current === self { Self.current = nil }
    }
}

/// The C callback is nonisolated and hops back to the main actor
/// (swift-swiftui skill, "Concurrency").
nonisolated private func hotKeyPressed(_ next: EventHandlerCallRef?, _ event: EventRef?, _ data: UnsafeMutableRawPointer?) -> OSStatus {
    Task { @MainActor in HotKey.current?.action() }
    return noErr
}
