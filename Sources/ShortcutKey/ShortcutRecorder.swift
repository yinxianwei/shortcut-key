import AppKit

final class ShortcutRecorder: NSButton {
    var onBegin: (() -> Void)?
    var onFinish: ((UInt32?, String?) -> Void)?
    private(set) var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    @objc func startRecordingAction() { beginRecording() }

    func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        title = "请按 ⌥ + 键（Esc 取消）"
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
        guard event.modifierFlags.intersection([.option, .command, .control, .shift]) == [.option],
              let name = KeyCatalog.name(for: code) else {
            NSSound.beep()
            return
        }
        finish(code, name)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { finish(nil, nil) }
        return super.resignFirstResponder()
    }

    private func finish(_ keyCode: UInt32?, _ name: String?) {
        guard isRecording else { return }
        isRecording = false
        onFinish?(keyCode, name)
    }
}
