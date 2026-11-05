import AppKit

final class ShortcutRecorder: NSButton {
    var onBegin: (() -> Void)?
    var onFinish: ((UInt32?, String?) -> Void)?
    var onFinishCombination: ((UInt32?, String?, UInt32?) -> Void)?
    var recordsCombination = false
    private(set) var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    @objc func startRecordingAction() { beginRecording() }

    func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        title = recordsCombination ? "请按组合键（Esc 取消）" : "请按 ⌥ + 键（Esc 取消）"
        onBegin?()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        let code = UInt32(event.keyCode)
        if code == 53 {
            finish(nil, nil)
            return
        }
        let flags = event.modifierFlags.intersection([.option, .command, .control, .shift])
        let modifiers = ShortcutModifier.from(flags)
        guard let name = KeyCatalog.name(for: code),
              recordsCombination ? modifiers != 0 : modifiers == ShortcutModifier.option else {
            NSSound.beep()
            return
        }
        finish(code, name, modifiers)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { finish(nil, nil, nil) }
        return super.resignFirstResponder()
    }

    private func finish(_ keyCode: UInt32?, _ name: String?, _ modifiers: UInt32? = nil) {
        guard isRecording else { return }
        isRecording = false
        onFinish?(keyCode, name)
        onFinishCombination?(keyCode, name, modifiers)
    }
}

extension ShortcutModifier {
    static func from(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.shift) { modifiers |= shift }
        if flags.contains(.control) { modifiers |= control }
        if flags.contains(.option) { modifiers |= option }
        if flags.contains(.command) { modifiers |= command }
        return modifiers
    }
}
