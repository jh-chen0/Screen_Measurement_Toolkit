import AppKit

final class ScreenProtractorPanel: NSPanel {
    let drawing = ScreenProtractorView()
    private(set) var pivot = NSPoint.zero
    private(set) var radius: CGFloat = 260
    private(set) var rotation: CGFloat = 0

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 4)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = drawing
        drawing.owner = self
        if let saved = ScreenAnglePreferences.shared.geometry,
           NSScreen.screens.contains(where: { $0.visibleFrame.contains(saved.center) }) {
            setGeometry(center: saved.center, radius: saved.radius, rotation: saved.rotation)
        } else { reset() }
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func reset() {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        setGeometry(center: NSPoint(x: area.midX, y: area.midY - 60), radius: 260, rotation: 0)
        save()
    }
    func setGeometry(center: NSPoint, radius: CGFloat, rotation: CGFloat) {
        guard [center.x, center.y, radius, rotation].allSatisfy({ $0.isFinite }) else { return }
        pivot = center
        self.radius = min(600, max(140, radius))
        self.rotation = ScreenAngle.shortestTurn(from: 0, to: rotation)
        let extent = self.radius + 42
        setFrame(NSRect(x: center.x - extent, y: center.y - extent, width: extent * 2, height: extent * 2), display: false)
        drawing.radius = self.radius
        drawing.rotation = self.rotation
        drawing.needsDisplay = true
    }
    func save() { ScreenAnglePreferences.shared.save(center: pivot, radius: radius, rotation: rotation) }
    func updateHit(_ point: NSPoint) {
        if ScreenAnglePreferences.shared.clickThrough { ignoresMouseEvents = true; return }
        if drawing.isDragging { ignoresMouseEvents = false; return }
        ignoresMouseEvents = !drawing.containsTool(NSPoint(x: point.x - frame.minX, y: point.y - frame.minY))
    }
}

final class ScreenProtractorView: NSView {
    weak var owner: ScreenProtractorPanel?
    var radius: CGFloat = 260
    var rotation: CGFloat = 0
    private(set) var isDragging = false
    private enum Operation { case move, rotate, resize }
    private var operation: Operation = .move
    private var initialMouse = NSPoint.zero
    private var initialPivot = NSPoint.zero
    private var initialRadius: CGFloat = 260
    private var initialRotation: CGFloat = 0
    private var initialBearing: CGFloat = 0

