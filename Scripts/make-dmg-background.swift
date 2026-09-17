#!/usr/bin/env swift
// Renders Resources/Assets/dmg-background.tiff (1x + 2x) for the installer
// window, so the repository carries no binary asset nobody can edit.
import AppKit
import Foundation

let width: CGFloat = 660
let height: CGFloat = 400

func render(scale: CGFloat) -> Data? {
    let pixelsWide = Int(width * scale)
    let pixelsHigh = Int(height * scale)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelsWide,
        pixelsHigh: pixelsHigh,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: width, height: height)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Finder positions icons from the top-left; drawing is bottom-left.
    func y(_ fromTop: CGFloat) -> CGFloat { height - fromTop }

    NSGradient(colors: [
        NSColor(calibratedRed: 0.208, green: 0.545, blue: 0.525, alpha: 1),
        NSColor(calibratedRed: 0.137, green: 0.427, blue: 0.424, alpha: 1),
        NSColor(calibratedRed: 0.082, green: 0.306, blue: 0.318, alpha: 1),
    ])?.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 270)

    NSGradient(
        starting: NSColor(calibratedRed: 0.63, green: 0.95, blue: 0.86, alpha: 0.28),
        ending: NSColor(calibratedRed: 0.63, green: 0.95, blue: 0.86, alpha: 0)
    )?.draw(
        fromCenter: NSPoint(x: width / 2, y: y(40)),
        radius: 0,
        toCenter: NSPoint(x: width / 2, y: y(40)),
        radius: 300,
        options: []
    )

    NSGraphicsContext.saveGraphicsState()
    let sheen = NSBezierPath()
    sheen.move(to: NSPoint(x: -120, y: 0))
    sheen.line(to: NSPoint(x: 240, y: height))
    sheen.line(to: NSPoint(x: 470, y: height))
    sheen.line(to: NSPoint(x: 110, y: 0))
    sheen.close()
    sheen.addClip()
    NSGradient(
        starting: NSColor(calibratedWhite: 1, alpha: 0.05),
        ending: NSColor(calibratedWhite: 1, alpha: 0)
    )?.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    func draw(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, topY: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor(calibratedWhite: 1, alpha: alpha),
            .paragraphStyle: style,
        ]
        let rect = NSRect(x: 0, y: y(topY) - size * 1.25, width: width, height: size * 1.35)
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    draw("VoltGuard", size: 30, weight: .semibold, alpha: 1.0, topY: 40)
    draw("Stay charged. Stay informed.", size: 13, weight: .regular, alpha: 0.62, topY: 74)

    // Dashed shaft plus a solid head, centred between the icon slots at
    // x = 165 and x = 495.
    let arrowY = y(200)
    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: 252, y: arrowY))
    shaft.line(to: NSPoint(x: 378, y: arrowY))
    shaft.lineWidth = 6
    shaft.lineCapStyle = .butt
    shaft.setLineDash([16, 10], count: 2, phase: 0)
    NSColor(calibratedWhite: 1, alpha: 0.92).setStroke()
    shaft.stroke()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: 380, y: arrowY + 16))
    head.line(to: NSPoint(x: 412, y: arrowY))
    head.line(to: NSPoint(x: 380, y: arrowY - 16))
    head.close()
    NSColor(calibratedWhite: 1, alpha: 0.92).setFill()
    head.fill()

    NSColor(calibratedWhite: 1, alpha: 0.10).setFill()
    NSBezierPath(rect: NSRect(x: 150, y: y(290), width: 360, height: 1)).fill()

    draw(
        "Drag VoltGuard into Applications to install",
        size: 13,
        weight: .medium,
        alpha: 0.95,
        topY: 320
    )
    draw(
        "First launch: System Settings ▸ Privacy & Security ▸ Open Anyway",
        size: 12,
        weight: .regular,
        alpha: 0.58,
        topY: 344
    )

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let assets = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources/Assets")
try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

let one = assets.appendingPathComponent("dmg-background.png")
let two = assets.appendingPathComponent("dmg-background@2x.png")
try render(scale: 1)?.write(to: one)
try render(scale: 2)?.write(to: two)

let combine = Process()
combine.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
combine.arguments = [
    "-cathidpicheck", one.path, two.path,
    "-out", assets.appendingPathComponent("dmg-background.tiff").path,
]
try combine.run()
combine.waitUntilExit()

// Only the combined .tiff is an input to the build; the per-scale PNGs are
// intermediates and must not linger in the repository.
try? FileManager.default.removeItem(at: one)
try? FileManager.default.removeItem(at: two)

print(combine.terminationStatus == 0
    ? "✓ Wrote Resources/Assets/dmg-background.tiff"
    : "✗ tiffutil failed")
