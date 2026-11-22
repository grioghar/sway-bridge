// Draws the app icon and writes mac/AppIcon.icns:  swift tools/make-icon.swift
import AppKit

func draw(_ size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size)
    let body = NSBezierPath(roundedRect: NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8), xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(colors: [NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.16, alpha: 1), NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.06, alpha: 1)])!
        .draw(in: body, angle: -90)
    // Hand-height beams rising from an LED strip.
    let hues: [CGFloat] = [0.55, 0.62, 0.72, 0.83, 0.93, 0.05]
    let heights: [CGFloat] = [0.22, 0.38, 0.50, 0.44, 0.30, 0.18]
    for (i, hue) in hues.enumerated() {
        let x = s * (0.22 + CGFloat(i) * 0.098), w = s * 0.066
        let colour = NSColor(calibratedHue: hue, saturation: 0.85, brightness: 1, alpha: 1)
        let beam = NSBezierPath(roundedRect: NSRect(x: x, y: s * 0.29, width: w, height: s * heights[i]), xRadius: w / 2, yRadius: w / 2)
        NSGradient(colors: [colour, colour.withAlphaComponent(0.15)])!.draw(in: beam, angle: 90)
        colour.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: s * 0.22, width: w, height: s * 0.035), xRadius: s * 0.01, yRadius: s * 0.01).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("SwayBridge-\(ProcessInfo.processInfo.processIdentifier).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try draw(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try draw(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let tool = Process()
tool.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
tool.arguments = ["-c", "icns", "-o", root.appendingPathComponent("mac/AppIcon.icns").path, iconset.path]
try tool.run(); tool.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("wrote mac/AppIcon.icns")
