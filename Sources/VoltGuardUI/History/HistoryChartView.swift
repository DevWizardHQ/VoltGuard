import Charts
import SwiftUI
import VoltGuardCore

struct HistoryChartView: View {
    @Environment(AppState.self) private var state
    @State private var range: HistoryRange = .week
    @State private var points: [(date: Date, value: Double)] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Range", selection: $range) {
                ForEach(HistoryRange.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("History range")

            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if points.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text(
                        "VoltGuard records a sample whenever the battery level or power source changes.")
                )
            } else {
                Chart(points, id: \.date) { point in
                    AreaMark(x: .value("Time", point.date), y: .value("Battery", point.value))
                        .foregroundStyle(.tint.opacity(0.18))
                    LineMark(x: .value("Time", point.date), y: .value("Battery", point.value))
                        .foregroundStyle(.tint)
                        .interpolationMethod(.monotone)
                }
                .chartYScale(domain: 0...100)
                .chartYAxisLabel("Battery %")
                .accessibilityLabel("Battery level over the last \(range.title)")
            }
        }
        .padding()
        .task(id: range) { await load() }
    }

    private func load() async {
        guard let store = state.history else { return }
        isLoading = true
        defer { isLoading = false }
        let interval = range.interval()
        let entries = (try? await store.samples(from: interval.start, to: interval.end)) ?? []
        let raw = entries.map { ($0.timestamp, Double($0.percentage)) }
        points = StatisticsCalculator.downsample(raw).map { (date: $0.0, value: $0.1) }
    }
}
