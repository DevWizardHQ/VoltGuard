import Foundation
import VoltGuardCore

public actor HistoryStore {
    private let database: SQLiteDatabase
    private var openSessionID: Int64?

    public static func defaultURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("VoltGuard", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("history.sqlite")
    }

    public init(path: String) throws {
        self.database = try SQLiteDatabase(path: path)
        try Migrations.apply(to: database)
    }

    public init(url: URL) throws {
        try self.init(path: url.path)
    }

    // MARK: - Writing

    public func insert(snapshot: BatterySnapshot, monitoringState: MonitoringStateKind) throws {
        guard let percentage = snapshot.combinedPercentage else { return }
        let health = snapshot.primaryHealth
        try database.run(
            """
            INSERT INTO samples
                (ts, percentage, charging_state, power_source, monitoring_state, cycle_count, max_capacity_pct)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7);
            """,
            [
                .date(snapshot.timestamp),
                .int(percentage),
                .int(snapshot.chargingState.rawValue),
                .int(snapshot.powerSource.rawValue),
                .int(monitoringState.rawValue),
                .optionalInt(health?.cycleCount),
                .optionalInt(health?.maxCapacityPercent),
            ]
        )
        try updateChargingSession(snapshot: snapshot, percentage: percentage)
    }

    public func insert(delivery: AlertDelivery) throws {
        let event = delivery.event
        let delivered = delivery.deliveredChannels
        try database.run(
            """
            INSERT INTO alert_events
                (ts, rule_id, rule_name, direction, threshold, percentage, power_source, channels, outcome)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9);
            """,
            [
                .date(event.firedAt),
                .text(event.rule.id.uuidString),
                .text(event.rule.name),
                .int(event.rule.direction.rawValue),
                .int(event.rule.threshold),
                .int(event.snapshot.combinedPercentage ?? 0),
                .int(event.snapshot.powerSource.rawValue),
                .text(delivered.map(\.rawValue).joined(separator: ",")),
                .int(delivered.isEmpty ? 0 : 1),
            ]
        )
    }

    // MARK: - Charging sessions

    private func updateChargingSession(snapshot: BatterySnapshot, percentage: Int) throws {
        let onPower = snapshot.powerSource == .ac

        if onPower {
            if openSessionID == nil {
                if let existing = try openSessionIdentifier() {
                    openSessionID = existing
                } else {
                    openSessionID = try database.run(
                        """
                        INSERT INTO charging_sessions (started_at, start_pct, peak_pct)
                        VALUES (?1, ?2, ?2);
                        """,
                        [.date(snapshot.timestamp), .int(percentage)]
                    )
                }
            }
            guard let sessionID = openSessionID else { return }
            try database.run(
                "UPDATE charging_sessions SET peak_pct = MAX(peak_pct, ?2) WHERE id = ?1;",
                [.integer(sessionID), .int(percentage)]
            )
            if percentage >= 100 {
                try database.run(
                    """
                    UPDATE charging_sessions SET reached_full_at = COALESCE(reached_full_at, ?2)
                    WHERE id = ?1;
                    """,
                    [.integer(sessionID), .date(snapshot.timestamp)]
                )
            }
        } else if let sessionID = try openSessionID ?? openSessionIdentifier() {
            try database.run(
                "UPDATE charging_sessions SET ended_at = ?2, end_pct = ?3 WHERE id = ?1;",
                [.integer(sessionID), .date(snapshot.timestamp), .int(percentage)]
            )
            openSessionID = nil
        }
    }

    private func openSessionIdentifier() throws -> Int64? {
        try database.query(
            "SELECT id FROM charging_sessions WHERE ended_at IS NULL ORDER BY started_at DESC LIMIT 1;"
        ) { $0.int64(0) }.first
    }

    /// Closes a session abandoned by a crash or force-quit, using the last
    /// sample inside it rather than inventing an end value.
    public func recoverAbandonedSession(maxGap: TimeInterval, now: Date) throws {
        guard let sessionID = try openSessionIdentifier() else { return }
        let started = try database.query(
            "SELECT started_at FROM charging_sessions WHERE id = ?1;",
            [.integer(sessionID)]
        ) { $0.date(0) }.first
        guard let started else { return }

        let last = try database.query(
            "SELECT ts, percentage FROM samples WHERE ts >= ?1 ORDER BY ts DESC LIMIT 1;",
            [.date(started)]
        ) { (date: $0.date(0), percentage: $0.int(1)) }.first

        guard let last, now.timeIntervalSince(last.date) > maxGap * 2 else {
            openSessionID = sessionID
            return
        }
        try database.run(
            "UPDATE charging_sessions SET ended_at = ?2, end_pct = ?3 WHERE id = ?1;",
            [.integer(sessionID), .date(last.date), .int(last.percentage)]
        )
        openSessionID = nil
    }

    // MARK: - Reading

    public func samples(from start: Date, to end: Date, limit: Int = 100_000) throws -> [BatteryHistoryEntry]
    {
        try database.query(
            """
            SELECT id, ts, percentage, charging_state, power_source, monitoring_state, cycle_count, max_capacity_pct
            FROM samples WHERE ts >= ?1 AND ts <= ?2 ORDER BY ts ASC LIMIT ?3;
            """,
            [.date(start), .date(end), .int(limit)]
        ) { row in
            BatteryHistoryEntry(
                id: row.int64(0),
                timestamp: row.date(1),
                percentage: row.int(2),
                chargingState: ChargingState(rawValue: row.int(3)) ?? .unknown,
                powerSource: PowerSource(rawValue: row.int(4)) ?? .unknown,
                monitoringState: MonitoringStateKind(rawValue: row.int(5)) ?? .active,
                cycleCount: row.optionalInt(6),
                maxCapacityPercent: row.optionalInt(7)
            )
        }
    }

    public func sessions(from start: Date, to end: Date) throws -> [ChargingSession] {
        try database.query(
            """
            SELECT id, started_at, ended_at, start_pct, end_pct, peak_pct, reached_full_at
            FROM charging_sessions WHERE started_at >= ?1 AND started_at <= ?2
            ORDER BY started_at DESC;
            """,
            [.date(start), .date(end)]
        ) { row in
            ChargingSession(
                id: row.int64(0),
                startedAt: row.date(1),
                endedAt: row.optionalDate(2),
                startPercentage: row.int(3),
                endPercentage: row.optionalInt(4),
                peakPercentage: row.int(5),
                reachedFullAt: row.optionalDate(6)
            )
        }
    }

    public func alerts(from start: Date, to end: Date) throws -> [AlertLogEntry] {
        try database.query(
            """
            SELECT id, ts, rule_id, rule_name, direction, threshold, percentage, power_source, channels, outcome
            FROM alert_events WHERE ts >= ?1 AND ts <= ?2 ORDER BY ts DESC;
            """,
            [.date(start), .date(end)]
        ) { row in
            AlertLogEntry(
                id: row.int64(0),
                timestamp: row.date(1),
                ruleID: UUID(uuidString: row.text(2)) ?? UUID(),
                ruleName: row.text(3),
                direction: ThresholdDirection(rawValue: row.int(4)) ?? .low,
                threshold: row.int(5),
                percentage: row.int(6),
                powerSource: PowerSource(rawValue: row.int(7)) ?? .unknown,
                channels: row.text(8).split(separator: ",").compactMap { AlertChannel(rawValue: String($0)) },
                wasDelivered: row.int(9) == 1
            )
        }
    }

    public func dailyAggregates(from start: Date, to end: Date) throws -> [DailyAggregate] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return try database.query(
            """
            SELECT strftime('%Y-%m-%d', ts, 'unixepoch', 'localtime') AS day,
                   AVG(percentage), MIN(percentage), MAX(percentage), COUNT(*)
            FROM samples WHERE ts >= ?1 AND ts <= ?2
            GROUP BY day ORDER BY day ASC;
            """,
            [.date(start), .date(end)]
        ) { row in
            DailyAggregate(
                day: formatter.date(from: row.text(0)) ?? start,
                average: row.double(1),
                minimum: row.int(2),
                maximum: row.int(3),
                sampleCount: row.int(4)
            )
        }
    }

    public func statistics(from start: Date, to end: Date, maxGap: TimeInterval) throws -> BatteryStatistics {
        let range = DateInterval(start: start, end: max(end, start))
        let entries = try samples(from: start, to: end)
        guard !entries.isEmpty else { return .empty(range: range) }

        let percentages = entries.map(\.percentage)
        let durations = StatisticsCalculator.durations(samples: entries, maxGap: maxGap)
        let alertEntries = try alerts(from: start, to: end).filter(\.wasDelivered)

        return BatteryStatistics(
            range: range,
            averagePercentage: Double(percentages.reduce(0, +)) / Double(percentages.count),
            minimumPercentage: percentages.min(),
            maximumPercentage: percentages.max(),
            chargingDuration: durations.charging,
            dischargingDuration: durations.discharging,
            lowAlertCount: alertEntries.filter { $0.direction == .low }.count,
            highAlertCount: alertEntries.filter { $0.direction == .high }.count,
            sampleCount: entries.count
        )
    }

    // MARK: - Retention

    @discardableResult
    public func prune(before cutoff: Date) throws -> Int {
        try database.transaction {
            try database.run("DELETE FROM samples WHERE ts < ?1;", [.date(cutoff)])
            try database.run("DELETE FROM alert_events WHERE ts < ?1;", [.date(cutoff)])
            try database.run(
                "DELETE FROM charging_sessions WHERE ended_at IS NOT NULL AND ended_at < ?1;",
                [.date(cutoff)]
            )
        }
        try database.execute("PRAGMA incremental_vacuum;")
        return try count()
    }

    public func deleteAll() throws {
        try database.transaction {
            try database.execute(
                "DELETE FROM samples; DELETE FROM alert_events; DELETE FROM charging_sessions;")
        }
        openSessionID = nil
        try database.execute("PRAGMA incremental_vacuum;")
    }

    public func count() throws -> Int {
        try database.query("SELECT COUNT(*) FROM samples;") { $0.int(0) }.first ?? 0
    }

    func withDatabase<T>(_ body: (SQLiteDatabase) throws -> T) rethrows -> T {
        try body(database)
    }
}
