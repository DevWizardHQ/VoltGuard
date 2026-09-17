import SwiftUI
import VoltGuardCore
import VoltGuardIcon

public enum StatusIcon {
    /// The menu bar draws the same mark as the app icon, minus its plate: the
    /// shield shows while the guard is watching, the bolt while a charger is
    /// attached, and the cell fills to the real level.
    public static func image(for status: MonitoringStatus, height: CGFloat = 18) -> NSImage {
        let mark = BatteryShieldIcon(
            level: status.snapshot?.combinedPercentage.map(Double.init),
            isCharging: isPluggedIn(status),
            guardActive: status.state == .active
        )
        // Monochrome like every other menu bar item, except the charging bolt,
        // which is tinted green so it reads at 18pt. A tinted shape cannot be
        // a template image, so the ink follows the menu bar's appearance.
        return mark.image(
            size: CGSize(width: height, height: height),
            includePlate: false,
            monochrome: true,
            ink: menuBarInk(),
            boltTint: isPluggedIn(status) ? Self.chargingTint : nil
        )
    }

    /// Apple's system green, the colour macOS itself uses for charging.
    private static let chargingTint = NSColor(
        calibratedRed: 0.204, green: 0.780, blue: 0.349, alpha: 1)

    private static func menuBarInk() -> NSColor {
        let dark =
            NSApplication.shared.effectiveAppearance
            .bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return dark ? .white : .black
    }

    /// A charger being attached is what the bolt reports, not whether current
    /// is flowing: a full battery on mains is still plugged in.
    private static func isPluggedIn(_ status: MonitoringStatus) -> Bool {
        status.snapshot?.powerSource == .ac
    }

    public static func accessibilityLabel(for status: MonitoringStatus) -> String {
        guard let snapshot = status.snapshot, let percentage = snapshot.combinedPercentage else {
            return "VoltGuard, \(status.state.displayName)"
        }
        return
            "VoltGuard, battery \(percentage) percent, \(snapshot.powerSource.displayName), monitoring \(status.state.displayName)"
    }

    public static func menuBarText(for status: MonitoringStatus, showPercentage: Bool) -> String? {
        guard showPercentage, let percentage = status.snapshot?.combinedPercentage else { return nil }
        return "\(percentage)%"
    }
}
