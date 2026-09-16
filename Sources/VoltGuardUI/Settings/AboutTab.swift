import SwiftUI
import VoltGuardCore
import VoltGuardPlatform

struct AboutTab: View {
    @Environment(AppState.self) private var state

    private static let repository = URL(string: "https://github.com/DevWizardHQ/VoltGuard")!
    private static let issues = URL(
        string: "https://github.com/DevWizardHQ/VoltGuard/issues/new?labels=bug&template=bug_report.yml")!
    private static let feedback = URL(string: "https://github.com/DevWizardHQ/VoltGuard/discussions")!

    var body: some View {
        @Bindable var state = state

        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VoltGuard").font(.title2).bold()
                    Text("Smart Battery Monitoring & Alerts for macOS")
                        .foregroundStyle(.secondary)
                    Text("Version \(Diagnostics.appVersion) (\(Diagnostics.buildNumber))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("By DevWizardHQ · MIT licensed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $state.settings.automaticUpdateChecks)
                Picker("Channel", selection: $state.settings.updateChannel) {
                    ForEach(UpdateChannelOption.allCases) { Text($0.displayName).tag($0.value) }
                }
                LabeledContent("Last checked", value: lastCheckedText)
                Button("Check for Updates…") { state.updateService.checkForUpdates() }
                    .disabled(!state.updateService.isUpdaterAvailable)
                if !state.updateService.isUpdaterAvailable {
                    Text("Updates are only available in a packaged VoltGuard.app build.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Project") {
                Link("Open GitHub", destination: Self.repository)
                Link("Send Feedback", destination: Self.feedback)
                Link("Report a Bug", destination: Self.issues)
            }

            Section("Privacy") {
                Text(
                    "VoltGuard keeps every battery sample on this Mac. The only network request it ever makes is the update check."
                )
                .font(.caption)
            }
        }
        .formStyle(.grouped)
    }

    private var lastCheckedText: String {
        guard let date = state.updateService.lastCheckDate else { return "Never" }
        return date.formatted(.dateTime.day().month().hour().minute())
    }
}

private enum UpdateChannelOption: String, CaseIterable, Identifiable {
    case stable, beta

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var value: VoltGuardCore.UpdateChannel { self == .beta ? .beta : .stable }
}
