import AppKit

/// The VoltGuard mark, drawn from the geometry in
/// `Resources/Assets/battery-shield-icon.svg`.
///
/// One renderer serves the app icon and the menu bar so the two cannot drift.
/// The three states the artwork encodes are the three the app actually has:
/// how full the battery is, whether a charger is attached, and whether the
/// guard is watching.
public struct BatteryShieldIcon: Sendable {
    /// 0...100. `nil` on a Mac with no battery, which draws an empty cell.
    public var level: Double?
    /// Drawn only while a charger is attached.
    public var isCharging: Bool
    /// The shield is the guard: it disappears while monitoring is paused.
    public var guardActive: Bool

    public init(level: Double?, isCharging: Bool, guardActive: Bool) {
        self.level = level
        self.isCharging = isCharging
        self.guardActive = guardActive
    }

    // MARK: - Geometry, verbatim from the artwork

    private enum Art {
        static let canvas: CGFloat = 1024
        static let plateRadius: CGFloat = 236

        /// Every element's union, including half the shield's stroke, so the
        /// mark keeps one size whether or not the shield is drawn and nothing
        /// is clipped at the edges.
        static let content = NSRect(x: 86, y: 110, width: 852, height: 864)

        static let cap = NSRect(x: 413, y: 120, width: 198, height: 100)
        static let capRadius: CGFloat = 34

        static let body = NSRect(x: 329.5, y: 219, width: 361.5, height: 587)
        static let bodyRadius: CGFloat = 70
        static let bodyStroke: CGFloat = 40

        /// The artwork's own fill window covers only the lower third of the
        /// cell, so a full battery never looked full. The charge fills the
        /// cell's interior instead, inset inside the 40-unit stroke.
        static let window = NSRect(x: 362, y: 252, width: 297, height: 522)
        static let windowRadius: CGFloat = 36

        static let shield = """
            M132 302 C124 330 119 390 124 440 C128 520 158 600 206 678 \
            C232 720 275 775 324 822 C370 860 440 900 512 934 \
            C584 900 654 860 700 822 C749 775 792 720 818 678 \
            C866 600 896 520 900 440 C905 390 900 330 892 302 L742 236 \
            C762 270 814 312 830 346 C828 392 826 440 813 488 \
            C798 545 774 612 731 678 C694 730 644 786 586 828 \
            C562 845 536 858 512 862 C488 858 462 845 438 828 \
            C380 786 330 730 293 678 C250 612 226 545 211 488 \
            C198 440 196 392 194 346 C210 312 262 270 282 236 Z
            """

        static let bolt = "M487 533 L525 419 H411 L538 277 L500 391 H614 Z"

        /// The shield's outer contour on its own, stroked rather than filled.
        /// The artwork fills a thick arm shape, which reads as a heavy slab
        /// beside Apple's hairline battery in the menu bar.
        static let shieldOutline = """
            M282 236 L132 302 C124 330 119 390 124 440 C128 520 158 600 206 678 \
            C232 720 275 775 324 822 C370 860 440 900 512 934 \
            C584 900 654 860 700 822 C749 775 792 720 818 678 \
            C866 600 896 520 900 440 C905 390 900 330 892 302 L742 236
            """
        static let shieldStroke: CGFloat = 46
        static let slimBodyStroke: CGFloat = 30

        /// The artwork's bolt has notched corners that turn to mush at menu
        /// bar size. This one is bigger and plainer, closer to the bolt in
        /// Apple's own battery glyph.
        static let slimBolt = "M556 318 L424 556 H508 L470 716 L600 470 H516 Z"
    }

