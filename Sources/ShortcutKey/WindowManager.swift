import AppKit
import ApplicationServices

final class WindowManager {
    func apply(_ action: WindowAction) {
        guard AXIsProcessTrusted() else {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            NSSound.beep()
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication else { NSSound.beep(); return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var windowValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &windowValue) != .success {
            _ = AXUIElementCopyAttributeValue(element, kAXMainWindowAttribute as CFString, &windowValue)
        }
        guard let windowValue, CFGetTypeID(windowValue) == AXUIElementGetTypeID() else { NSSound.beep(); return }
        let window = windowValue as! AXUIElement

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { NSSound.beep(); return }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size),
              let primaryScreen = NSScreen.screens.first else { NSSound.beep(); return }

        let screenPoint = NSPoint(x: position.x + size.width / 2,
                                  y: primaryScreen.frame.maxY - position.y - size.height / 2)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(screenPoint) }) ?? primaryScreen
        let area = screen.visibleFrame
        let target: CGRect
        switch action {
        case .leftHalf:
            target = CGRect(x: area.minX, y: area.minY, width: area.width / 2, height: area.height)
        case .rightHalf:
            target = CGRect(x: area.midX, y: area.minY, width: area.width / 2, height: area.height)
        case .maximize:
            target = area
        }
        var targetPosition = CGPoint(x: target.minX, y: primaryScreen.frame.maxY - target.maxY)
        var targetSize = target.size
        guard let axPosition = AXValueCreate(.cgPoint, &targetPosition),
              let axSize = AXValueCreate(.cgSize, &targetSize) else { NSSound.beep(); return }
        let setSize = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
        let setPosition = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPosition)
        // Some apps constrain one dimension after moving; apply the size again.
        let setSizeAgain = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
        if setSize != .success || setPosition != .success || setSizeAgain != .success { NSSound.beep() }
    }
}
