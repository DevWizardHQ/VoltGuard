import SwiftUI
import VoltGuardCore

struct AlertLogView: View {
    @Environment(AppState.self) private var state
    @State private var entries: [AlertLogEntry] = []
    @State private var range: HistoryRange = .month

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Range", selection: $range) {
                ForEach(HistoryRange.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Alert history range")

            if entries.isEmpty {
                ContentUnavailableView(
                    "No alerts yet",
                    systemImage: "bell.slash",
                    description: Text("Alerts appear here once a rule fires.")
                )
            } else {
                Table(entries) {
                    TableColumn("When") { entry in
                        Text(entry.timestamp, format: .dateTime.day().month().hour().minute())
                    }
                    TableColumn("Rule", value: \.ruleName)
                    TableColumn("Threshold") { Text("\($0.threshold)%") }
                    TableColumn("Battery") { Text("\($0.percentage)%") }
                    TableColumn("Power") { Text($0.powerSource.displayName) }
                    TableColumn("Channels") { entry in
                        Text(entry.channels.map(\.displayName).joined(separator: ", "))
                    }
                    TableColumn("Delivered") { entry in
                        Image(systemName: entry.wasDelivered ? "checkmark.circle" : "xmark.circle")
                            .accessibilityLabel(entry.wasDelivered ? "Delivered" : "Not delivered")
                    }
                }
            }
        }
        .padding()
        .task(id: range) { await load() }
    }

    private func load() async {
        guard let store = state.history else { return }
        let interval = range.interval()
        entries = (try? await store.alerts(from: interval.start, to: interval.end)) ?? []
    }
}
