import AppKit

/// Drawing shared by the temporary preview and the committed measurement.
enum ScreenAngleDrawing {
    static let firstColor = NSColor(calibratedRed: 0.05, green: 0.74, blue: 0.83, alpha: 1)
    static let secondColor = NSColor(calibratedRed: 1, green: 0.56, blue: 0.12, alpha: 1)

    static func line(from a: NSPoint, to b: NSPoint, color: NSColor, dashed: Bool = false, width: CGFloat = 2) {
        let path = NSBezierPath()
        path.move(to: a)
        path.line(to: b)
        if dashed { path.setLineDash([6, 4], count: 2, phase: 0) }
        NSColor.white.withAlphaComponent(0.8).setStroke()
        path.lineWidth = width + 2
        path.stroke()
        color.setStroke()
        path.lineWidth = width
        path.stroke()
    }

    static func text(_ value: String, at point: NSPoint, size: CGFloat = 12, color: NSColor = .white,
                     weight: NSFont.Weight = .medium) {
        (value as NSString).draw(at: point, withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight), .foregroundColor: color,
        ])
    }

    static func handle(_ point: NSPoint, label: String, color: NSColor, radius: CGFloat = 6) {
        let shape = NSBezierPath(ovalIn: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        NSColor.white.setFill()
        shape.fill()
        color.setStroke()
        shape.lineWidth = 2
        shape.stroke()
        text(label, at: NSPoint(x: point.x + 10, y: point.y + 8), size: 11, color: color, weight: .bold)
    }

    static func angle(_ model: ScreenAngle, preview: Bool) {
        line(from: model.vertex, to: model.first, color: firstColor)
        line(from: model.vertex, to: model.second, color: secondColor, dashed: preview)
        let length = min(hypot(model.first.x - model.vertex.x, model.first.y - model.vertex.y),
                         hypot(model.second.x - model.vertex.x, model.second.y - model.vertex.y))
        let r = min(42, length * 0.4)
        if r >= 4 {
            let turn = ScreenAngle.shortestTurn(from: model.firstBearing, to: model.secondBearing)
            let arc = NSBezierPath()
            arc.appendArc(withCenter: model.vertex, radius: r, startAngle: model.firstBearing * 180 / .pi,
                          endAngle: (model.firstBearing + turn) * 180 / .pi, clockwise: turn < 0)
            arc.lineWidth = 2
            NSColor.systemGreen.setStroke()
            arc.stroke()
        }
        handle(model.vertex, label: "O", color: .systemBlue, radius: 7)
        handle(model.first, label: "A", color: firstColor)
        handle(model.second, label: preview ? "" : "B", color: secondColor)
    }

    static func badge(_ rect: NSRect) {
        NSColor(calibratedWhite: 0.10, alpha: 0.95).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9).fill()
    }

    static func distance(_ point: NSPoint, to a: NSPoint, _ b: NSPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared == 0 { return hypot(point.x - a.x, point.y - a.y) }
        let t = min(1, max(0, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
        return hypot(point.x - a.x - t * dx, point.y - a.y - t * dy)
    }
}
