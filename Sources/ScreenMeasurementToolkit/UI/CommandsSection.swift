import AppKit

/// Control panel section displaying essential gestures and commands for using Screen Measurement Toolkit.
final class CommandsSection: NSView {

    private let universalFontSize: CGFloat = 12
    private let textSection = Palette.guideLine
    private var originalGroupViews: [NSView] = []
    private var angleGestureViews: [NSView] = []
    private var angleLabels: [() -> Void] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        appearance = NSAppearance(named: .darkAqua)
        setupUI()
        NotificationCenter.default.addObserver(self, selector: #selector(modeChanged), name: .screenAngleModeChanged, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        AppLanguage.shared.bind(label, key: text)
        label.font = NSFont.systemFont(ofSize: universalFontSize, weight: .medium)
        label.textColor = textSection
        return label
    }

    private func makeSubgroupLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        AppLanguage.shared.bind(label, key: text)
        label.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = NSColor(calibratedWhite: 0.68, alpha: 1.0)
        return label
    }

    private func bindModeLabel(_ label: NSTextField, normal: String, angle: String) {
        let update: (NSTextField) -> Void = { field in
            let tools = AngleToolController.shared
            field.stringValue = L(tools.isAngleModeSelected || tools.isCapturing ? angle : normal)
        }
        AppLanguage.shared.bind(label, update: update)
        angleLabels.append { [weak label] in if let label { update(label) } }
    }
    @objc private func modeChanged() {
        angleLabels.forEach { $0() }
        let tools = AngleToolController.shared
        let angle = tools.isAngleModeSelected || tools.isCapturing
        originalGroupViews.forEach { $0.isHidden = angle }
        angleGestureViews.forEach { $0.isHidden = !angle }
    }

    private func makeRow(gesture: String, description: String, angle: (String, String)? = nil) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let gestureLabel = NSTextField(labelWithString: gesture)
        if let angle { bindModeLabel(gestureLabel, normal: gesture, angle: angle.0) }
        else { AppLanguage.shared.bind(gestureLabel, key: gesture) }
        gestureLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        gestureLabel.textColor = NSColor(calibratedWhite: 0.94, alpha: 1.0)
        gestureLabel.alignment = .left
        gestureLabel.translatesAutoresizingMaskIntoConstraints = false
        gestureLabel.widthAnchor.constraint(equalToConstant: 82).isActive = true

        let descLabel = NSTextField(labelWithString: description)
        if let angle { bindModeLabel(descLabel, normal: description, angle: angle.1) }
        else { AppLanguage.shared.bind(descLabel, key: description) }
        descLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        descLabel.textColor = NSColor(calibratedWhite: 0.80, alpha: 1.0)
        descLabel.lineBreakMode = .byTruncatingTail

        row.addArrangedSubview(gestureLabel)
        row.addArrangedSubview(descLabel)
        return row
    }

    private func setupUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.detachesHiddenViews = true
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let header = makeSectionLabel("COMMANDS")
        stack.addArrangedSubview(header)
        stack.setCustomSpacing(6, after: header)

        // 1. Shapes
        let shapesGroup = makeSubgroupLabel("SHAPES")
        bindModeLabel(shapesGroup, normal: "SHAPES", angle: "ANGLE")
        stack.addArrangedSubview(shapesGroup)
        stack.setCustomSpacing(3, after: shapesGroup)

        let shapesCommands: [(String, String)] = [
            ("Drag", "Draw shape or line"),
            ("⌘ Drag", "Draw out from center"),
            ("⇧ Drag", "Keep 1:1 / 45° angle"),
            ("⇧⌘ Drag", "Draw out from center 1:1"),
        ]
        let angleCommands = [("Click 1", "Set shared vertex O"), ("Click 2", "Fix first ray OA"),
                             ("Move", "Preview OB and the angle"), ("Click 3", "Save second ray and angle")]
        for (index, command) in shapesCommands.enumerated() {
            stack.addArrangedSubview(makeRow(gesture: command.0, description: command.1, angle: angleCommands[index]))
        }

        if let last = stack.arrangedSubviews.last {
            stack.setCustomSpacing(8, after: last)
        }

        for command in [("Drag + / fill", "Move protractor"), ("Drag ↻ / ↔", "Rotate / resize protractor")] {
            let row = makeRow(gesture: command.0, description: command.1)
            row.isHidden = true
            stack.addArrangedSubview(row)
            angleGestureViews.append(row)
        }
        let originalGroupStart = stack.arrangedSubviews.count

        // 2. Guides
        let guidesGroup = makeSubgroupLabel("GUIDES")
        stack.addArrangedSubview(guidesGroup)
        stack.setCustomSpacing(3, after: guidesGroup)

        let guidesCommands: [(String, String)] = [
            ("⌘ Click", "Toggle guide on ruler / cross marker"),
        ]
        for (gesture, desc) in guidesCommands {
            stack.addArrangedSubview(makeRow(gesture: gesture, description: desc))
        }

        if let last = stack.arrangedSubviews.last {
            stack.setCustomSpacing(8, after: last)
        }

        // 3. Rulers
        let rulersGroup = makeSubgroupLabel("RULERS")
        stack.addArrangedSubview(rulersGroup)
        stack.setCustomSpacing(3, after: rulersGroup)

        let rulersCommands: [(String, String)] = [
            ("Drag", "Move ruler (drag end to resize)"),
            ("⌘ Drag", "Move zero point"),
            ("Right Click", "Set / reset zero & ruler menu"),
        ]
        for (gesture, desc) in rulersCommands {
            stack.addArrangedSubview(makeRow(gesture: gesture, description: desc))
        }
        originalGroupViews = Array(stack.arrangedSubviews.dropFirst(originalGroupStart))
        modeChanged()
    }
}
