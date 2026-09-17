import AppKit
import Foundation
import VoltGuardIcon

// Renders Resources/Assets/AppIcon.icns from the shared mark, so the icon in
// the Dock and the icon in the menu bar are the same drawing.
// `--states <path>` renders a contact sheet of the menu bar states on light
// and dark backgrounds, for eyeballing a change to the mark.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--states" {
    let cases: [(String, BatteryShieldIcon)] = [
        ("100 charging", .init(level: 100, isCharging: true, guardActive: true)),
        ("62 on battery", .init(level: 62, isCharging: false, guardActive: true)),
        ("25 low", .init(level: 25, isCharging: false, guardActive: true)),
        ("12 critical", .init(level: 12, isCharging: false, guardActive: true)),
        ("paused", .init(level: 62, isCharging: false, guardActive: false)),
    ]
    let tile: CGFloat = 132
    let sheet = NSImage(size: NSSize(width: tile * CGFloat(cases.count), height: tile * 2))
    sheet.lockFocus()
    for (index, entry) in cases.enumerated() {
        let x = CGFloat(index) * tile
        NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: x, y: tile, width: tile, height: tile)).fill()
        NSColor(calibratedWhite: 0.11, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: x, y: 0, width: tile, height: tile)).fill()
        let image = entry.1.image(size: CGSize(width: 96, height: 96), includePlate: false)
        image.draw(in: NSRect(x: x + 18, y: tile + 18, width: 96, height: 96))
        image.draw(in: NSRect(x: x + 18, y: 18, width: 96, height: 96))
    }
    sheet.unlockFocus()
    let data = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
        .representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    print("✓ Wrote \(CommandLine.arguments[2])")
    exit(0)
}

let sizes = [16, 32, 128, 256, 512]
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build-iconset/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// The app icon shows a healthy, charging, guarded battery.
let mark = BatteryShieldIcon(level: 100, isCharging: true, guardActive: true)

for size in sizes {
    guard let data = mark.png(pixels: size, includePlate: true) else { continue }
    try data.write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    if let retina = mark.png(pixels: size * 2, includePlate: true) {
        try retina.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
    }
}

let assets = root.appendingPathComponent("Resources/Assets")
try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = [
    "-c", "icns", iconset.path,
    "-o", assets.appendingPathComponent("AppIcon.icns").path,
]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: root.appendingPathComponent("build-iconset"))

if iconutil.terminationStatus == 0 {
    print("✓ Wrote Resources/Assets/AppIcon.icns")
} else {
    print("✗ iconutil failed")
    exit(1)
}