    private enum Palette {
        static func rgb(_ hex: UInt32) -> NSColor {
            NSColor(
                calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }

        static let plate = NSGradient(colors: [rgb(0x141D2A), rgb(0x090E15)])
        static let blue = NSGradient(
            colors: [rgb(0x5BD1FB), rgb(0x2E8CFF), rgb(0x1663F5)],
            atLocations: [0, 0.45, 1],
            colorSpace: .deviceRGB
        )
        static let cell = NSGradient(colors: [rgb(0x101C2C), rgb(0x0A1119)])
        static let bolt = NSGradient(colors: [rgb(0xB6EF62), rgb(0x2FC978)])

        /// Solid fill tinted by how much charge is left, matching the
        /// thresholds in the artwork's own script.
        static func fill(level: Double) -> NSGradient? {
            if level <= 15 { return NSGradient(colors: [rgb(0xFF9C86), rgb(0xEF4444)]) }
            if level <= 35 { return NSGradient(colors: [rgb(0xFFD866), rgb(0xF59E0B)]) }
            return NSGradient(colors: [rgb(0xA8E85E), rgb(0x35CE7C)])
        }
    }

    // MARK: - Drawing

    /// - Parameters:
    ///   - includePlate: true for the application icon, false for the menu
    ///     bar, which sits directly on the bar and must be transparent.
    ///   - monochrome: draws every shape in one colour for use as a template
    ///     image, which macOS tints to match the menu bar. Level is still
    ///     legible from the fill height.
    public func draw(in size: CGSize, includePlate: Bool, monochrome: Bool = false) {
        // The menu bar sits next to Apple's own hairline battery, so the mark
        // is drawn with lighter strokes there than on the application icon.
        let slim = !includePlate
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        context.imageInterpolation = .high

        let source =
            includePlate
            ? NSRect(x: 0, y: 0, width: Art.canvas, height: Art.canvas)
            : Art.content
        let scale = min(size.width / source.width, size.height / source.height)

        let transform = NSAffineTransform()
        transform.translateX(
            by: (size.width - source.width * scale) / 2,
            yBy: (size.height + source.height * scale) / 2
        )
        // The artwork's y axis runs downward; AppKit's runs up.
        transform.scaleX(by: scale, yBy: -scale)
        transform.translateX(by: -source.minX, yBy: -source.minY)
        transform.concat()

        if includePlate {
            let plate = NSBezierPath(
                roundedRect: NSRect(x: 0, y: 0, width: Art.canvas, height: Art.canvas),
                xRadius: Art.plateRadius,
                yRadius: Art.plateRadius
            )
            fill(plate, with: Palette.plate, from: NSPoint(x: 0, y: 0), to: NSPoint(x: 0, y: Art.canvas))
        }

        let ink = monochrome ? NSGradient(colors: [.black, .black]) : Palette.blue

        if guardActive {
            if slim {
                let arc = SVGPath.path(Art.shieldOutline)
                let stroked = arc.cgPath.copy(
                    strokingWithWidth: Art.shieldStroke,
                    lineCap: .round,
                    lineJoin: .round,
                    miterLimit: 10
                )
                fill(NSBezierPath(cgPath: stroked), with: ink, from: blueStart, to: blueEnd)
            } else {
                fill(SVGPath.path(Art.shield), with: ink, from: blueStart, to: blueEnd)
            }
        }

        fill(
            NSBezierPath(roundedRect: Art.cap, xRadius: Art.capRadius, yRadius: Art.capRadius),
            with: ink,
            from: blueStart,
            to: blueEnd
        )

        let bodyStroke = slim ? Art.slimBodyStroke : Art.bodyStroke
        let body = NSBezierPath(roundedRect: Art.body, xRadius: Art.bodyRadius, yRadius: Art.bodyRadius)
        if includePlate, !monochrome {
            fill(body, with: Palette.cell, from: NSPoint(x: 0, y: Art.body.minY), to: NSPoint(x: 0, y: 806))
        }
        let outline = body.cgPath.copy(
            strokingWithWidth: bodyStroke,
            lineCap: .butt,
            lineJoin: .miter,
            miterLimit: 10
        )
        fill(NSBezierPath(cgPath: outline), with: ink, from: blueStart, to: blueEnd)

        let bolt = SVGPath.path(slim ? Art.slimBolt : Art.bolt)
        let fraction = min(max(level ?? 0, 0), 100) / 100
        let chargeHeight = Art.window.height * fraction
        // The artwork's y axis runs downward, so the charge sits at the bottom.
        let charge = NSRect(
            x: Art.window.minX,
            y: Art.window.maxY - chargeHeight,
            width: Art.window.width,
            height: chargeHeight
        )

        // Above the charge the bolt is painted; within it the bolt is a hole
        // punched clean through. Painting it in the same ink as the fill and
        // relying on a hairline gap made it vanish at menu bar size.
        if isCharging, charge.minY > Art.window.minY {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(
                rect: NSRect(
                    x: Art.window.minX,
                    y: Art.window.minY,
                    width: Art.window.width,
                    height: charge.minY - Art.window.minY
                )
            ).addClip()
            fill(
                bolt,
                with: monochrome ? NSGradient(colors: [.black, .black]) : Palette.bolt,
                from: NSPoint(x: 411, y: 277),
                to: NSPoint(x: 641, y: 723)
            )
            NSGraphicsContext.restoreGraphicsState()
        }

        if let level, level > 0,
            let gradient = monochrome
                ? NSGradient(colors: [.black, .black])
                : Palette.fill(level: level)
        {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(
                roundedRect: Art.window,
                xRadius: Art.windowRadius,
                yRadius: Art.windowRadius
            ).addClip()

            let region = NSBezierPath(rect: charge)
            if isCharging {
                // Slightly inflated so the hole survives being scaled to 18pt.
                region.append(
                    NSBezierPath(
                        cgPath: bolt.cgPath.copy(
                            strokingWithWidth: 34,
                            lineCap: .round,
                            lineJoin: .round,
                            miterLimit: 10
                        )))
                region.append(bolt)
            }
            region.windingRule = .evenOdd
            region.addClip()

            gradient.draw(
                from: NSPoint(x: Art.window.minX, y: Art.window.minY),
                to: NSPoint(x: Art.window.maxX, y: Art.window.maxY),
                options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation]
            )
            NSGraphicsContext.restoreGraphicsState()
        }

