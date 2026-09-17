import SwiftUI
import VoltGuardCore
import VoltGuardIcon

public enum StatusIcon {
    public static func image(for status: MonitoringStatus, height: CGFloat = 18) -> NSImage {
        let mark = BatteryShieldIcon(
            level: status.snapshot?.combinedPercentage.map(Double.init),
            isCharging: isPluggedIn(status),
            guardActive: status.state == .active
        )
        return mark.image(
            size: CGSize(width: height, height: height),
            includePlate: false,
            monochrome: true
        )
    }

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
