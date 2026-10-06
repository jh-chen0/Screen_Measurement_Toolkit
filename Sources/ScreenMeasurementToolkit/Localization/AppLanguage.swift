import AppKit

extension Notification.Name {
    static let anglePreferencesChanged = Notification.Name("AnglePreferencesChanged")
    static let appLanguageChanged = Notification.Name("AppLanguageChanged")
    static let screenAngleModeChanged = Notification.Name("ScreenAngleModeChanged")
}

/// One persisted language choice and weak bindings for already-open AppKit controls.
final class AppLanguage: NSObject, NSMenuItemValidation {
    enum Language: String { case english = "en", chinese = "zh-Hans" }
    static let shared = AppLanguage()
    static let preferenceKey = "toolkit.interfaceLanguage"
    private(set) var current = AppLanguage.savedLanguage()
    private var bindings: [() -> Bool] = []

    static func savedLanguage(in defaults: UserDefaults = .standard) -> Language {
        Language(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .english
    }
    func text(_ key: String) -> String {
        current == .chinese ? (Self.chinese[key] ?? key) : key
    }
    func set(_ language: Language) {
        guard current != language else { return }
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.preferenceKey)
        bindings = bindings.filter { $0() }
        NotificationCenter.default.post(name: .appLanguageChanged, object: self)
    }
    func bind<T: NSObject>(_ target: T, update: @escaping (T) -> Void) {
        bindings.removeAll { !$0() }
        update(target)
        bindings.append { [weak target] in
            guard let target else { return false }
            update(target)
            return true
        }
    }
    func bind(_ field: NSTextField, key: String) {
        bind(field) { $0.stringValue = L(key) }
    }
    func bind(_ button: NSButton, key: String) {
        let attributes = button.attributedTitle.length > 0 ? button.attributedTitle.attributes(at: 0, effectiveRange: nil) : [:]
        bind(button) {
            $0.title = L(key)
            $0.attributedTitle = NSAttributedString(string: L(key), attributes: attributes)
            $0.needsDisplay = true
        }
    }
    func bind(_ window: NSWindow, key: String) { bind(window) { $0.title = L(key) } }

