// The editable master is Resources/AppIcon.svg. Its committed 1024px PNG keeps
// builds dependency-free; this script produces the sizes required by macOS.
import AppKit
import Foundation

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
let source = URL(fileURLWithPath: "Resources/AppIcon-1024.png")
guard let image = NSImage(contentsOf: source) else { fatalError("Missing app icon master") }
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for logical in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = logical * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero,
                   operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(logical)x\(logical)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output).appendingPathComponent(name))
    }
}
print("Generated \(output) from Dual Measure master")
