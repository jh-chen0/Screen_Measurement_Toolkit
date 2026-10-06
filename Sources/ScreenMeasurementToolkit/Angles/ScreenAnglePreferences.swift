import AppKit

/// New options use their own keys and never write any original ruler setting.
final class ScreenAnglePreferences {
    static let shared = ScreenAnglePreferences()
    private let defaults = UserDefaults.standard
    private let prefix = "screenAngleTools."
    private init() {
        defaults.register(defaults: [prefix + "visible": false, prefix + "fill": 0.25, prefix + "clickThrough": false])
    }
    private func changed() { NotificationCenter.default.post(name: .anglePreferencesChanged, object: self) }
    var visible: Bool {
        get { defaults.bool(forKey: prefix + "visible") }
        set { defaults.set(newValue, forKey: prefix + "visible"); changed() }
    }
    var fill: Double {
        get { defaults.double(forKey: prefix + "fill") }
        set { defaults.set(min(0.8, max(0.1, newValue)), forKey: prefix + "fill"); changed() }
    }
    var clickThrough: Bool {
        get { defaults.bool(forKey: prefix + "clickThrough") }
        set { defaults.set(newValue, forKey: prefix + "clickThrough"); changed() }
    }
    var geometry: (center: NSPoint, radius: CGFloat, rotation: CGFloat)? {
        guard let text = defaults.string(forKey: prefix + "center") else { return nil }
        let center = NSPointFromString(text)
        let radius = CGFloat(defaults.double(forKey: prefix + "radius"))
        let rotation = CGFloat(defaults.double(forKey: prefix + "rotation"))
        guard [center.x, center.y, radius, rotation].allSatisfy({ $0.isFinite }), radius >= 140 else { return nil }
        return (center, radius, rotation)
    }
    func save(center: NSPoint, radius: CGFloat, rotation: CGFloat) {
        defaults.set(NSStringFromPoint(center), forKey: prefix + "center")
        defaults.set(Double(radius), forKey: prefix + "radius")
        defaults.set(Double(rotation), forKey: prefix + "rotation")
        changed()
    }
}
