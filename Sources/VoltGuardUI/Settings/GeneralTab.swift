import SwiftUI
import VoltGuardCore

struct GeneralTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        Form {
            Section("Monitoring") {
                Toggle("Monitoring enabled", isOn: $state.settings.monitoring.isEnabled)
                Toggle("Alerts enabled", isOn: $state.settings.monitoring.alertsGloballyEnabled)

                Picker("Check every", selection: $state.settings.monitoring.interval) {
                    ForEach(MonitoringConfiguration.intervalPresets, id: \.self) { interval in
                        Text("\(Int(interval / 60)) minutes").tag(interval)
                    }
                }
                Text("VoltGuard also reacts immediately when the charger is connected or disconnected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch VoltGuard at login", isOn: $state.settings.launchAtLogin)
            }

            Section("Battery status") {
                LabeledContent(
                    "Battery", value: state.status.snapshot?.combinedPercentage.map { "\($0)%" } ?? "—")
                LabeledContent("Status", value: state.status.snapshot?.chargingState.displayName ?? "—")
                LabeledContent("Monitoring", value: state.status.state.displayName)
                Button("Check Now") { state.checkNow() }
            }
        }
        .formStyle(.grouped)
    }
}