    func appendMenu(to menu: NSMenu) {
        let entry = NSMenuItem(title: "Language / 语言", action: nil, keyEquivalent: "")
        let choices = NSMenu()
        for (title, language) in [("English", Language.english), ("简体中文", Language.chinese)] {
            let item = NSMenuItem(title: title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = current == language ? .on : .off
            choices.addItem(item)
        }
        entry.submenu = choices
        menu.addItem(entry)
    }
    @objc private func selectLanguage(_ item: NSMenuItem) {
        if let raw = item.representedObject as? String, let language = Language(rawValue: raw) { set(language) }
    }
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        item.state = (item.representedObject as? String) == current.rawValue ? .on : .off
        return true
    }
    private static let chinese: [String: String] = [
        "ANGLE TOOLS": "角度工具",
        "Show Protractor": "显示量角器",
        "Start Measurement: O → A → B": "开始测角：O → A → B",
        "Rotation (°)": "旋转角度 (°)",
        "Protractor Opacity (%)": "量角器底色不透明度 (%)",
        "Angle Click-Through": "量角工具点击穿透",
        "Reset Protractor": "重置量角器",
        "Clear Angles": "清除角度",
        "Angle Help…": "量角帮助…",
        "Drag + / fill": "拖 + / 底色",
        "Move protractor": "移动量角器",
        "Drag ↻ / ↔": "拖 ↻ / ↔",
        "Rotate / resize protractor": "旋转 / 缩放量角器",
        "License & Credits": "许可与致谢",
        "Derived from": "基于开源项目",
        "Distanser by Joel Sandén (MIT License).": "Distanser，原作者 Joel Sandén（MIT 许可）。",
        "The original copyright and complete MIT License are included with the app and source code.": "应用与源码均附原作者版权声明及完整 MIT 许可证。",
        "Screen Measurement Toolkit": "Screen Measurement Toolkit",
        "ANGLE": "角度",
        "Click 1": "第一次点击",
        "Click 2": "第二次点击",
        "Move": "移动鼠标",
        "Click 3": "第三次点击",
        "Set shared vertex O": "设置共用顶点 O",
        "Fix first ray OA": "固定第一条线 OA",
        "Preview OB and the angle": "预览 OB 与角度",
        "Save second ray and angle": "保存第二条线与角度",
        "Screen Measurement Toolkit Controls": "Screen Measurement Toolkit 控制面板",
        "Screen Measurement Toolkit Controls…": "Screen Measurement Toolkit 控制面板…",
        "About Screen Measurement Toolkit": "关于 Screen Measurement Toolkit",
        "Quit Screen Measurement Toolkit": "退出 Screen Measurement Toolkit",
        "Screen Measurement Toolkit Help": "Screen Measurement Toolkit 帮助",
        "Rectangle": "矩形",
        "Circle": "圆形",
        "Line": "直线",
        "Angle": "角度",
        "Rectangle measurement mode (click to draw)": "矩形测量模式（点击后拖动绘制）",
        "Circle measurement mode (click to draw)": "圆形测量模式（点击后拖动绘制）",
        "Line measurement mode (click to draw)": "直线测量模式（点击后拖动绘制）",
        "Angle tools: protractor and shared-vertex measurement": "角度工具：半透明量角器与共用顶点测角",
        "DISPLAY": "显示",
        "Horizontal Ruler": "水平尺",
        "Vertical Ruler": "垂直尺",
        "Crosshair": "十字线",
        "Click-Through": "点击穿透",
        "Opacity": "不透明度",
        "Reset Rulers": "重置尺子",
        "Clear Measurements": "清除测量",
        "Clear Guides": "清除导线",
        "Based on Distanser · Joel Sandén": "基于 Distanser · Joel Sandén",
        "COMMANDS": "操作说明",
        "SHAPES": "形状",
        "GUIDES": "导线",
        "RULERS": "尺子",
        "Drag": "拖动",
        "⌘ Drag": "⌘ 拖动",
        "⇧ Drag": "⇧ 拖动",
        "⇧⌘ Drag": "⇧⌘ 拖动",
        "⌘ Click": "⌘ 点击",
        "Right Click": "右键点击",
        "Draw shape or line": "绘制形状或直线",
        "Draw out from center": "从中心向外绘制",
        "Keep 1:1 / 45° angle": "保持 1:1 / 45° 角度",
        "Draw out from center 1:1": "从中心绘制并保持 1:1",
        "Toggle guide on ruler / cross marker": "切换尺上导线 / 十字标记",
        "Move ruler (drag end to resize)": "移动尺子（拖末端调整长度）",
        "Move zero point": "移动零点",
        "Set / reset zero & ruler menu": "设置 / 重置零点及尺子菜单",
        "Crosshair Follows Pointer": "十字线跟随鼠标",
        "Guides": "导线",
        "Shapes": "形状",
        "Add Horizontal Guide at Pointer": "在鼠标位置添加水平导线",
        "Add Vertical Guide at Pointer": "在鼠标位置添加垂直导线",
        "Clear All Guides": "清除全部导线",
        "Draw Rectangles": "绘制矩形",
        "Draw Circles": "绘制圆形",
        "Draw Lines": "绘制直线",
        "Clear All Shapes": "清除全部形状",
        "Click-Through (ignore mouse)": "点击穿透（忽略鼠标）",
        "Clear All Measurements": "清除全部测量",
        "Reset Position & Size": "重置位置与大小",
        "Reset Zero Marks": "重置零点标记",
        "Launch at Login": "登录时启动",
        "Could not change the login item": "无法修改登录启动项",
        "Moving Screen Measurement Toolkit to your Applications folder usually fixes this.": "将 Screen Measurement Toolkit 移到“应用程序”文件夹通常可以解决此问题。",
        "Set Zero Here": "在此设置零点",
        "Reset Zero": "重置零点",
        "Add Cross Guide Here": "在此添加十字导线",
        "Hide Horizontal Ruler": "隐藏水平尺",
        "Hide Vertical Ruler": "隐藏垂直尺",
        "Remove Guide": "移除导线",
        "Shape Settings": "形状设置",
        "RULER POSITION": "相对尺子的位置",
        "SCREEN POSITION": "屏幕位置",
        "DIMENSIONS": "尺寸",
        "Translucent Protractor": "半透明量角器",
        "Measure Angle (Shared Vertex)…": "两线测角（共用顶点）…",
        "Angle Tools": "量角工具选项",
        "Measure Angle: O → A → B": "三次点击测角：O → A → B",
        "Reset Protractor Position, Size & Rotation": "重置量角器位置、大小和旋转",
        "Rotate +1°": "旋转 +1°",
        "Rotate −1°": "旋转 −1°",
        "Protractor Fill Opacity %d%%": "量角器底色不透明度 %d%%",
        "Angle Tools Click-Through": "量角工具点击穿透",
        "Clear All Angle Measurements": "清除所有角度测量",
        "Angle Tools Help…": "量角工具使用说明…",
        "Screen Protractor & Shared-Vertex Angles": "屏幕量角器与共用顶点测角",
        "OK": "知道了",
        "Protractor · %.1f°": "量角器 · %.1f°",
        "Shared O · drag endpoints · drag badge to move": "O 共用顶点 · 拖端点调整 · 拖读数整体移动",
        "Copy": "复制",
        "Copy Angle": "复制角度",
        "Remove Measurement": "移除此测量",
        "1 / 3  Click shared vertex O": "1 / 3  点击设置共用顶点 O",
        "2 / 3  Click first endpoint A": "2 / 3  点击设置第一条线端点 A",
        "3 / 3  Preview OB, click endpoint B": "3 / 3  移动鼠标预览，点击设置端点 B",
        "Measurement complete": "测量完成",
        "Preview ∠AOB %.1f° · Click to save · Esc / right-click cancels": "预览 ∠AOB %.1f° · 点击才会保存 · Esc / 右键取消",
        "Click O → A → B · ⇧ snaps 15° · Esc / right-click cancels": "依次点击 O → A → B · ⇧ 吸附 15° · Esc / 右键取消",
        "Protractor: drag its fill, center +, or badge to move; drag ↻ to rotate; drag ↔ or scroll to resize. Right-click for fill opacity.\n\nAngles: click shared vertex O, then A to fix OA. Move the pointer to preview OB and the angle; click B to save. Esc or right-click cancels. Dragging does not confirm a point.\n\nDrag O/A/B to edit; drag a line or badge to move the whole measurement. Shift snaps to 15°. Copy copies the angle; × removes it.\n\nSelect the Angle tab, then Start Measurement. Use Show Protractor and the controls in the same tab. Rectangle, Circle and Line retain their original gestures. Angle opacity, click-through and clearing are independent.": "量角器：拖底色、中心 + 或读数条移动；拖 ↻ 旋转；拖 ↔ 或滚轮缩放。右键调底色不透明度。\n\n两线测角：点击共用顶点 O；点击端点 A 固定 OA；移动鼠标实时预览 OB 和角度；点击端点 B 保存。Esc 或右键取消，拖动不会确认。\n\n拖 O/A/B 调整角度；拖线或读数条整体移动。Shift 吸附 15°。复制按钮复制角度；× 删除测量。\n\n选择“角度”选项卡后点击“开始测角”；同一页面可开关量角器并调整设置。矩形、圆形、直线保留原有手势。量角工具的透明度、点击穿透和清除命令独立。",
        "A screen ruler that floats above every other window. It lives in the menu bar — there is no Dock icon and no main window.\n": "浮在其他窗口上方的屏幕尺子。通过菜单栏图标访问，没有 Dock 图标。\n",
        "The rulers": "尺子",
        "Drag a ruler": "拖动尺子",
        "reposition the ruler window anywhere on screen": "将尺子移到屏幕任意位置",
        "⌘-drag along ruler": "沿尺子 ⌘ 拖动",
        "slide its zero position along that ruler axis": "沿尺子轴线移动零点",
        "Drag the far end": "拖动末端",
        "change its length — the end with the grip dots": "拖动带有抓握点的末端以调整长度",
        "⌘-click a ruler": "⌘ 点击尺子",
        "toggle a guide marker directly at that spot": "切换该位置的导线标记",
        "Right-click a ruler": "右键点击尺子",
        "set or reset zero, add a cross guide, open settings, hide the ruler, or quit": "设置或重置零点、添加十字导线、打开设置、隐藏尺子或退出",
        "Move the pointer": "移动鼠标",
        "a red line and a pixel readout follow it on both rulers": "两把尺子上的红线与像素读数跟随鼠标",
        "Shapes & Measuring": "形状与测量",
        "Click either ruler or open Screen Measurement Toolkit Controls to enter active drawing mode. The rulers turn from neutral charcoal to blueprint blue. Drag anywhere on screen to draw shapes or straight lines without interfering with apps underneath. Drag with Command (⌘) to draw out from the center. Press or hold Shift (⇧) to constrain to a 1:1 ratio (perfect square/circle) or snap lines to 45° angles. Hold both ⇧⌘ to draw out from the center while keeping 1:1. Clicking anywhere on the screen exits drawing mode and returns rulers to neutral.\n": "点击尺子或在控制面板中选择形状，进入绘图模式，尺子变为蓝色。在屏幕上拖动绘制形状或直线。按住 ⌘ 从中心向外绘制；按住 ⇧ 保持 1:1 比例（正方形 / 圆形），或将直线吸附到 45°。同时按住 ⇧⌘ 从中心绘制并保持 1:1。点击屏幕退出绘图模式，尺子恢复原色。\n",
        "Activate mode": "进入模式",
        "click either ruler or Screen Measurement Toolkit Controls to enter active drawing mode": "点击尺子或在控制面板中选择形状进入绘图模式",
        "Shape modes": "形状模式",
        "switch between Rectangle (⌘4), Circle (⌘5), and Line (⌘6) in the Shapes menu or Controls": "在形状菜单或控制面板中切换矩形（⌘4）、圆形（⌘5）、直线（⌘6）",
        "Draw from center": "从中心绘制",
        "drag with Command (⌘) to draw outward from center instead of corner": "按住 ⌘ 拖动，从中心向外绘制",
        "1:1 / Angle lock": "1:1 / 角度锁定",
        "press or hold Shift (⇧) to constrain 1:1 or snap lines to 45° increments": "按住 ⇧ 保持 1:1 比例，或将直线方向吸附到 45°",
        "Center + 1:1": "中心 + 1:1",
        "hold ⇧⌘ to draw out from center with a 1:1 ratio": "按住 ⇧⌘ 从中心绘制并保持 1:1",
        "Exit mode": "退出模式",
        "click anywhere on the screen (or press Esc) to leave active mode; rulers return to neutral": "点击屏幕或按 Esc 退出绘图模式，尺子恢复原色",
        "Move shapes": "移动形状",
        "drag the center symbol, readout badge, or outline to move the shape anywhere on screen": "拖动中心符号、读数条或轮廓移动形状",
        "Resize shapes": "调整形状尺寸",
        "drag control handles to resize (hold ⌘ to resize from center, ⇧ to constrain 1:1)": "拖控制点调整大小（⌘ 从中心调整，⇧ 保持 1:1）",
        "Set values": "设置数值",
        "double-click a shape or click the sliders icon on its tooltip to open settings": "双击形状或点击读数条中的滑块图标打开设置",
        "Shapes stay": "保留形状",
        "letting go of the mouse leaves the shape on screen, so you can place several at once": "松开鼠标后形状保留在屏幕上，可同时放置多个",
        "Dismiss one": "删除单个",
        "click the ✕ on its readout badge": "点击读数条上的 ✕",
        "Dismiss all": "全部清除",
        "Clear All Shapes in the menu or Controls": "在菜单或控制面板中清除形状",
        "Note": "说明",
        "Screen Measurement Toolkit keeps shape interiors click-through so apps underneath still work. Drag via the center symbol, badge tooltip, or outline to reposition.": "形状内部可点击穿透，底层应用仍可操作。拖动中心符号、读数条或轮廓移动形状。",
        "Marklines and guides": "标记与导线",
        "two screen-wide hairlines follow the pointer — toggle with Crosshair Follows Pointer": "两条跨屏细线跟随鼠标，可在菜单中切换“十字线跟随鼠标”",
        "⌘-click on screen": "⌘ 点击屏幕",
        "toggle horizontal and vertical cross markers at that position": "切换该位置的水平与垂直十字标记",
        "Drag off a ruler": "从尺子向外拖动",
        "drag out perpendicular from either ruler to place a guide where you release": "从任意尺子沿垂直方向向外拖动，在松开处放置导线",
        "Add Cross Guide Here — a guide crossing it at the clicked value": "在此添加十字导线，在点击位置添加穿过尺子的导线",
        "Drag a guide": "拖动导线",
        "move it; its badge sits at the screen edge and shows its position on the matching ruler": "移动导线；屏幕边缘的读数条显示它相对尺子的位置",
        "Hover or drag a guide": "悬停或拖动导线",
        "shows its distance to every other guide, one dimension row per pair along the screen edge": "沿屏幕边缘显示与其他各条导线的距离",
        "Double-click a guide": "双击导线",
        "remove it — ⌘-click also removes it, or right-click for remove / clear all": "移除导线；也可 ⌘ 点击移除，或右键选择移除 / 全部清除",
        "Guides menu": "导线菜单",
        "add a guide at the pointer, or clear every guide": "在鼠标位置添加导线或全部清除",
        "Guides are remembered between launches.\n": "导线会保存，重启后恢复。\n",
        "Look and layout": "外观与布局",
        "100% down to 30%": "从 100% 到 30%",
        "rulers and guides stop taking clicks, so you can work underneath them. The lines keep tracking, but you cannot drag them until you switch it off.": "尺子与导线忽略鼠标点击，便于操作底层应用。关闭点击穿透后才能再次拖动。",
        "lays the rulers out as an L so both zero marks sit on exactly the same pixel": "将两把尺子摆成 L 形，使零点位于同一像素",
        "puts both zeros back at the ruler ends": "将两个零点恢复到尺子末端",
        "Good to know": "其他说明",
        "Controls window": "控制面板",
        "Ruler Controls lets you toggle rulers, opacity, and shapes. Close or minimize it at any time, or reopen it with ⌘,": "控制面板可切换尺子、不透明度和形状；可随时关闭或最小化，按 ⌘, 重新打开",
        "No permissions": "无需授权",
        "pointer, buttons and modifiers are polled 60 times a second rather than tapped, so Ruler needs no accessibility or screen-recording access.": "每秒轮询鼠标与修饰键 60 次，无需辅助功能或屏幕录制权限。",
        "Always on top": "始终置顶",
        "the rulers join every Space and stay above full-screen windows.": "尺子出现在各个桌面空间，并位于全屏窗口上方。",
        "toggle it in the menu — macOS starts Ruler with your session.": "在菜单中切换，登录 macOS 时自动启动。",
        "Quit": "退出",
        "Quit Ruler in the menu, the controls window, the ruler right-click menu, or ⌘Q.": "通过菜单、控制面板、尺子右键菜单或 ⌘Q 退出。",
        "Angles & Language": "角度与语言",
        "Angle tab": "角度选项卡",
        "select Angle, then Start Measurement; click O → A → B": "选择“角度”后点击“开始测角”，依次点击 O → A → B",
        "Shared vertex": "共用顶点",
        "O is shared by OA and OB; moving the mouse previews OB, and only the third click saves the angle": "OA 与 OB 共用 O；鼠标移动实时预览 OB，第三次点击才保存角度",
        "Protractor": "量角器",
        "toggle the translucent protractor with ⌘7 or the menu; drag to move, rotate or resize it": "按 ⌘7 或通过菜单切换半透明量角器；拖动可移动、旋转或缩放",
        "Language": "语言",
        "use Language / 语言 in the menu bar to switch English and Simplified Chinese immediately; your choice is saved": "通过菜单栏的 Language / 语言 即时切换英文与简体中文；选择会保存",
    ]
}

func L(_ key: String) -> String { AppLanguage.shared.text(key) }
