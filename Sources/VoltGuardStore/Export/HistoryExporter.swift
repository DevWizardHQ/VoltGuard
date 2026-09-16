import Foundation
import VoltGuardCore

public enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case csv, json, txt

    public var id: String { rawValue }
    public var fileExtension: String { rawValue }
    public var displayName: String { rawValue.uppercased() }
}

public enum ExportRange: Equatable, Sendable {
    case all
    case lastDays(Int)
    case custom(Date, Date)

    public func interval(now: Date) -> DateInterval {
        switch self {
        case .all:
            // Genuinely unbounded: a sample written a moment ago can carry a
            // timestamp slightly ahead of this call, and "All" must not drop it.
            return DateInterval(start: Date(timeIntervalSince1970: 0), end: .distantFuture)
        case let .lastDays(days):
            return DateInterval(start: now.addingTimeInterval(-Double(days) * 86_400), end: now)
        case let .custom(start, end):
            return DateInterval(start: min(start, end), end: max(start, end))
        }
    }
}

public struct HistoryExporter: Sendable {
    private let store: HistoryStore

    public init(store: HistoryStore) {
        self.store = store
    }

    public func export(
        format: ExportFormat,
        range: ExportRange,
        to url: URL,
        now: Date = Date()
    ) async throws {
        let interval = range.interval(now: now)
        let entries = try await store.samples(from: interval.start, to: interval.end)
        let sessions = try await store.sessions(from: interval.start, to: interval.end)
        let alerts = try await store.alerts(from: interval.start, to: interval.end)

        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        switch format {
        case .csv:
            try writeCSV(entries: entries, handle: handle)
        case .json:
            try writeJSON(entries: entries, sessions: sessions, alerts: alerts, handle: handle)
        case .txt:
            try writeText(entries: entries, sessions: sessions, handle: handle)
        }
    }

    private func write(_ string: String, to handle: FileHandle) throws {
        guard let data = string.data(using: .utf8) else { return }
        try handle.write(contentsOf: data)
    }

    private func writeCSV(entries: [BatteryHistoryEntry], handle: FileHandle) throws {
        try write("timestamp,battery_percentage,charging,power_source\n", to: handle)
        let formatter = ISO8601DateFormatter()
        var buffer = ""
        for entry in entries {
            buffer += "\(formatter.string(from: entry.timestamp)),"
            buffer += "\(entry.percentage),"
            buffer += "\(entry.chargingState.isCharging),"
            buffer += "\(entry.powerSource.displayName)\n"
            if buffer.utf8.count > 64_000 {
                try write(buffer, to: handle)
                buffer = ""
            }
        }
        try write(buffer, to: handle)
    }

    private func writeJSON(
        entries: [BatteryHistoryEntry],
        sessions: [ChargingSession],
        alerts: [AlertLogEntry],
        handle: FileHandle
    ) throws {
        let formatter = ISO8601DateFormatter()
        var payload: [String: Any] = [:]
        payload["samples"] = entries.map { entry in
            [
                "timestamp": formatter.string(from: entry.timestamp),
                "battery_percentage": entry.percentage,
                "charging": entry.chargingState.isCharging,
                "charging_state": entry.chargingState.displayName,
                "power_source": entry.powerSource.displayName,
                "monitoring_state": entry.monitoringState.displayName,
            ] as [String: Any]
        }
        payload["charging_sessions"] = sessions.map { session in
            [
                "started_at": formatter.string(from: session.startedAt),
                "ended_at": session.endedAt.map(formatter.string(from:)) ?? NSNull(),
                "start_percentage": session.startPercentage,
                "end_percentage": session.endPercentage ?? NSNull(),
                "peak_percentage": session.peakPercentage,
            ] as [String: Any]
        }
        payload["alerts"] = alerts.map { alert in
            [
                "timestamp": formatter.string(from: alert.timestamp),
                "rule": alert.ruleName,
                "threshold": alert.threshold,
                "battery_percentage": alert.percentage,
                "channels": alert.channels.map(\.rawValue),
                "delivered": alert.wasDelivered,
            ] as [String: Any]
        }
        let data = try JSONSerialization.data(
            withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try handle.write(contentsOf: data)
    }

    private func writeText(
        entries: [BatteryHistoryEntry],
        sessions: [ChargingSession],
        handle: FileHandle
    ) throws {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        try write("VoltGuard Battery History\n=========================\n\n", to: handle)
        for entry in entries {
            let line =
                "\(formatter.string(from: entry.timestamp))  \(entry.percentage)%  "
                + "\(entry.chargingState.displayName)  \(entry.powerSource.displayName)\n"
            try write(line, to: handle)
        }
        try write("\nCharging Sessions\n-----------------\n", to: handle)
        for session in sessions {
            let ended = session.endedAt.map(formatter.string(from:)) ?? "in progress"
            let line =
                "\(formatter.string(from: session.startedAt)) → \(ended)  "
                + "\(session.startPercentage)% → \(session.endPercentage.map { "\($0)%" } ?? "—")\n"
            try write(line, to: handle)
        }
    }
}
