import AppKit
import Foundation

@main struct ScreenAngleChecks {
    static var assertions = 0
    static var failures = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
        assertions += 1
        if !value() { failures += 1; print("FAIL line \(line): \(message)") }
    }
    static func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 1e-7 }
    @MainActor static func mouse(_ type: NSEvent.EventType, at point: NSPoint, in panel: NSWindow,
                                flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: panel.convertPoint(fromScreen: point), modifierFlags: flags,
                           timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                           eventNumber: 0, clickCount: 1, pressure: 1)!
    }
    @MainActor static func main() throws {
        try geometryAndConstruction()
        preferenceMigration()
        if CommandLine.arguments.contains("--geometry-only") {
            print("\(assertions) assertions, \(failures) failures")
            exit(failures == 0 ? 0 : 1)
        }
        _ = NSApplication.shared
        ScreenAnglePreferences.shared.clickThrough = false
        try captureInteraction()
        try committedMeasurementInteraction()
        try protractorInteraction()
        try previews()
        try languageAndControls()
        print("\(assertions) assertions, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }

    static func preferenceMigration() {
        let suite = "ToolkitChecks.migration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let source: [String: Any] = ["distanser.interfaceLanguage": "zh-Hans", "showHorizontal": false,
                                   "opacity": 0.2, "drawShapeType": "circle", "screenAngleTools.fill": 0.4,
                                   "screenAngleTools.unknown": "ignored", "unrelated": "ignored"]
        defaults.set(0.9, forKey: "opacity")
        ToolkitPreferencesMigration.migrate(from: source, into: defaults)
        check(defaults.string(forKey: AppLanguage.preferenceKey) == "zh-Hans", "old language moves to new preference key")
        check(defaults.object(forKey: "distanser.interfaceLanguage") == nil, "legacy language key is not copied")
        check(defaults.object(forKey: "showHorizontal") as? Bool == false, "original ruler preferences migrate")
        check(defaults.string(forKey: "drawShapeType") == "circle", "original shape identifiers migrate")
        check(abs(defaults.double(forKey: "screenAngleTools.fill") - 0.4) < 1e-7, "angle preferences migrate")
        check(abs(defaults.double(forKey: "opacity") - 0.9) < 1e-7, "existing new-app settings take precedence")
        check(defaults.object(forKey: "unrelated") == nil && defaults.object(forKey: "screenAngleTools.unknown") == nil, "migration only copies recognized settings")
        check(defaults.bool(forKey: ToolkitPreferencesMigration.completedKey), "migration is marked complete")
        ToolkitPreferencesMigration.migrate(from: ["showHorizontal": true], into: defaults)
        check(!defaults.bool(forKey: "showHorizontal"), "migration runs once")
        check(source["opacity"] as? Double == 0.2, "source preferences stay unchanged")
        print("PASS scoped one-time preference migration")
    }

    static func geometryAndConstruction() throws {
        let origin = NSPoint(x: -300, y: 200)
        for degree: CGFloat in [0, 0.001, 15, 30, 45, 90, 120, 135, 179.999, 180] {
            let r = degree * .pi / 180
            let model = ScreenAngle(vertex: origin, first: NSPoint(x: origin.x + 300, y: origin.y),
                                    second: NSPoint(x: origin.x + 200 * cos(r), y: origin.y + 200 * sin(r)))
            check(near(model.degrees!, degree), "0–180° ray angle \(degree)")
            check(near(model.translated(by: NSPoint(x: 1920, y: -1080)).degrees!, degree), "translation invariance")
            check(near(ScreenAngle(vertex: model.vertex, first: model.second, second: model.first).degrees!, degree), "ray order invariance")
        }
        check(ScreenAngle(vertex: .zero, first: .zero, second: NSPoint(x: 100, y: 0)).degrees == nil, "reject zero-length ray")
        check(ScreenAngle(vertex: .zero, first: NSPoint(x: CGFloat.infinity, y: 1), second: NSPoint(x: 100, y: 0)).degrees == nil, "reject invalid point")
        check(near(ScreenAngle.shortestTurn(from: 179 * .pi / 180, to: -179 * .pi / 180) * 180 / .pi, 2), "rotation wrap")
        let snapped = ScreenAngle.snap(NSPoint(x: 100, y: 70), around: .zero)
        check(near(atan2(snapped.y, snapped.x) * 180 / .pi, 30), "15° snapping")

        var construction = ScreenAngleConstruction()
        check(construction.stage == .vertex, "initially requests O")
        check(construction.click(at: origin) == nil, "first click does not commit")
        check(construction.stage == .firstEndpoint && construction.vertex == origin, "O becomes shared vertex")
        construction.move(to: NSPoint(x: origin.x + 100, y: origin.y + 50))
        check(construction.stage == .firstEndpoint && construction.first == nil, "hover does not fix A")
        check(construction.click(at: origin) == nil && construction.stage == .firstEndpoint, "duplicate O cannot set A")
        let first = NSPoint(x: origin.x + 300, y: origin.y)
        check(construction.click(at: first) == nil, "second click still does not commit")
        check(construction.stage == .secondEndpoint && construction.first == first, "second click fixes OA")
        let second = NSPoint(x: origin.x - 100, y: origin.y + 100)
        construction.move(to: second)
        check(near(construction.preview!.degrees!, 135), "moving pointer previews obtuse angle")
        check(construction.completed == nil && construction.stage == .secondEndpoint, "preview never commits OB")
        check(construction.click(at: origin) == nil && construction.stage == .secondEndpoint, "zero OB does not commit")
        construction.move(to: second)
        check(construction.click(at: second) == ScreenAngle(vertex: origin, first: first, second: second), "only third click commits O/A/B")
        check(construction.stage == .finished && construction.preview == nil, "committed state has no preview")
        check(construction.click(at: first) == nil, "fourth click cannot duplicate result")
        print("PASS ray geometry and three-click state machine")
    }

    @MainActor static func captureInteraction() throws {
        let tools = AngleToolController.shared
        tools.clearAngles()
        defer { tools.clearAngles() }
        let originalMode = RulerController.shared.isContextActive
        let originalSettings = UserDefaults.standard.dictionaryRepresentation()
        tools.beginCapture()
        guard let canvas = tools.capturePanels.first else { fatalError("WindowServer unavailable") }
        let view = canvas.drawing
        let o = NSPoint(x: canvas.frame.minX + 260, y: canvas.frame.minY + 260)
        let a = NSPoint(x: o.x + 200, y: o.y)
        let b = NSPoint(x: o.x + 160, y: o.y + 160)
        view.mouseDown(with: mouse(.leftMouseDown, at: o, in: canvas))
        view.mouseDragged(with: mouse(.leftMouseDragged, at: a, in: canvas))
        view.mouseUp(with: mouse(.leftMouseUp, at: a, in: canvas))
        check(tools.construction.stage == .vertex, "drag cannot select O")
        for point in [o, a] {
            view.mouseDown(with: mouse(.leftMouseDown, at: point, in: canvas))
            view.mouseUp(with: mouse(.leftMouseUp, at: point, in: canvas))
        }
        check(tools.isCapturing && tools.measurements.isEmpty, "two clicks keep canvas active and do not save")
        view.mouseMoved(with: mouse(.mouseMoved, at: b, in: canvas))
        check(near(tools.construction.preview!.degrees!, 45), "actual mouseMoved previews OB")
        check(tools.measurements.isEmpty, "mouseMoved never adds a measurement")
        view.mouseDown(with: mouse(.leftMouseDown, at: b, in: canvas))
        view.mouseUp(with: mouse(.leftMouseUp, at: b, in: canvas))
        check(!tools.isCapturing && tools.measurements.count == 1, "third click saves and removes canvas")
        check(tools.measurements[0].model == ScreenAngle(vertex: o, first: a, second: b), "both saved rays share O")
        check(RulerController.shared.isContextActive == originalMode, "original drawing context unaffected")
        check(NSDictionary(dictionary: originalSettings).isEqual(to: UserDefaults.standard.dictionaryRepresentation()), "original settings unaffected")
        tools.beginCapture()
        tools.click(at: o)
        let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                     windowNumber: tools.capturePanels[0].windowNumber, context: nil,
                                     characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
        tools.capturePanels[0].drawing.keyDown(with: escape)
        check(!tools.isCapturing && tools.measurements.count == 1, "Escape cancels only unfinished new capture")
        tools.beginCapture()
        tools.capturePanels[0].drawing.rightMouseDown(with: mouse(.rightMouseDown, at: o, in: tools.capturePanels[0]))
        check(!tools.isCapturing && tools.measurements.count == 1, "right click cancels without changing saved results")
        tools.start()
        RulerController.shared.activateContext()
        tools.beginCapture()
        let activeEscape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                           windowNumber: tools.capturePanels[0].windowNumber, context: nil,
                                           characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
        NSApp.sendEvent(activeEscape)
        check(!tools.isCapturing, "Escape cancels capture when original drawing mode was active")
        check(RulerController.shared.isContextActive, "Escape preserves previous original drawing mode")
        tools.beginCapture()
        tools.click(at: o)
        tools.click(at: a)
        tools.movePointer(to: b)
        check(tools.measurements.count == 1, "active original mode still previews without saving")
        tools.click(at: b)
        check(!tools.isCapturing && tools.measurements.count == 2, "capture completes from original drawing mode")
        check(RulerController.shared.isContextActive, "completion restores previous original drawing mode")
        RulerController.shared.deactivateContext()
        print("PASS actual click/move/drag/Escape/right-click capture")
    }

    @MainActor static func committedMeasurementInteraction() throws {
        let model = ScreenAngle(vertex: NSPoint(x: 300, y: 300), first: NSPoint(x: 600, y: 300), second: NSPoint(x: 500, y: 500))
        let panel = ScreenAnglePanel(model)
        let view = panel.drawing
        view.mouseDown(with: mouse(.leftMouseDown, at: model.second, in: panel))
        let target = NSPoint(x: 300, y: 550)
        view.mouseUp(with: mouse(.leftMouseUp, at: target, in: panel))
        check(panel.model.vertex == model.vertex && panel.model.first == model.first, "drag B preserves O and A")
        check(near(panel.model.degrees!, 90), "drag B updates angle")
        view.mouseDown(with: mouse(.leftMouseDown, at: model.vertex, in: panel))
        let newOrigin = NSPoint(x: 330, y: 320)
        view.mouseUp(with: mouse(.leftMouseUp, at: newOrigin, in: panel))
        check(panel.model.vertex == newOrigin, "O stays a single editable vertex")
        check(panel.model.first == model.first && panel.model.second == target, "moving O keeps endpoints fixed")
        let before = panel.model
        let badgePoint = NSPoint(x: panel.frame.minX + view.badge.minX + 20, y: panel.frame.minY + view.badge.midY)
        view.mouseDown(with: mouse(.leftMouseDown, at: badgePoint, in: panel))
        view.mouseUp(with: mouse(.leftMouseUp, at: NSPoint(x: badgePoint.x + 50, y: badgePoint.y - 20), in: panel))
        check(panel.model == before.translated(by: NSPoint(x: 50, y: -20)), "badge moves whole angle")
        panel.updateHit(panel.model.vertex)
        check(!panel.ignoresMouseEvents, "vertex receives mouse")
        panel.updateHit(NSPoint(x: panel.frame.minX + 4, y: panel.frame.minY + 4))
        check(panel.ignoresMouseEvents, "empty interior is click-through")
        ScreenAnglePreferences.shared.clickThrough = true
        panel.updateHit(panel.model.vertex)
        check(panel.ignoresMouseEvents, "new tool click-through")
        ScreenAnglePreferences.shared.clickThrough = false
        print("PASS shared vertex editing and overlay hit regions")
    }

    @MainActor static func protractorInteraction() throws {
        let panel = ScreenProtractorPanel()
        panel.setGeometry(center: NSPoint(x: 500, y: 400), radius: 260, rotation: 0)
        let view = panel.drawing
        check(view.containsTool(view.pivot), "center move handle")
        check(!view.containsTool(NSPoint(x: 5, y: 5)), "protractor transparent corners")
        view.mouseDown(with: mouse(.leftMouseDown, at: panel.pivot, in: panel))
        view.mouseUp(with: mouse(.leftMouseUp, at: NSPoint(x: 550, y: 440), in: panel))
        check(panel.pivot == NSPoint(x: 550, y: 440), "protractor moves")
        view.mouseDown(with: mouse(.leftMouseDown, at: NSPoint(x: panel.pivot.x + 260, y: panel.pivot.y), in: panel))
        view.mouseUp(with: mouse(.leftMouseUp, at: NSPoint(x: panel.pivot.x + 320, y: panel.pivot.y), in: panel))
        check(panel.radius == 320, "protractor resize handle")
        view.mouseDown(with: mouse(.leftMouseDown, at: NSPoint(x: panel.pivot.x, y: panel.pivot.y + panel.radius + 23), in: panel))
        view.mouseUp(with: mouse(.leftMouseUp, at: NSPoint(x: panel.pivot.x - 200, y: panel.pivot.y + 200), in: panel, flags: .shift))
        check(near(panel.rotation * 180 / .pi, 45), "rotation snapping")
        check(ScreenAnglePreferences.shared.geometry?.center == panel.pivot, "protractor geometry persists independently")
        let angle = ScreenAnglePanel(ScreenAngle(vertex: .zero, first: NSPoint(x: 100, y: 0), second: NSPoint(x: 0, y: 100)))
        check(angle.level.rawValue > panel.level.rawValue, "angle handles sit above protractor")
        print("PASS independent protractor drag/resize/rotation/persistence")
    }

    @MainActor static func languageAndControls() throws {
        let language = AppLanguage.shared
        let originalLanguage = language.current
        let originalPreference = UserDefaults.standard.object(forKey: AppLanguage.preferenceKey)
        let originalShape = Settings.shared.drawShapeType
        defer {
            AngleToolController.shared.selectShapeMode()
            AngleToolController.shared.clearAngles()
            Settings.shared.drawShapeType = originalShape
            RulerController.shared.deactivateContext()
            language.set(originalLanguage)
            if let originalPreference { UserDefaults.standard.set(originalPreference, forKey: AppLanguage.preferenceKey) }
            else { UserDefaults.standard.removeObject(forKey: AppLanguage.preferenceKey) }
            NSApp.windows.forEach { $0.orderOut(nil) }
        }
        language.set(.english)
        let app = AppDelegate()
        app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        guard let window = NSApp.windows.first(where: { $0 is ControlWindow }), let view = window.contentView else {
            fatalError("Controls window unavailable")
        }
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap { descendants($0) } }
        var children = descendants(view)
        let tabs = children.compactMap { $0 as? NSSegmentedControl }.first!
        check(tabs.segmentCount == 4, "Controls has four tabs")
        check((0..<4).map { tabs.label(forSegment: $0)! } == ["Rectangle", "Circle", "Line", "Angle"], "original English tabs plus Angle")
        check(window.title == "Screen Measurement Toolkit Controls", "English window title")
        func select(_ index: Int) {
            tabs.selectedSegment = index
            _ = NSApp.sendAction(tabs.action!, to: tabs.target, from: tabs)
        }
        for (index, shape) in [ShapeType.rectangle, .circle, .line].enumerated() {
            select(index)
            check(Settings.shared.drawShapeType == shape && RulerController.shared.isContextActive, "original tab \(index) activates unchanged shape mode")
            check(!AngleToolController.shared.isCapturing, "original tab does not start angle capture")
        }
        let priorShape = Settings.shared.drawShapeType
        select(3)
        let tools = AngleToolController.shared
        check(!tools.isCapturing && tools.isAngleModeSelected && tabs.selectedSegment == 3, "Angle tab opens controls before capture")
        check(Settings.shared.drawShapeType == priorShape && !RulerController.shared.isContextActive, "Angle mode preserves stored shape and suspends original drawing")
        children = descendants(view)
        check(children.compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Set shared vertex O" }, "Angle tab shows relevant commands")
        func control<T: NSView>(_ identifier: String, as type: T.Type) -> T {
            descendants(view).first { $0.identifier?.rawValue == identifier } as! T
        }
        func send(_ control: NSControl) { _ = NSApp.sendAction(control.action!, to: control.target, from: control) }
        let protractorSwitch = control("angle.showProtractor", as: NSSwitch.self)
        protractorSwitch.state = .on
        send(protractorSwitch)
        check(ScreenAnglePreferences.shared.visible, "Angle panel shows the protractor")
        tools.hideProtractor()
        check(protractorSwitch.state == .off, "menu/controller visibility changes update Angle panel")
        let originalOpacity = Settings.shared.opacity
        let opacityField = control("angle.opacity", as: NSTextField.self)
        opacityField.integerValue = 40
        send(opacityField)
        check(near(ScreenAnglePreferences.shared.fill, 0.4), "Angle opacity field updates protractor fill")
        check(Settings.shared.opacity == originalOpacity, "Angle opacity preserves original ruler opacity")
        tools.setFillOpacity(0.25)
        check(opacityField.integerValue == 25, "controller opacity changes update Angle panel")
        let rotationField = control("angle.rotation", as: NSTextField.self)
        rotationField.doubleValue = 30
        send(rotationField)
        check(abs(tools.protractorRotationDegrees - 30) < 1e-7, "Angle rotation field rotates the protractor")
        let reset = children.compactMap { $0 as? NSButton }.first { $0.attributedTitle.string == "Reset Protractor" }!
        reset.performClick(nil)
        check(abs(tools.protractorRotationDegrees) < 1e-7 && protractorSwitch.state == .on, "Angle reset restores and shows the protractor")
        let originalClickThrough = Settings.shared.clickThrough
        let clickThroughSwitch = control("angle.clickThrough", as: NSSwitch.self)
        clickThroughSwitch.state = .on
        send(clickThroughSwitch)
        check(ScreenAnglePreferences.shared.clickThrough && Settings.shared.clickThrough == originalClickThrough, "Angle click-through is independent of ruler settings")
        tools.setClickThrough(false)
        check(clickThroughSwitch.state == .off, "controller click-through changes update Angle panel")
        tools.hideProtractor()
        let start = control("angle.startMeasurement", as: NSButton.self)
        start.performClick(nil)
        check(tools.isCapturing, "Angle Start Measurement button begins three-click capture")
        tools.click(at: NSPoint(x: 200, y: 200))
        tools.click(at: NSPoint(x: 400, y: 200))
        tools.movePointer(to: NSPoint(x: 200, y: 400))
        check(tools.measurements.isEmpty && near(tools.construction.preview!.degrees!, 90), "Angle tab previews without committing")
        tools.click(at: NSPoint(x: 200, y: 400))
        check(tools.measurements.count == 1 && !tools.isCapturing && tabs.selectedSegment == 3, "Angle tab third click commits while keeping angle mode")
        let clear = descendants(view).compactMap { $0 as? NSButton }.first { $0.attributedTitle.string == "Clear Angles" }!
        clear.performClick(nil)
        check(tools.measurements.isEmpty && tools.isAngleModeSelected, "Angle panel clears measurements while preserving selected mode")
        start.performClick(nil)
        check(tools.isCapturing && tools.construction.stage == .vertex, "Start Measurement begins another measurement")
        select(0)
        check(!tools.isCapturing && !tools.isAngleModeSelected && Settings.shared.drawShapeType == .rectangle, "Rectangle tab cancels capture and returns to original mode")
        children = descendants(view)
        check(children.compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Draw shape or line" }, "original commands restored")
        check(ShapeType.rectangle.rawValue == "rectangle" && ShapeType.circle.rawValue == "circle" && ShapeType.line.rawValue == "line", "original persisted shape identifiers unchanged")
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/previews")
        func snapshot(_ name: String) throws {
            view.layoutSubtreeIfNeeded()
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
        }
        try snapshot("controls-en.png")
        let menu = app.buildMenu()
        let entry = menu.items.first { $0.title == "Language / 语言" }!
        check(entry.submenu?.items.map(\.title) == ["English", "简体中文"], "language switch present in status menu")
        let chinese = entry.submenu!.items[1]
        _ = NSApp.sendAction(chinese.action!, to: chinese.target, from: chinese)
        check(language.current == .chinese && AppLanguage.savedLanguage() == .chinese, "language menu action persists Chinese for restart")
        check((0..<4).map { tabs.label(forSegment: $0)! } == ["矩形", "圆形", "直线", "角度"], "already-open tabs switch to Chinese immediately")
        check(window.title == "Screen Measurement Toolkit 控制面板", "open window title switches live")
        let fields = children.compactMap { $0 as? NSTextField }
        check(fields.contains { $0.stringValue == "水平尺" } && fields.contains { $0.stringValue == "操作说明" }, "display and commands translated")
        let buttons = children.compactMap { $0 as? PaddedButton }
        check(buttons.contains { $0.attributedTitle.string == "重置尺子" }, "custom drawn buttons translated")
        check(NSApp.mainMenu?.items.first?.submenu?.items.first?.title == "关于 Screen Measurement Toolkit", "main menu rebuilds immediately after switching")
        check(ShapeType.circle.title == "圆形", "original shape readout title translated")
        try snapshot("controls-zh.png")
        select(3)
        tools.cancel()
        try snapshot("controls-angle-zh.png")
        let chineseMenu = app.buildMenu()
        func allItems(_ menu: NSMenu) -> [NSMenuItem] { menu.items + menu.items.compactMap(\.submenu).flatMap { allItems($0) } }
        let items = allItems(chineseMenu)
        app.menuWillOpen(chineseMenu)
        let shapeItems = chineseMenu.items.first { $0.title == "形状" }!.submenu!.items
        check(shapeItems.prefix(3).allSatisfy { $0.state == .off }, "shape menu checkmarks do not conflict with Angle tab")
        let angleItem = chineseMenu.items.first { $0.keyEquivalent == "8" }!
        _ = tools.validateMenuItem(angleItem)
        check(angleItem.state == .on, "angle menu indicates selected Angle tab")
        check(items.contains { $0.title == "半透明量角器" && $0.keyEquivalent == "7" }, "localized protractor shortcut retained")
        check(items.contains { $0.title == "两线测角（共用顶点）…" && $0.keyEquivalent == "8" }, "localized angle shortcut retained")
        for key in ["1", "2", "3", "4", "5", "6", ",", "q"] {
            check(items.contains { $0.keyEquivalent == key }, "original shortcut \(key) retained")
        }
        HelpWindowController.shared.show()
        let helpWindow = NSApp.windows.first { $0.title == "Screen Measurement Toolkit 帮助" }!
        let helpText = (helpWindow.contentView as! NSScrollView).documentView as! NSTextView
        check(helpText.string.contains("角度与语言") && helpText.string.contains("尺子"), "Chinese help covers original and new tools")
        let english = chineseMenu.items.first { $0.title == "Language / 语言" }!.submenu!.items[0]
        _ = NSApp.sendAction(english.action!, to: english.target, from: english)
        check(language.current == .english && AppLanguage.savedLanguage() == .english, "language action persists English")
        check(tabs.label(forSegment: 3) == "Angle" && buttons.contains { $0.attributedTitle.string == "Reset Rulers" }, "open UI switches back to English")
        check(helpWindow.title == "Screen Measurement Toolkit Help" && helpText.string.contains("Angles & Language"), "open help switches back immediately")
        try snapshot("controls-angle-en.png")
        print("PASS Angle controls, original modes, menu shortcuts, live bilingual UI and language persistence")
    }

    @MainActor static func previews() throws {
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/previews")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let protractor = ScreenProtractorView(frame: NSRect(x: 0, y: 0, width: 604, height: 604))
        try render(protractor, region: NSRect(x: 0, y: 200, width: 604, height: 404), to: directory.appendingPathComponent("protractor.png"), dark: false)
        let committed = ScreenAngleView(frame: NSRect(x: 0, y: 0, width: 660, height: 450))
        committed.model = ScreenAngle(vertex: NSPoint(x: 120, y: 100), first: NSPoint(x: 530, y: 100), second: NSPoint(x: 380, y: 320))
        try render(committed, region: committed.bounds, to: directory.appendingPathComponent("shared-vertex-angle.png"), dark: true)
        let capture = ScreenAngleCapturePanel(screen: NSScreen.main!)
        capture.setFrame(NSRect(x: 0, y: 0, width: 800, height: 560), display: false)
        var construction = ScreenAngleConstruction()
        _ = construction.click(at: NSPoint(x: 240, y: 160))
        _ = construction.click(at: NSPoint(x: 660, y: 160))
        construction.move(to: NSPoint(x: 500, y: 360))
        capture.drawing.construction = construction
        try render(capture.drawing, region: capture.drawing.bounds, to: directory.appendingPathComponent("second-ray-preview.png"), dark: true)
        check(construction.completed == nil, "rendered preview is uncommitted")
        print("PASS actual AppKit previews")
    }
    @MainActor static func render(_ view: NSView, region: NSRect, to path: URL, dark: Bool) throws {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(region.width * 2), pixelsHigh: Int(region.height * 2),
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = region.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.cgContext.translateBy(x: -region.minX, y: -region.minY)
        (dark ? NSColor(calibratedRed: 0.13, green: 0.18, blue: 0.24, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
        view.bounds.fill()
        let grid = NSBezierPath()
        for x in stride(from: CGFloat(0), through: view.bounds.width, by: 24) {
            grid.move(to: NSPoint(x: x, y: 0)); grid.line(to: NSPoint(x: x, y: view.bounds.height))
        }
        for y in stride(from: CGFloat(0), through: view.bounds.height, by: 24) {
            grid.move(to: NSPoint(x: 0, y: y)); grid.line(to: NSPoint(x: view.bounds.width, y: y))
        }
        (dark ? NSColor(white: 1, alpha: 0.08) : NSColor(white: 0, alpha: 0.08)).setStroke()
        grid.lineWidth = 0.5
        grid.stroke()
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: path)
    }
}