        context.restoreGraphicsState()
    }

    private var blueStart: NSPoint { NSPoint(x: 0, y: 120) }
    private var blueEnd: NSPoint { NSPoint(x: 0, y: 935) }

    private func fill(_ path: NSBezierPath, with gradient: NSGradient?, from: NSPoint, to: NSPoint) {
        guard let gradient else { return }
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        gradient.draw(from: from, to: to, options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation])
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: - Output

    public func image(size: CGSize, includePlate: Bool, monochrome: Bool = false) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            self.draw(in: size, includePlate: includePlate, monochrome: monochrome)
            return true
        }
        // A template image is tinted by macOS to match the menu bar, in either
        // appearance and while the menu is open.
        image.isTemplate = monochrome
        return image
    }

    /// Rendered at exact pixel dimensions: `NSImage.lockFocus` would follow the
    /// display's backing scale and silently double every file.
    public func png(pixels: Int, includePlate: Bool, monochrome: Bool = false) -> Data? {
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixels,
                pixelsHigh: pixels,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else { return nil }
        rep.size = NSSize(width: pixels, height: pixels)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(in: CGSize(width: pixels, height: pixels), includePlate: includePlate, monochrome: monochrome)
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }
}

extension NSBezierPath {
    fileprivate convenience init(cgPath: CGPath) {
        self.init()
        cgPath.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint: move(to: points[0])
            case .addLineToPoint: line(to: points[0])
            case .addQuadCurveToPoint:
                let start = currentPoint
                let control1 = NSPoint(
                    x: start.x + 2.0 / 3.0 * (points[0].x - start.x),
                    y: start.y + 2.0 / 3.0 * (points[0].y - start.y)
                )
                let control2 = NSPoint(
                    x: points[1].x + 2.0 / 3.0 * (points[0].x - points[1].x),
                    y: points[1].y + 2.0 / 3.0 * (points[0].y - points[1].y)
                )
                curve(to: points[1], controlPoint1: control1, controlPoint2: control2)
            case .addCurveToPoint:
                curve(to: points[2], controlPoint1: points[0], controlPoint2: points[1])
            case .closeSubpath: close()
            @unknown default: break
            }
        }
    }
}
