import AppKit

/// The menu bar icon: the app icon's two stacked cards with a "2" cut out
/// of the front one. A template image, so macOS tints it for light and dark
/// menu bars like the system's own icons.
enum StatusIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in // grid: ok menu bar icon size, not layout
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            // Tomorrow: the card behind, upper right, lighter.
            NSColor.black.withAlphaComponent(0.5).setFill()
            card(NSRect(x: 6, y: 5.5, width: 10.5, height: 10.5), degrees: 8).fill() // grid: ok drawing coordinates

            // Today: the card in front, with a clear gap around it.
            let frontRect = NSRect(x: 1.5, y: 1.5, width: 11.5, height: 11.5) // grid: ok drawing coordinates
            let front = card(frontRect, degrees: -3)
            context.setBlendMode(.clear)
            front.lineWidth = 3
            front.stroke()
            context.setBlendMode(.normal)
            NSColor.black.setFill()
            front.fill()

            // The "2", cut out of the front card.
            context.saveGState()
            context.setBlendMode(.destinationOut)
            context.translateBy(x: frontRect.midX, y: frontRect.midY)
            context.rotate(by: -3 * .pi / 180)
            let two = NSAttributedString(string: "2", attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .heavy),
                .foregroundColor: NSColor.black,
            ])
            let size = two.size()
            two.draw(at: NSPoint(x: -size.width / 2, y: -size.height / 2 + 0.5))
            context.restoreGState()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "TwodayNote"
        return image
    }

    private static func card(_ rect: NSRect, degrees: CGFloat) -> NSBezierPath {
        let path = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
        var turn = AffineTransform(translationByX: rect.midX, byY: rect.midY)
        turn.rotate(byDegrees: degrees)
        turn.translate(x: -rect.midX, y: -rect.midY)
        path.transform(using: turn)
        return path
    }
}
