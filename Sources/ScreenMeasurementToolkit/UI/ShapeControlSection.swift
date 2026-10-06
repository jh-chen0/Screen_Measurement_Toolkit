import AppKit

private final class ShapeSegmentedControl: NSSegmentedControl {
    var onSegmentTapped: ((Int) -> Void)?
    private(set) var isHandlingMouse = false

    override func mouseDown(with event: NSEvent) {
        isHandlingMouse = true
        super.mouseDown(with: event)
        isHandlingMouse = false
        onSegmentTapped?(selectedSegment)
    }
}

/// Original three drawing modes plus shared-vertex angle capture.
final class ShapeControlSection: NSView {

    private let universalFontSize: CGFloat = 12

    private let segmentedControl = ShapeSegmentedControl(labels: ["Rectangle", "Circle", "Line", "Angle"],
                                                         trackingMode: .selectOne,
                                                         target: nil,
                                                         action: nil)

    private var isSyncing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        appearance = NSAppearance(named: .darkAqua)
        setupUI()
        bindActions()
        NotificationCenter.default.addObserver(self, selector: #selector(modeChanged), name: .screenAngleModeChanged, object: nil)
        syncWithSettings()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    private func setupUI() {
        segmentedControl.appearance = NSAppearance(named: .darkAqua)
        segmentedControl.segmentDistribution = .fillEqually
        segmentedControl.controlSize = .regular
        segmentedControl.font = NSFont.systemFont(ofSize: universalFontSize, weight: .medium)
        AppLanguage.shared.bind(segmentedControl) { control in
            let labels = ["Rectangle", "Circle", "Line", "Angle"]
            let hints = ["Rectangle measurement mode (click to draw)", "Circle measurement mode (click to draw)",
                         "Line measurement mode (click to draw)", "Angle tools: protractor and shared-vertex measurement"]
            for index in labels.indices {
                control.setLabel(L(labels[index]), forSegment: index)
                control.setToolTip(L(hints[index]), forSegment: index)
            }
        }
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: topAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func bindActions() {
        segmentedControl.onSegmentTapped = { [weak self] segment in
            self?.selectShape(segment: segment)
        }
        segmentedControl.target = self
        segmentedControl.action = #selector(onToggleShape)
    }

    private func selectShape(segment: Int) {
        if segment == 3 {
            AngleToolController.shared.selectAngleMode()
            return
        }
        AngleToolController.shared.selectShapeMode()
        switch segment {
        case 1:
            Settings.shared.drawShapeType = .circle
        case 2:
            Settings.shared.drawShapeType = .line
        default:
            Settings.shared.drawShapeType = .rectangle
        }
        RulerController.shared.activateContext()
    }

    func syncWithSettings() {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        if AngleToolController.shared.isAngleModeSelected || AngleToolController.shared.isCapturing {
            segmentedControl.selectedSegment = 3
            return
        }
        switch Settings.shared.drawShapeType {
        case .rectangle:
            segmentedControl.selectedSegment = 0
        case .circle:
            segmentedControl.selectedSegment = 1
        case .line:
            segmentedControl.selectedSegment = 2
        }
    }

    @objc private func onToggleShape() {
        guard !segmentedControl.isHandlingMouse else { return }
        selectShape(segment: segmentedControl.selectedSegment)
    }
    @objc private func modeChanged() { syncWithSettings() }
}
