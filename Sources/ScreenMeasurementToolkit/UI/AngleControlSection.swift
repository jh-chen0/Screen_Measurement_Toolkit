import AppKit

/// Dedicated Angle tab, backed by the same actions and preferences as the menu.
final class AngleControlSection: NSView, NSTextFieldDelegate {
    private let controller = AngleToolController.shared
    private let showProtractor = NSSwitch()
    private let clickThrough = NSSwitch()
    private let rotation = NSTextField()
    private let rotationStepper = NSStepper()
    private let opacity = NSTextField()
    private let opacityStepper = NSStepper()
    private var isSyncing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        appearance = NSAppearance(named: .darkAqua)
        setupUI()
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged), name: .anglePreferencesChanged, object: nil)
        syncWithPreferences()
    }
    required init?(coder: NSCoder) { fatalError("not supported") }

    private func label(_ key: String, heading: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: key)
        field.font = .systemFont(ofSize: 12, weight: heading ? .medium : .regular)
        field.textColor = heading ? Palette.guideLine : .white
        AppLanguage.shared.bind(field, key: key)
        return field
    }
    private func row(_ key: String, control: NSView) -> NSStackView {
        let row = NSStackView(views: [label(key), control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .equalSpacing
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 284).isActive = true
        row.heightAnchor.constraint(equalToConstant: 26).isActive = true
        return row
    }
    private func button(_ key: String, action: Selector) -> PaddedButton {
        let button = PaddedButton(title: key)
        AppLanguage.shared.bind(button, key: key)
        button.target = controller
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }
    private func numberControl(_ field: NSTextField, stepper: NSStepper, min: Double, max: Double, fraction: Int, action: Selector) -> NSStackView {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = NSNumber(value: min)
        formatter.maximum = NSNumber(value: max)
        formatter.maximumFractionDigits = fraction
        field.formatter = formatter
        field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        field.textColor = .white
        field.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.8)
        field.bezelStyle = .roundedBezel
        field.controlSize = .small
        field.alignment = .center
        field.delegate = self
        field.target = self
        field.action = action
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 62).isActive = true
        stepper.controlSize = .small
        stepper.minValue = min
        stepper.maxValue = max
        stepper.increment = 1
        stepper.target = self
        stepper.action = action
        let controls = NSStackView(views: [field, stepper])
        controls.orientation = .horizontal
        controls.spacing = 3
        controls.alignment = .centerY
        return controls
    }
    private func setupUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
                                     stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor)])
        stack.addArrangedSubview(label("ANGLE TOOLS", heading: true))
        for toggle in [showProtractor, clickThrough] { toggle.controlSize = .small; toggle.target = self }
        showProtractor.action = #selector(toggleProtractor)
        clickThrough.action = #selector(toggleClickThrough)
        showProtractor.identifier = NSUserInterfaceItemIdentifier("angle.showProtractor")
        clickThrough.identifier = NSUserInterfaceItemIdentifier("angle.clickThrough")
        rotation.identifier = NSUserInterfaceItemIdentifier("angle.rotation")
        opacity.identifier = NSUserInterfaceItemIdentifier("angle.opacity")
        stack.addArrangedSubview(row("Show Protractor", control: showProtractor))
        let measure = button("Start Measurement: O → A → B", action: #selector(AngleToolController.beginCapture))
        measure.identifier = NSUserInterfaceItemIdentifier("angle.startMeasurement")
        measure.widthAnchor.constraint(equalToConstant: 284).isActive = true
        stack.addArrangedSubview(measure)
        stack.setCustomSpacing(10, after: measure)
        stack.addArrangedSubview(row("Rotation (°)", control: numberControl(rotation, stepper: rotationStepper, min: -180, max: 180, fraction: 1, action: #selector(changeRotation(_:)))))
        stack.addArrangedSubview(row("Protractor Opacity (%)", control: numberControl(opacity, stepper: opacityStepper, min: 10, max: 80, fraction: 0, action: #selector(changeOpacity(_:)))))
        stack.addArrangedSubview(row("Angle Click-Through", control: clickThrough))
        let reset = button("Reset Protractor", action: #selector(AngleToolController.resetProtractor))
        reset.widthAnchor.constraint(equalToConstant: 284).isActive = true
        stack.addArrangedSubview(reset)
        let actions = NSStackView(views: [button("Clear Angles", action: #selector(AngleToolController.clearAngles)),
                                        button("Angle Help…", action: #selector(AngleToolController.showHelp))])
        actions.orientation = .horizontal
        actions.distribution = .fillEqually
        actions.spacing = 8
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.widthAnchor.constraint(equalToConstant: 284).isActive = true
        stack.addArrangedSubview(actions)
    }
    func syncWithPreferences() {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let preferences = ScreenAnglePreferences.shared
        showProtractor.state = preferences.visible ? .on : .off
        clickThrough.state = preferences.clickThrough ? .on : .off
        if rotation.currentEditor() == nil { rotation.doubleValue = controller.protractorRotationDegrees }
        rotationStepper.doubleValue = controller.protractorRotationDegrees
        if opacity.currentEditor() == nil { opacity.integerValue = Int((preferences.fill * 100).rounded()) }
        opacityStepper.doubleValue = preferences.fill * 100
    }
    @objc private func preferencesChanged() { syncWithPreferences() }
    @objc private func toggleProtractor() { controller.setProtractorVisible(showProtractor.state == .on) }
    @objc private func toggleClickThrough() { controller.setClickThrough(clickThrough.state == .on) }
    @objc private func changeRotation(_ sender: NSControl) {
        if sender === rotationStepper { rotation.doubleValue = rotationStepper.doubleValue }
        controller.setProtractorRotation(degrees: rotation.doubleValue)
    }
    @objc private func changeOpacity(_ sender: NSControl) {
        if sender === opacityStepper { opacity.doubleValue = opacityStepper.doubleValue }
        controller.setFillOpacity(opacity.doubleValue / 100)
    }
    func controlTextDidEndEditing(_ notification: Notification) {
        if let field = notification.object as? NSTextField {
            if field === rotation { changeRotation(field) }
            if field === opacity { changeOpacity(field) }
            syncWithPreferences()
        }
    }
}
