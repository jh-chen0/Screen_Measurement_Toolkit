// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScreenMeasurementToolkit",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ScreenMeasurementToolkit", targets: ["ScreenMeasurementToolkit"])],
    targets: [.executableTarget(name: "ScreenMeasurementToolkit", path: "Sources/ScreenMeasurementToolkit")]
)
