import SwiftUI
import VoltGuardCore

public struct MenuBarContent: View {
    @Environment(AppState.self) private var state
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    public init() {}

    public var body: some View {
        Group {
            statusRows
            Divider()

            if state.status.state != .noBatteryMac {
                Button(state.settings.monitoring.isEnabled ? "Pause Monitoring" : "Resume Monitoring") {
                    state.togglePause()
                }

                Button("Check Now") { state.checkNow() }

                Button(state.settings.monitoring.alertsGloballyEnabled ? "Disable Alerts" : "Enable Alerts") {
                    state.toggleAlerts()
                }
                Divider()
            }

            // Only worth showing when the user can actually fix it: an
            // unbundled copy has no notification centre to enable.
            if state.notificationAuthorization == .denied {
                Button("Notifications Are Turned Off…") { state.openNotificationSettings() }
                Divider()
            }

            Button("Battery History") { open(tab: .history) }
            Button("Statistics") { open(tab: .statistics) }
            Divider()

            Button("Settings…") { openSettings() }
            Divider()

            Button("Quit VoltGuard") { NSApplication.shared.terminate(nil) }
        }
    }

    @ViewBuilder
    private var statusRows: some View {
        if state.status.state == .noBatteryMac {
            Text("This Mac does not have a battery")
            Text("Battery monitoring is unavailable")
        } else {
            Text("Battery: \(batteryText)")
            Text("Status: \(state.status.snapshot?.chargingState.displayName ?? "Unknown")")
            Text("Monitoring: \(state.status.state.displayName)")
            if let nextCheck = state.status.nextCheck, state.status.state == .active {
                Text("Next check: \(relative(nextCheck))")
            }
            if let error = state.status.lastErrorDescription {
                Text("Last error: \(error)")
            }
        }
    }

    private var batteryText: String {
        guard let percentage = state.status.snapshot?.combinedPercentage else { return "Unknown" }
        return "\(percentage)%"
    }

    private func relative(_ date: Date) -> String {
        let minutes = Int(max(date.timeIntervalSinceNow, 0) / 60)
        return minutes <= 0 ? "under a minute" : "\(minutes) min"
    }

    private func open(tab: MainWindowTab) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: MainWindowTab.windowID, value: tab)
    }
}
