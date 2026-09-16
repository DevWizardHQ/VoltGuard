#!/usr/bin/env swift
// Renders Resources/Assets/AppIcon.icns from code so the repository carries no
// binary asset that nobody can edit.
import AppKit
import Foundation

// iconutil only accepts these base sizes; anything else is silently dropped.
let sizes = [16, 32, 128, 256, 512]
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build-iconset/AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

/// Geometry ported from Resources/Assets/battery-charging.svg so the icon is
/// drawn natively at each size rather than resampled from one raster.
private enum Mark {
    static let viewBox = NSSize(width: 176, height: 60)
    static let bodyWidth: CGFloat = 161
    static let cornerRadius: CGFloat = 11
    static let chargedWidth: CGFloat = 105
    static let green = NSColor(calibratedRed: 0.306, green: 0.737, blue: 0.451, alpha: 1)
    static let emptyAlpha: CGFloat = 0.42
}

func draw(size: Int) -> Data? {
    let side = CGFloat(size)
    // Drawn into an explicit bitmap rather than NSImage.lockFocus(), which
    // renders at the display's backing scale and silently doubles every file.
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: side, height: side)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let margin: CGFloat = 0.06
    let scale = (side * (1 - margin * 2)) / Mark.viewBox.width
    let transform = NSAffineTransform()
    // SVG's y axis runs downward; AppKit's runs up.
    transform.translateX(
        by: (side - Mark.viewBox.width * scale) / 2,
        yBy: (side + Mark.viewBox.height * scale) / 2
    )
    transform.scaleX(by: scale, yBy: -scale)

    NSGraphicsContext.saveGraphicsState()
    transform.concat()

    let body = NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: Mark.bodyWidth, height: Mark.viewBox.height),
        xRadius: Mark.cornerRadius,
        yRadius: Mark.cornerRadius
    )

    NSGraphicsContext.saveGraphicsState()
    body.addClip()
    Mark.green.withAlphaComponent(Mark.emptyAlpha).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: Mark.bodyWidth, height: Mark.viewBox.height)).fill()
    Mark.green.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: Mark.chargedWidth, height: Mark.viewBox.height)).fill()
    NSGraphicsContext.restoreGraphicsState()

    // The terminal is rounded on its outer edge only, so a rounded rect is
    // squared off on the left by a second overlapping fill.
    Mark.green.setFill()
    NSBezierPath(
        roundedRect: NSRect(x: 164, y: 17.5, width: 12, height: 25),
        xRadius: 5,
        yRadius: 5
    ).fill()
    NSBezierPath(rect: NSRect(x: 164, y: 17.5, width: 6, height: 25)).fill()

    let bolt = NSBezierPath()
    bolt.move(to: NSPoint(x: 84.5, y: 14))
    bolt.line(to: NSPoint(x: 70, y: 32.5))
    bolt.line(to: NSPoint(x: 77.5, y: 32.5))
    bolt.line(to: NSPoint(x: 73.5, y: 46))
    bolt.line(to: NSPoint(x: 88, y: 27.5))
    bolt.line(to: NSPoint(x: 80.5, y: 27.5))
    bolt.close()
    NSColor.white.setFill()
    bolt.fill()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

for size in sizes {
    guard let data = draw(size: size) else { continue }
    try data.write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    if size <= 512, let retina = draw(size: size * 2) {
        try retina.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
    }
}

let assets = root.appendingPathComponent("Resources/Assets")
try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", assets.appendingPathComponent("AppIcon.icns").path]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: root.appendingPathComponent("build-iconset"))
print(process.terminationStatus == 0 ? "✓ Wrote Resources/Assets/AppIcon.icns" : "✗ iconutil failed")
