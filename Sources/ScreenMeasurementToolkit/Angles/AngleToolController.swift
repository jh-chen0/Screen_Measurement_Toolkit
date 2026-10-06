import AppKit

/// Independent geometry, preferences and overlays; the prior drawing context is restored after capture.
final class AngleToolController: NSObject, NSMenuItemValidation {
    static let shared = AngleToolController()
    private(set) var isAngleModeSelected = false
    private var protractor: ScreenProtractorPanel?
    private(set) var measurements: [ScreenAnglePanel] = []
    private(set) var capturePanels: [ScreenAngleCapturePanel] = []
    private(set) var construction = ScreenAngleConstruction()
    private weak var previousKeyWindow: NSWindow?
    private var resumeOriginalDrawing = false
    private var timer: Timer?
    private var keyMonitor: Any?
    private var lastPointer: NSPoint?
    private var lastFlags: NSEvent.ModifierFlags = []
    var isCapturing: Bool { !capturePanels.isEmpty }

    func start() {
        guard timer == nil else { return }
        applyProtractorVisibility()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(originalContextChanged), name: .rulerContextChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53, self.isCapturing { self.cancel(); return nil }
            let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if flags == [.command] {
                switch event.charactersIgnoringModifiers {
                case "7": self.toggleProtractor(); return nil
                case "8": self.beginCapture(); return nil
                default: break
                }
            }
            return event
        }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 1.0 / 120
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func appendMenu(to menu: NSMenu) {
        menu.addItem(.separator())
        item("Translucent Protractor", action: #selector(toggleProtractor), key: "7", to: menu)
        item("Measure Angle (Shared Vertex)…", action: #selector(beginCapture), key: "8", to: menu)
        let options = NSMenuItem(title: L("Angle Tools"), action: nil, keyEquivalent: "")
        options.submenu = optionsMenu()
        menu.addItem(options)
    }
    func optionsMenu() -> NSMenu {
        let menu = NSMenu()
        item("Measure Angle: O → A → B", action: #selector(beginCapture), to: menu)
        item("Reset Protractor Position, Size & Rotation", action: #selector(resetProtractor), to: menu)
        item("Rotate +1°", action: #selector(rotatePositive), to: menu)
        item("Rotate −1°", action: #selector(rotateNegative), to: menu)
        menu.addItem(.separator())
        for value in [0.15, 0.25, 0.4, 0.6, 0.8] {
            let entry = item(String(format: L("Protractor Fill Opacity %d%%"), Int(value * 100)), action: #selector(setFill(_:)), to: menu)
            entry.representedObject = NSNumber(value: value)
        }
        menu.addItem(.separator())
        item("Angle Tools Click-Through", action: #selector(toggleClickThrough), to: menu)
        item("Clear All Angle Measurements", action: #selector(clearAngles), to: menu)
        item("Angle Tools Help…", action: #selector(showHelp), to: menu)
        return menu
    }
    @discardableResult private func item(_ title: String, action: Selector, key: String = "", to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: L(title), action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(beginCapture) { menuItem.state = isCapturing || isAngleModeSelected ? .on : .off }
        if menuItem.action == #selector(toggleProtractor) { menuItem.state = ScreenAnglePreferences.shared.visible ? .on : .off }
        if menuItem.action == #selector(toggleClickThrough) { menuItem.state = ScreenAnglePreferences.shared.clickThrough ? .on : .off }
        if menuItem.action == #selector(setFill(_:)), let value = menuItem.representedObject as? NSNumber {
            menuItem.state = abs(value.doubleValue - ScreenAnglePreferences.shared.fill) < 0.001 ? .on : .off
        }
        return true
    }
    @objc func toggleProtractor() { setProtractorVisible(!ScreenAnglePreferences.shared.visible) }
    func setProtractorVisible(_ visible: Bool) {
        ScreenAnglePreferences.shared.visible = visible
        applyProtractorVisibility()
    }
    func hideProtractor() {
        ScreenAnglePreferences.shared.visible = false
        applyProtractorVisibility()
    }
    private func applyProtractorVisibility() {
        if ScreenAnglePreferences.shared.visible {
            if protractor == nil { protractor = ScreenProtractorPanel() }
            protractor?.drawing.needsDisplay = true
            protractor?.orderFrontRegardless()
        } else { protractor?.orderOut(nil) }
    }
    @objc func resetProtractor() {
        ScreenAnglePreferences.shared.visible = true
        applyProtractorVisibility()
        protractor?.reset()
    }
    @objc private func rotatePositive() { rotate(by: .pi / 180) }
    @objc private func rotateNegative() { rotate(by: -.pi / 180) }
    var protractorRotationDegrees: Double {
        Double((protractor?.rotation ?? ScreenAnglePreferences.shared.geometry?.rotation ?? 0) * 180 / .pi)
    }
    func setProtractorRotation(degrees: Double) {
        guard degrees.isFinite else { return }
        if protractor == nil { protractor = ScreenProtractorPanel() }
        guard let protractor else { return }
        protractor.setGeometry(center: protractor.pivot, radius: protractor.radius, rotation: CGFloat(degrees) * .pi / 180)
        protractor.save()
    }
    private func rotate(by amount: CGFloat) {
        setProtractorRotation(degrees: protractorRotationDegrees + Double(amount * 180 / .pi))
    }
    @objc private func setFill(_ item: NSMenuItem) {
        guard let value = item.representedObject as? NSNumber else { return }
        setFillOpacity(value.doubleValue)
    }
    func setFillOpacity(_ value: Double) {
        guard value.isFinite else { return }
        ScreenAnglePreferences.shared.fill = value
        protractor?.drawing.needsDisplay = true
    }
    func setClickThrough(_ enabled: Bool) {
        ScreenAnglePreferences.shared.clickThrough = enabled
        tick()
    }
    @objc private func toggleClickThrough() { setClickThrough(!ScreenAnglePreferences.shared.clickThrough) }

    func selectAngleMode() {
        cancel()
        // Choosing another tab is an explicit mode switch. The stored shape type is preserved.
        RulerController.shared.deactivateContext()
        isAngleModeSelected = true
        modeChanged()
    }
    func selectShapeMode() {
        cancel()
        isAngleModeSelected = false
        modeChanged()
    }
    private func modeChanged() {
        NotificationCenter.default.post(name: .screenAngleModeChanged, object: self)
    }
    @objc private func originalContextChanged() {
        if RulerController.shared.isContextActive, isAngleModeSelected {
            isAngleModeSelected = false
            modeChanged()
        }
    }
    @objc private func languageChanged() {
        protractor?.drawing.needsDisplay = true
        measurements.forEach { $0.drawing.needsDisplay = true }
        refreshCapture()
        MeasurementStore.shared.measurements.forEach { $0.refresh() }
    }

    @objc func beginCapture() {
        cancel()
        construction = ScreenAngleConstruction()
        previousKeyWindow = NSApp.keyWindow
        // The original drawing canvas installs its own Escape monitor. Suspend it only
        // during the new capture so Escape cannot alter or consume its previous mode.
        resumeOriginalDrawing = RulerController.shared.isContextActive
        if resumeOriginalDrawing { RulerController.shared.deactivateContext() }
        capturePanels = NSScreen.screens.map { ScreenAngleCapturePanel(screen: $0) }
        NSApp.activate(ignoringOtherApps: true)
        capturePanels.forEach { $0.orderFrontRegardless() }
        let panel = capturePanels.first { $0.frame.contains(NSEvent.mouseLocation) } ?? capturePanels.first
        panel?.makeKeyAndOrderFront(nil)
        if let panel { panel.makeFirstResponder(panel.drawing) }
        lastPointer = nil
        refreshCapture()
        modeChanged()
    }
    func movePointer(to point: NSPoint, flags: NSEvent.ModifierFlags = []) {
        guard isCapturing else { return }
        construction.move(to: point, snap: flags.contains(.shift))
        refreshCapture()
    }
    func click(at point: NSPoint, flags: NSEvent.ModifierFlags = []) {
        guard isCapturing else { return }
        if let result = construction.click(at: point, snap: flags.contains(.shift)) {
            let panel = ScreenAnglePanel(result)
            measurements.append(panel)
            panel.orderFrontRegardless()
            cancel()
        } else { refreshCapture() }
    }
    func cancel() {
        capturePanels.forEach { $0.orderOut(nil) }
        capturePanels.removeAll()
        construction = ScreenAngleConstruction()
        let restoreDrawing = resumeOriginalDrawing
        resumeOriginalDrawing = false
        if restoreDrawing { RulerController.shared.activateContext() }
        if let previousKeyWindow, previousKeyWindow.isVisible { previousKeyWindow.makeKey() }
        previousKeyWindow = nil
        modeChanged()
    }
    func remove(_ panel: ScreenAnglePanel) {
        panel.orderOut(nil)
        measurements.removeAll { $0 === panel }
    }
    @objc func clearAngles() {
        cancel()
        measurements.forEach { $0.orderOut(nil) }
        measurements.removeAll()
    }
    private func refreshCapture() {
        capturePanels.forEach { $0.drawing.construction = construction; $0.drawing.needsDisplay = true }
    }
    private func tick() {
        guard isCapturing || ScreenAnglePreferences.shared.visible || !measurements.isEmpty else { return }
        let point = NSEvent.mouseLocation
        let flags = NSEvent.modifierFlags
        if isCapturing, lastPointer != point || lastFlags != flags { movePointer(to: point, flags: flags) }
        lastPointer = point
        lastFlags = flags
        if ScreenAnglePreferences.shared.visible { protractor?.updateHit(point) }
        measurements.forEach { $0.updateHit(point) }
    }
    @objc private func displaysChanged() {
        if isCapturing { cancel() }
        if let protractor, !NSScreen.screens.contains(where: { $0.visibleFrame.contains(protractor.pivot) }) { protractor.reset() }
        if let area = NSScreen.main?.visibleFrame {
            for panel in measurements where !NSScreen.screens.contains(where: { $0.frame.intersects(panel.frame) }) {
                let delta = NSPoint(x: area.midX - panel.frame.midX, y: area.midY - panel.frame.midY)
                panel.update(panel.model.translated(by: delta))
            }
        }
    }
    @objc func showHelp() {
        let alert = NSAlert()
        alert.messageText = L("Screen Protractor & Shared-Vertex Angles")
        alert.informativeText = L("Protractor: drag its fill, center +, or badge to move; drag ↻ to rotate; drag ↔ or scroll to resize. Right-click for fill opacity.\n\nAngles: click shared vertex O, then A to fix OA. Move the pointer to preview OB and the angle; click B to save. Esc or right-click cancels. Dragging does not confirm a point.\n\nDrag O/A/B to edit; drag a line or badge to move the whole measurement. Shift snaps to 15°. Copy copies the angle; × removes it.\n\nSelect the Angle tab, then Start Measurement. Use Show Protractor and the controls in the same tab. Rectangle, Circle and Line retain their original gestures. Angle opacity, click-through and clearing are independent.")
        alert.addButton(withTitle: L("OK"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
