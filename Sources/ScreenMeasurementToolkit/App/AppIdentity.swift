import Foundation

/// Product metadata, kept separate from the upstream ruler implementation.
enum AppIdentity {
    static let name = "Screen Measurement Toolkit"
    static let bundleIdentifier = "org.screenmeasurementtoolkit.app"
    static let upstreamURL = URL(string: "https://github.com/simpel/ruler")!
    static let upstreamCommit = "1bc14313ebc3c6108928eeb16b98bb25f9f23cec"
}

/// Copy recognized preferences once; the original application's domain is read-only.
enum ToolkitPreferencesMigration {
    static let completedKey = "toolkit.migratedDistanserPreferences"
    static let rulerKeys: Set<String> = ["showHorizontal", "showVertical", "opacity", "clickThrough", "crosshair",
                                        "drawShapeType", "guides", "frame.h", "frame.v", "zero.h", "zero.v"]
    static let angleKeys: Set<String> = ["visible", "fill", "clickThrough", "center", "radius", "rotation"]
    static func migrate() {
        migrate(from: UserDefaults.standard.persistentDomain(forName: "se.joelsanden.ruler") ?? [:], into: .standard)
    }
    static func migrate(from source: [String: Any], into destination: UserDefaults) {
        guard !destination.bool(forKey: completedKey) else { return }
        for (key, value) in source {
            let target: String
            if key == "distanser.interfaceLanguage" { target = AppLanguage.preferenceKey }
            else if rulerKeys.contains(key) || (key.hasPrefix("screenAngleTools.") && angleKeys.contains(String(key.dropFirst("screenAngleTools.".count)))) { target = key }
            else { continue }
            if destination.object(forKey: target) == nil { destination.set(value, forKey: target) }
        }
        destination.set(true, forKey: completedKey)
    }
}
