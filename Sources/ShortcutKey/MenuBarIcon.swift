import AppKit

enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 19, height: 19), flipped: false) { _ in
            NSColor.black.setStroke()
            let front = NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: 15, height: 15),
                                     xRadius: 3.5, yRadius: 3.5)
            front.lineWidth = 1.3
            front.stroke()

            let option = NSBezierPath()
            option.lineWidth = 1.2
            option.lineCapStyle = .round
            option.lineJoinStyle = .round
            option.move(to: NSPoint(x: 5.5, y: 12))
            option.line(to: NSPoint(x: 7.6, y: 12))
            option.line(to: NSPoint(x: 10.3, y: 6.5))
            option.line(to: NSPoint(x: 13.4, y: 6.5))
            option.move(to: NSPoint(x: 10.5, y: 12))
            option.line(to: NSPoint(x: 13.4, y: 12))
            option.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ShortcutKey 窗口快捷键"
        return image
    }
}
