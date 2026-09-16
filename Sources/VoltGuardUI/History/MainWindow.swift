import Charts
import SwiftUI
import VoltGuardCore
import VoltGuardStore

public enum MainWindowTab: String, Codable, Hashable, Identifiable, CaseIterable {
    case history, statistics, sessions, alerts

    public static let windowID = "main"
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .history: "History"
        case .statistics: "Statistics"
        case .sessions: "Charging Sessions"
        case .alerts: "Alerts"
        }
    }

    public var symbol: String {
        switch self {
        case .history: "chart.xyaxis.line"
        case .statistics: "chart.bar"
        case .sessions: "bolt.badge.clock"
        case .alerts: "bell"
        }
    }
}

public enum HistoryRange: String, CaseIterable, Identifiable {
    case day, week, month, quarter

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .day: "24 Hours"
        case .week: "7 Days"
        case .month: "30 Days"
        case .quarter: "90 Days"
        }
    }

    public var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        case .quarter: 90
        }
    }

    public func interval(now: Date = Date()) -> DateInterval {
        DateInterval(start: now.addingTimeInterval(-Double(days) * 86_400), end: now)
    }
}

public struct MainWindow: View {
    @Environment(AppState.self) private var state
    @State private var selection: MainWindowTab

    public init(tab: MainWindowTab = .history) {
        _selection = State(initialValue: tab)
    }

    public var body: some View {
        TabView(selection: $selection) {
            ForEach(MainWindowTab.allCases) { tab in
                content(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
        .frame(minWidth: 680, minHeight: 460)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func content(for tab: MainWindowTab) -> some View {
        switch tab {
        case .history: HistoryChartView()
        case .statistics: StatisticsView()
        case .sessions: ChargingSessionsView()
        case .alerts: AlertLogView()
        }
    }
}
