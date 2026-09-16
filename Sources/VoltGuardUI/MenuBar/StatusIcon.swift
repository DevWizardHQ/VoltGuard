import SwiftUI
import VoltGuardCore

public enum StatusIcon {
    public static func symbolName(for status: MonitoringStatus) -> String {
        switch status.state {
        case .pausedByUser: return "pause.circle"
        case .outsideSchedule: return "moon.zzz"
        case .systemAsleep: return "moon.zzz"
        case .degraded: return "exclamationmark.triangle"
        case .noBatteryMac: return "desktopcomputer"
        case .active: break
        }

        guard let snapshot = status.snapshot, let percentage = snapshot.combinedPercentage else {
            return "battery.50"
        }
        if snapshot.chargingState.isCharging { return "battery.100percent.bolt" }
        switch percentage {
        case ..<10: return "battery.0"
        case ..<25: return "battery.25"
        case ..<60: return "battery.50"
        case ..<85: return "battery.75"
        default: return "battery.100"
        }
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
