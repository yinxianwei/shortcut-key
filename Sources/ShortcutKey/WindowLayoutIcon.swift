import AppKit

enum WindowLayoutIcon {
    static func make(for action: WindowAction) -> NSImage {
        NSImage(size: NSSize(width: 72, height: 56), flipped: false) { bounds in
            let frame = bounds.insetBy(dx: 10, dy: 7)
            let outline = NSBezierPath(roundedRect: frame, xRadius: 5, yRadius: 5)
            outline.lineWidth = 3
            NSColor.labelColor.setStroke()
            outline.stroke()

            let inside = frame.insetBy(dx: 5, dy: 5)
            let fill: NSRect
            switch action {
            case .leftHalf:
                fill = NSRect(x: inside.minX, y: inside.minY,
                              width: inside.width / 2 - 2, height: inside.height)
            case .rightHalf:
                fill = NSRect(x: inside.midX + 2, y: inside.minY,
                              width: inside.width / 2 - 2, height: inside.height)
            case .maximize:
                fill = inside
            }
            NSColor.labelColor.setFill()
            NSBezierPath(roundedRect: fill, xRadius: 1.5, yRadius: 1.5).fill()
            return true
        }
    }
}