    override var isOpaque: Bool { false }
    var pivot: NSPoint { NSPoint(x: bounds.midX, y: bounds.midY) }
    var badge: NSRect { NSRect(x: pivot.x - 123, y: pivot.y - 66, width: 246, height: 32) }
    var close: NSRect { NSRect(x: badge.maxX - 28, y: badge.minY, width: 28, height: badge.height) }
    func radialPoint(_ angle: CGFloat, distance: CGFloat) -> NSPoint {
        let a = angle + rotation
        return NSPoint(x: pivot.x + distance * cos(a), y: pivot.y + distance * sin(a))
    }
    var rotateHandle: NSPoint { radialPoint(.pi / 2, distance: radius + 23) }
    var sizeHandle: NSPoint { radialPoint(0, distance: radius) }
    private func near(_ point: NSPoint, _ target: NSPoint) -> Bool { hypot(point.x - target.x, point.y - target.y) <= 13 }
    func containsTool(_ point: NSPoint) -> Bool {
        if badge.contains(point) || near(point, pivot) || near(point, rotateHandle) || near(point, sizeHandle) { return true }
        let dx = point.x - pivot.x, dy = point.y - pivot.y
        let y = -sin(rotation) * dx + cos(rotation) * dy
        return y >= -4 && hypot(dx, dy) <= radius + 4
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: pivot.x, yBy: pivot.y)
        transform.rotate(byRadians: rotation)
        transform.concat()
        let ink = NSColor(calibratedWhite: 0.07, alpha: 0.96)
        let body = NSBezierPath()
        body.move(to: NSPoint(x: radius, y: 0))
        body.appendArc(withCenter: .zero, radius: radius, startAngle: 0, endAngle: 180)
        body.line(to: NSPoint(x: -21, y: 0))
        body.appendArc(withCenter: .zero, radius: 21, startAngle: 180, endAngle: 0, clockwise: true)
        body.close()
        NSColor(white: 1, alpha: ScreenAnglePreferences.shared.fill).setFill()
        body.fill()
        ink.setStroke()
        body.lineWidth = 1.2
        body.stroke()
        let innerRadius = radius * 0.65
        let inner = NSBezierPath()
        inner.appendArc(withCenter: .zero, radius: innerRadius, startAngle: 0, endAngle: 180)
        inner.lineWidth = 1
        inner.stroke()
        for degrees in 0...180 {
            let a = CGFloat(degrees) * .pi / 180
            let tickLength: CGFloat = degrees % 10 == 0 ? 20 : degrees % 5 == 0 ? 13 : 7
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: radius * cos(a), y: radius * sin(a)))
            tick.line(to: NSPoint(x: (radius - tickLength) * cos(a), y: (radius - tickLength) * sin(a)))
            tick.lineWidth = degrees % 10 == 0 ? 1.2 : 0.7
            tick.stroke()
            if degrees % 10 == 0 {
                let ray = NSBezierPath()
                ray.move(to: NSPoint(x: 21 * cos(a), y: 21 * sin(a)))
                ray.line(to: NSPoint(x: innerRadius * cos(a), y: innerRadius * sin(a)))
                NSColor(white: 0.08, alpha: 0.62).setStroke()
                ray.lineWidth = 0.7
                ray.stroke()
                ink.setStroke()
                scaleLabel("\(degrees)", bearing: a, distance: radius * 0.865, color: ink)
                scaleLabel("\(180 - degrees)", bearing: a, distance: radius * 0.775, color: ink)
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        control(pivot, label: "+")
        control(rotateHandle, label: "↻")
        control(sizeHandle, label: "↔")
        ScreenAngleDrawing.badge(badge)
        ScreenAngleDrawing.text(String(format: L("Protractor · %.1f°"), Double(rotation * 180 / .pi)),
                                at: NSPoint(x: badge.minX + 12, y: badge.minY + 9))
        ScreenAngleDrawing.text("×", at: NSPoint(x: close.minX + 6, y: close.minY + 6), size: 17)
    }
    private func scaleLabel(_ text: String, bearing: CGFloat, distance: CGFloat, color: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: distance * cos(bearing), yBy: distance * sin(bearing))
        transform.rotate(byRadians: bearing - .pi / 2)
        transform.concat()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: max(8, min(16, radius / 21)), weight: .medium),
            .foregroundColor: color,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: NSPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
    }
    private func control(_ point: NSPoint, label: String) {
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)).fill()
        ScreenAngleDrawing.text(label, at: NSPoint(x: point.x - 6, y: point.y - 9), size: 15, weight: .bold)
    }
    private func global(_ event: NSEvent) -> NSPoint { window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if close.contains(point) { AngleToolController.shared.hideProtractor(); return }
        guard let owner else { return }
        operation = near(point, rotateHandle) ? .rotate : near(point, sizeHandle) ? .resize : .move
        initialMouse = global(event)
        initialPivot = owner.pivot
        initialRadius = radius
        initialRotation = rotation
        initialBearing = atan2(initialMouse.y - initialPivot.y, initialMouse.x - initialPivot.x)
        isDragging = true
    }
    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let owner else { return }
        let point = global(event)
        switch operation {
        case .move:
            owner.setGeometry(center: NSPoint(x: initialPivot.x + point.x - initialMouse.x,
                                             y: initialPivot.y + point.y - initialMouse.y), radius: initialRadius, rotation: initialRotation)
        case .resize:
            owner.setGeometry(center: initialPivot, radius: hypot(point.x - initialPivot.x, point.y - initialPivot.y), rotation: initialRotation)
        case .rotate:
            let bearing = atan2(point.y - initialPivot.y, point.x - initialPivot.x)
            var a = initialRotation + ScreenAngle.shortestTurn(from: initialBearing, to: bearing)
            if event.modifierFlags.contains(.shift) { a = (a / (.pi / 12)).rounded() * .pi / 12 }
            owner.setGeometry(center: initialPivot, radius: initialRadius, rotation: a)
        }
    }
    override func mouseUp(with event: NSEvent) {
        if isDragging { mouseDragged(with: event) }
        isDragging = false
        owner?.save()
    }
    override func scrollWheel(with event: NSEvent) {
        guard let owner else { return }
        owner.setGeometry(center: owner.pivot, radius: radius + event.scrollingDeltaY * 2, rotation: rotation)
        owner.save()
    }
    override func menu(for event: NSEvent) -> NSMenu? { AngleToolController.shared.optionsMenu() }
}
