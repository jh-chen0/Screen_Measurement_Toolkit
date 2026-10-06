import AppKit

final class ScreenAnglePanel: NSPanel {
    let drawing = ScreenAngleView()
    private(set) var model: ScreenAngle
    init(_ model: ScreenAngle) {
        self.model = model
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 6)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = drawing
        drawing.owner = self
        ignoresMouseEvents = true
        update(model)
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    func update(_ model: ScreenAngle) {
        guard model.degrees != nil else { return }
        self.model = model
        let points = [model.vertex, model.first, model.second]
        let left = points.map(\.x).min()!, right = points.map(\.x).max()!
        let bottom = points.map(\.y).min()!, top = points.map(\.y).max()!
        setFrame(NSRect(x: left - 170, y: bottom - 90, width: right - left + 340, height: top - bottom + 180), display: false)
        drawing.model = model.translated(by: NSPoint(x: -frame.minX, y: -frame.minY))
        drawing.needsDisplay = true
    }
    func updateHit(_ point: NSPoint) {
        if ScreenAnglePreferences.shared.clickThrough { ignoresMouseEvents = true; return }
        if drawing.isDragging { ignoresMouseEvents = false; return }
        ignoresMouseEvents = !drawing.containsTool(NSPoint(x: point.x - frame.minX, y: point.y - frame.minY))
    }
}

final class ScreenAngleView: NSView {
    weak var owner: ScreenAnglePanel?
    var model = ScreenAngle(vertex: NSPoint(x: 100, y: 100), first: NSPoint(x: 440, y: 100), second: NSPoint(x: 330, y: 330))
    private(set) var isDragging = false
    private var selectedPoint: Int?
    private var initialMouse = NSPoint.zero
    private var initialModel: ScreenAngle?
    override var isOpaque: Bool { false }
    var points: [NSPoint] { [model.vertex, model.first, model.second] }
    var badge: NSRect {
        let top = points.map(\.y).max()!
        let midX = (points.map(\.x).min()! + points.map(\.x).max()!) / 2
        var rect = NSRect(x: midX - 143, y: top + 20, width: 286, height: 54)
        if let owner, let screen = NSScreen.screens.first(where: { $0.frame.contains(owner.model.vertex) }) ?? NSScreen.main {
            let area = screen.visibleFrame.offsetBy(dx: -owner.frame.minX, dy: -owner.frame.minY)
            rect.origin.x = min(max(rect.minX, area.minX + 6), area.maxX - rect.width - 6)
            rect.origin.y = min(max(rect.minY, area.minY + 6), area.maxY - rect.height - 6)
        }
        return rect
    }
    var close: NSRect { NSRect(x: badge.maxX - 28, y: badge.minY, width: 28, height: badge.height) }
    var copy: NSRect { NSRect(x: badge.maxX - 71, y: badge.minY, width: 43, height: badge.height) }
    func pointHit(_ point: NSPoint) -> Int? {
        // B is painted last and remains draggable even when a 0° angle overlays A.
        [0, 2, 1].first { hypot(point.x - points[$0].x, point.y - points[$0].y) <= 11 }
    }
    func containsTool(_ point: NSPoint) -> Bool {
        badge.contains(point) || pointHit(point) != nil
            || ScreenAngleDrawing.distance(point, to: model.vertex, model.first) < 7
            || ScreenAngleDrawing.distance(point, to: model.vertex, model.second) < 7
    }
    override func draw(_ dirtyRect: NSRect) {
        ScreenAngleDrawing.angle(model, preview: false)
        ScreenAngleDrawing.badge(badge)
        let text = String(format: "∠AOB  %.1f°", Double(model.degrees ?? 0))
        ScreenAngleDrawing.text(text, at: NSPoint(x: badge.minX + 12, y: badge.minY + 28), size: 16, weight: .semibold)
        ScreenAngleDrawing.text(L("Shared O · drag endpoints · drag badge to move"), at: NSPoint(x: badge.minX + 12, y: badge.minY + 8), size: 9, color: .lightGray)
        ScreenAngleDrawing.text(L("Copy"), at: NSPoint(x: copy.minX + 4, y: copy.midY - 7), size: 11)
        ScreenAngleDrawing.text("×", at: NSPoint(x: close.minX + 6, y: close.midY - 10), size: 17)
    }
    private func global(_ event: NSEvent) -> NSPoint { window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if close.contains(point), let owner { AngleToolController.shared.remove(owner); return }
        if copy.contains(point) { copyResult(); return }
        guard let owner else { return }
        selectedPoint = pointHit(point)
        initialMouse = global(event)
        initialModel = owner.model
        isDragging = true
    }
    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let owner, var model = initialModel else { return }
        var point = global(event)
        if let index = selectedPoint {
            if index != 0, event.modifierFlags.contains(.shift) { point = ScreenAngle.snap(point, around: model.vertex) }
            switch index {
            case 0: model.vertex = point
            case 1: model.first = point
            default: model.second = point
            }
            // Keep the shared vertex and both rays valid while editing.
            guard hypot(model.first.x - model.vertex.x, model.first.y - model.vertex.y) >= 8,
                  hypot(model.second.x - model.vertex.x, model.second.y - model.vertex.y) >= 8 else { return }
        } else {
            model = model.translated(by: NSPoint(x: point.x - initialMouse.x, y: point.y - initialMouse.y))
        }
        owner.update(model)
    }
    override func mouseUp(with event: NSEvent) {
        if isDragging { mouseDragged(with: event) }
        isDragging = false
    }
    func copyResult() {
        guard let degrees = model.degrees else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(String(format: "%.1f°", Double(degrees)), forType: .string)
    }
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        for (title, action) in [("Copy Angle", #selector(copyAction)), ("Remove Measurement", #selector(removeAction))] {
            let item = NSMenuItem(title: L(title), action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        return menu
    }
    @objc private func copyAction() { copyResult() }
    @objc private func removeAction() { if let owner { AngleToolController.shared.remove(owner) } }
}
