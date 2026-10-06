import AppKit

/// Temporary canvas used only for the new three-click tool. Original drawing mode is untouched.
final class ScreenAngleCapturePanel: NSPanel {
    let drawing = ScreenAngleCaptureView()
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 9)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = drawing
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class ScreenAngleCaptureView: NSView {
    var construction = ScreenAngleConstruction()
    private var mouseDownPoint: NSPoint?
    private var hasDragged = false
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    private func global(_ event: NSEvent) -> NSPoint { window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 1, alpha: 0.002).setFill()
        dirtyRect.fill()
        guard let window else { return }
        let offset = NSPoint(x: -window.frame.minX, y: -window.frame.minY)
        func local(_ p: NSPoint) -> NSPoint { NSPoint(x: p.x + offset.x, y: p.y + offset.y) }
        if let preview = construction.preview {
            ScreenAngleDrawing.angle(preview.translated(by: offset), preview: true)
        } else if let vertex = construction.vertex {
            if let first = construction.first {
                ScreenAngleDrawing.line(from: local(vertex), to: local(first), color: ScreenAngleDrawing.firstColor)
                ScreenAngleDrawing.handle(local(first), label: "A", color: ScreenAngleDrawing.firstColor)
            } else if let pointer = construction.pointer, hypot(pointer.x - vertex.x, pointer.y - vertex.y) >= 1 {
                ScreenAngleDrawing.line(from: local(vertex), to: local(pointer), color: ScreenAngleDrawing.firstColor, dashed: true)
            }
            ScreenAngleDrawing.handle(local(vertex), label: "O", color: .systemBlue, radius: 7)
        }
        let badge = NSRect(x: bounds.midX - 225, y: bounds.maxY - 118, width: 450, height: 70)
        ScreenAngleDrawing.badge(badge)
        let title: String
        switch construction.stage {
        case .vertex: title = L("1 / 3  Click shared vertex O")
        case .firstEndpoint: title = L("2 / 3  Click first endpoint A")
        case .secondEndpoint: title = L("3 / 3  Preview OB, click endpoint B")
        case .finished: title = L("Measurement complete")
        }
        ScreenAngleDrawing.text(title, at: NSPoint(x: badge.minX + 16, y: badge.minY + 43), size: 15, weight: .semibold)
        let hint = construction.preview?.degrees.map { String(format: L("Preview ∠AOB %.1f° · Click to save · Esc / right-click cancels"), Double($0)) }
            ?? L("Click O → A → B · ⇧ snaps 15° · Esc / right-click cancels")
        ScreenAngleDrawing.text(hint, at: NSPoint(x: badge.minX + 16, y: badge.minY + 15), size: 11, color: .lightGray)
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        mouseDownPoint = global(event)
        hasDragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        if let start = mouseDownPoint, hypot(global(event).x - start.x, global(event).y - start.y) > 4 { hasDragged = true }
        AngleToolController.shared.movePointer(to: global(event), flags: event.modifierFlags)
    }
    override func mouseMoved(with event: NSEvent) { AngleToolController.shared.movePointer(to: global(event), flags: event.modifierFlags) }
    override func flagsChanged(with event: NSEvent) { AngleToolController.shared.movePointer(to: NSEvent.mouseLocation, flags: event.modifierFlags) }
    override func mouseUp(with event: NSEvent) {
        defer { mouseDownPoint = nil; hasDragged = false }
        guard let start = mouseDownPoint, !hasDragged,
              hypot(global(event).x - start.x, global(event).y - start.y) <= 4 else { return }
        AngleToolController.shared.click(at: global(event), flags: event.modifierFlags)
    }
    override func rightMouseDown(with event: NSEvent) { AngleToolController.shared.cancel() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { AngleToolController.shared.cancel() } else { super.keyDown(with: event) }
    }
}
