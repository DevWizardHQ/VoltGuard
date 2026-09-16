import SwiftUI
import VoltGuardCore

struct ChargingSessionsView: View {
    @Environment(AppState.self) private var state
    @State private var sessions: [ChargingSession] = []

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No charging sessions yet",
                    systemImage: "bolt.badge.clock",
                    description: Text("A session is recorded each time the charger is connected.")
                )
            } else {
                Table(sessions) {
                    TableColumn("Started") { session in
                        Text(session.startedAt, format: .dateTime.day().month().hour().minute())
                    }
                    TableColumn("Ended") { session in
                        Text(session.endedAt.map { $0.formatted(.dateTime.hour().minute()) } ?? "In progress")
                    }
                    TableColumn("From") { Text("\($0.startPercentage)%") }
                    TableColumn("To") { session in
                        Text(session.endPercentage.map { "\($0)%" } ?? "—")
                    }
                    TableColumn("Peak") { Text("\($0.peakPercentage)%") }
                    TableColumn("Duration") { session in
                        Text(session.duration.map(format) ?? "—")
                    }
                }
            }
        }
        .task { await load() }
    }

    private func format(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3_600
        let minutes = (Int(duration) % 3_600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func load() async {
        guard let store = state.history else { return }
        let interval = HistoryRange.month.interval()
        sessions = (try? await store.sessions(from: interval.start, to: interval.end)) ?? []
    }
}
