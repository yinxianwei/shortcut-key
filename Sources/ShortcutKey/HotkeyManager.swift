import AppKit
import Carbon

final class HotkeyManager {
    private static let signature: OSType = 0x534B4559 // SKEY
    private var handler: EventHandlerRef?
    private var registrations: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: HotkeyAction] = [:]
    private let switcher = AppSwitcher()
    private let windowManager = WindowManager()

    private enum HotkeyAction {
        case switchApp(Binding)
        case arrangeWindow(WindowAction)
    }

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
        actions.removeAll()
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
                actions[id] = .switchApp(binding)
            } else {
                errors.append("⌥\(binding.keyName ?? KeyCatalog.name(for: keyCode) ?? "?") 无法注册（系统错误 \(status)）")
            }
        }
        for (index, action) in WindowAction.allCases.enumerated() {
            guard let shortcut = configuration.windowShortcuts[action] else { continue }
            let id = UInt32(configuration.bindings.count + index + 1)
            let hotkeyID = EventHotKeyID(signature: Self.signature, id: id)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(shortcut.keyCode, carbonModifiers(shortcut.modifiers), hotkeyID,
                                            GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                registrations[id] = ref
                actions[id] = .arrangeWindow(action)
            } else {
                errors.append("\(ShortcutModifier.symbols(shortcut.modifiers))\(shortcut.keyName) 无法注册（系统错误 \(status)）")
            }
        }
        return errors
    }

    private func carbonModifiers(_ modifiers: UInt32) -> UInt32 {
        var result: UInt32 = 0
        if modifiers & ShortcutModifier.shift != 0 { result |= UInt32(shiftKey) }
        if modifiers & ShortcutModifier.control != 0 { result |= UInt32(controlKey) }
        if modifiers & ShortcutModifier.option != 0 { result |= UInt32(optionKey) }
        if modifiers & ShortcutModifier.command != 0 { result |= UInt32(cmdKey) }
        return result
    }

    private func handle(_ hotkeyID: EventHotKeyID) -> Bool {
        guard hotkeyID.signature == Self.signature, let action = actions[hotkeyID.id] else { return false }
        switch action {
        case .switchApp(let binding): switcher.toggle(binding)
        case .arrangeWindow(let windowAction): windowManager.apply(windowAction)
        }
        return true
    }
}
