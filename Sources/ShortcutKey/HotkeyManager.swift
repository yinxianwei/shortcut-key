import AppKit
import Carbon

final class HotkeyManager {
    private static let signature: OSType = 0x534B4559 // SKEY
    private var handler: EventHandlerRef?
    private var registrations: [UInt32: EventHotKeyRef] = [:]
    private var bindings: [UInt32: Binding] = [:]
    private let switcher = AppSwitcher()

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var hotkeyID = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            guard result == noErr else { return result }
            let owner = Unmanaged<HotkeyManager>.fromOpaque(context).takeUnretainedValue()
            return owner.handle(hotkeyID) ? noErr : OSStatus(eventNotHandledErr)
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        if status != noErr { NSLog("Could not install hotkey handler: %d", status) }
    }

    deinit {
        suspend()
        if let handler { RemoveEventHandler(handler) }
    }

    func suspend() {
        for ref in registrations.values { UnregisterEventHotKey(ref) }
        registrations.removeAll()
        bindings.removeAll()
    }

    @discardableResult
    func register(_ configuration: Configuration) -> [String] {
        suspend()
        var errors: [String] = []
        for (index, binding) in configuration.bindings.enumerated() {
            guard let keyCode = binding.keyCode else { continue }
            let id = UInt32(index + 1)
            let hotkeyID = EventHotKeyID(signature: Self.signature, id: id)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(keyCode, UInt32(optionKey), hotkeyID,
                                            GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                registrations[id] = ref
                bindings[id] = binding
            } else {
                errors.append("⌥\(binding.keyName ?? KeyCatalog.name(for: keyCode) ?? "?") 无法注册（系统错误 \(status)）")
            }
        }
        return errors
    }

    private func handle(_ hotkeyID: EventHotKeyID) -> Bool {
        guard hotkeyID.signature == Self.signature, let binding = bindings[hotkeyID.id] else { return false }
        switcher.toggle(binding)
        return true
    }
}
