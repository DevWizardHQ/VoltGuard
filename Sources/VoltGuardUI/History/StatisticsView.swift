import Charts
import SwiftUI
import VoltGuardCore

struct StatisticsView: View {
    @Environment(AppState.self) private var state
    @State private var range: HistoryRange = .week
    @State private var statistics: BatteryStatistics?
    @State private var daily: [DailyAggregate] = []

    var body: some View {
        VStack(spacing: 0) {
            RangeHeader(range: $range, label: "Statistics range")

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    currentSection

                    if let statistics {
                        summarySection(statistics)
                    }

                    if !daily.isEmpty {
                        Text("Daily average").font(.headline)
                        Chart(daily) { aggregate in
                            BarMark(
                                x: .value("Day", aggregate.day, unit: .day),
                                y: .value("Average", aggregate.average)
                            )
                            .foregroundStyle(.tint)
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 180)
                        .accessibilityLabel("Daily average battery level")
                    }
                }
                .padding(16)
            }
        }
        .historyTabLayout()
        .task(id: range) { await load() }
    }

    private var currentSection: some View {
        GroupBox("Current") {
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent(
                    "Battery", value: state.status.snapshot?.combinedPercentage.map { "\($0)%" } ?? "—")
                LabeledContent("Status", value: state.status.snapshot?.chargingState.displayName ?? "—")
                LabeledContent("Power source", value: state.status.snapshot?.powerSource.displayName ?? "—")
                if let health = state.status.snapshot?.primaryHealth {
                    if let cycles = health.cycleCount {
                        LabeledContent("Cycle count", value: "\(cycles)")
                    }
                    if let condition = health.condition {
                        LabeledContent("Condition", value: condition)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summarySection(_ statistics: BatteryStatistics) -> some View {
        GroupBox(range.title) {
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent(
                    "Average", value: statistics.averagePercentage.map { String(format: "%.0f%%", $0) } ?? "—"
                )
                LabeledContent("Minimum", value: statistics.minimumPercentage.map { "\($0)%" } ?? "—")
                LabeledContent("Maximum", value: statistics.maximumPercentage.map { "\($0)%" } ?? "—")
                LabeledContent("Charging time", value: format(statistics.chargingDuration))
                LabeledContent("Discharging time", value: format(statistics.dischargingDuration))
                LabeledContent("Low battery alerts", value: "\(statistics.lowAlertCount)")
                LabeledContent("High battery alerts", value: "\(statistics.highAlertCount)")
                LabeledContent("Samples", value: "\(statistics.sampleCount)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func format(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3_600
        let minutes = (Int(duration) % 3_600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func load() async {
        guard let store = state.history else { return }
        let interval = range.interval()
        statistics = try? await store.statistics(
            from: interval.start,
            to: interval.end,
            maxGap: state.settings.monitoring.maxSampleGap
        )
        daily = (try? await store.dailyAggregates(from: interval.start, to: interval.end)) ?? []
    }
}
