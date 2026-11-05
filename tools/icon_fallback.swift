#!/usr/bin/env swift
// Draws a flat AppIcon.icns from Icon/AppIcon.icon without actool (which
// only ships with Xcode). The gradient fill, then each layer, back first.
// Usage: swift tools/icon_fallback.swift Icon/AppIcon.icon Resources/AppIcon.icns
import AppKit

let args = CommandLine.arguments
let iconDir = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])

struct IconFile: Decodable {
    struct Fill: Decodable { var automaticGradient: String?
        enum CodingKeys: String, CodingKey { case automaticGradient = "automatic-gradient" } }
    struct Group: Decodable { var layers: [Layer] }
    struct Layer: Decodable { var imageName: String; var opacity: Double?
        enum CodingKeys: String, CodingKey { case imageName = "image-name", opacity } }
    var fill: Fill?
    var groups: [Group]
}

let file = try JSONDecoder().decode(IconFile.self, from: Data(contentsOf: iconDir.appending(path: "icon.json")))
let rgb = (file.fill?.automaticGradient ?? "srgb:0.2,0.42,0.96,1")
    .replacingOccurrences(of: "srgb:", with: "").split(separator: ",").compactMap { Double($0) }
let base = NSColor(srgbRed: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1)

func render(_ size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size) / 1024
    // macOS icon grid: an 824 pt rounded square centered in 1024.
    let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(starting: base.blended(withFraction: 0.25, of: .white)!, ending: base.blended(withFraction: 0.15, of: .black)!)!
        .draw(in: shape, angle: -90)
    for group in file.groups {
        for layer in group.layers.reversed() {
            guard let image = NSImage(contentsOf: iconDir.appending(path: "Assets/\(layer.imageName)")) else { continue }
            image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero,
                       operation: .sourceOver, fraction: layer.opacity ?? 1)
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let set = FileManager.default.temporaryDirectory.appending(path: "AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: set.appending(path: "icon_\(points)x\(points).png"))
    try render(points * 2).write(to: set.appending(path: "icon_\(points)x\(points)@2x.png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", set.path, "-o", output.path]
try task.run()
task.waitUntilExit()
try? FileManager.default.removeItem(at: set)
print(task.terminationStatus == 0 ? "wrote \(output.path) (flat fallback, no actool)" : "iconutil failed")
exit(task.terminationStatus)
