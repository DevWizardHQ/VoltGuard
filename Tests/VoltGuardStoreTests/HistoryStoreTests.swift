import Foundation
import Testing
import VoltGuardCore

@testable import VoltGuardStore

private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

private func snapshot(
    _ percentage: Int,
    source: PowerSource = .battery,
    charging: ChargingState = .discharging,
    at offset: TimeInterval = 0
) -> BatterySnapshot {
    BatterySnapshot(
        timestamp: epoch.addingTimeInterval(offset),
        sources: [
            BatteryReading(
                identifier: "InternalBattery-0",
                percentage: percentage,
                chargingState: charging,
                powerSource: source,
                isPresent: true
            )
        ]
    )
}

private func makeStore() throws -> HistoryStore {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("voltguard-test-\(UUID().uuidString).sqlite")
    return try HistoryStore(url: url)
}

@Suite("History store")
struct HistoryStoreTests {
    @Test("a fresh database is migrated to the current version")
    func migrations() async throws {
        let store = try makeStore()
        #expect(try await store.count() == 0)
    }

    @Test("samples round-trip")
    func roundTrip() async throws {
        let store = try makeStore()
        try await store.insert(snapshot: snapshot(55), monitoringState: .active)
        try await store.insert(snapshot: snapshot(54, at: 600), monitoringState: .active)

        let entries = try await store.samples(
            from: epoch.addingTimeInterval(-60),
            to: epoch.addingTimeInterval(3_600)
        )
        #expect(entries.count == 2)
        #expect(entries[0].percentage == 55)
        #expect(entries[1].monitoringState == .active)
    }

    @Test("a desktop snapshot writes nothing")
    func desktopWritesNothing() async throws {
        let store = try makeStore()
        try await store.insert(
            snapshot: BatterySnapshot(timestamp: epoch, sources: []),
            monitoringState: .noBatteryMac
        )
        #expect(try await store.count() == 0)
    }

    @Test("a charging session opens on AC and closes when unplugged")
    func chargingSession() async throws {
        let store = try makeStore()
        try await store.insert(
            snapshot: snapshot(30, source: .ac, charging: .charging), monitoringState: .active)
        try await store.insert(
            snapshot: snapshot(65, source: .ac, charging: .charging, at: 3_600),
            monitoringState: .active
        )
        try await store.insert(snapshot: snapshot(64, at: 7_200), monitoringState: .active)

        let sessions = try await store.sessions(
            from: epoch.addingTimeInterval(-60),
            to: epoch.addingTimeInterval(86_400)
        )
        #expect(sessions.count == 1)
        #expect(sessions[0].startPercentage == 30)
        #expect(sessions[0].endPercentage == 64)
        #expect(sessions[0].peakPercentage == 65)
        #expect(sessions[0].isInProgress == false)
    }

    @Test("reaching 100 percent stamps the session once")
    func reachedFull() async throws {
        let store = try makeStore()
        try await store.insert(
            snapshot: snapshot(99, source: .ac, charging: .charging), monitoringState: .active)
        try await store.insert(
            snapshot: snapshot(100, source: .ac, charging: .full, at: 600),
            monitoringState: .active
        )
        try await store.insert(
            snapshot: snapshot(100, source: .ac, charging: .full, at: 1_200),
            monitoringState: .active
        )

        let sessions = try await store.sessions(
            from: epoch.addingTimeInterval(-60), to: epoch.addingTimeInterval(86_400))
        #expect(sessions[0].reachedFullAt == epoch.addingTimeInterval(600))
    }

    @Test("an abandoned session is closed from its last sample")
    func abandonedSession() async throws {
        let store = try makeStore()
        try await store.insert(
            snapshot: snapshot(40, source: .ac, charging: .charging), monitoringState: .active)
        try await store.recoverAbandonedSession(maxGap: 1_800, now: epoch.addingTimeInterval(86_400))

        let sessions = try await store.sessions(
            from: epoch.addingTimeInterval(-60), to: epoch.addingTimeInterval(86_400))
        #expect(sessions[0].endedAt == epoch)
        #expect(sessions[0].endPercentage == 40)
    }

    @Test("retention pruning removes older rows")
    func pruning() async throws {
        let store = try makeStore()
        try await store.insert(snapshot: snapshot(50, at: -90 * 86_400), monitoringState: .active)
        try await store.insert(snapshot: snapshot(51, at: 0), monitoringState: .active)
        _ = try await store.prune(before: epoch.addingTimeInterval(-30 * 86_400))
        #expect(try await store.count() == 1)
    }

    @Test("statistics aggregate the range")
    func statistics() async throws {
        let store = try makeStore()
        try await store.insert(snapshot: snapshot(80), monitoringState: .active)
        try await store.insert(snapshot: snapshot(60, at: 3_600), monitoringState: .active)
        try await store.insert(snapshot: snapshot(40, at: 7_200), monitoringState: .active)

        let statistics = try await store.statistics(
            from: epoch.addingTimeInterval(-60),
            to: epoch.addingTimeInterval(86_400),
            maxGap: 1_800
        )
        #expect(statistics.minimumPercentage == 40)
        #expect(statistics.maximumPercentage == 80)
        #expect(statistics.sampleCount == 3)
        #expect(statistics.dischargingDuration == 5_400)  // two gaps clamped to 2700 each
    }

    @Test("deleting all history empties every table")
    func deleteAll() async throws {
        let store = try makeStore()
        try await store.insert(
            snapshot: snapshot(50, source: .ac, charging: .charging), monitoringState: .active)
        try await store.deleteAll()
        #expect(try await store.count() == 0)
        #expect(
            try await store.sessions(
                from: epoch.addingTimeInterval(-60), to: epoch.addingTimeInterval(86_400)
            ).isEmpty)
    }
}

@Suite("Settings store")
struct SettingsStoreTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "voltguard-test-\(UUID().uuidString)")!
    }

    @Test("an empty store returns the shipped defaults")
    func emptyReturnsDefaults() {
        let store = SettingsStore(defaults: makeDefaults())
        #expect(store.load() == AppSettings.defaults)
        #expect(store.load().rules.count == 4)
    }

    @Test("settings round-trip")
    func roundTrip() {
        let store = SettingsStore(defaults: makeDefaults())
        var settings = AppSettings.defaults
        settings.monitoring.interval = 120
        settings.rules[0].threshold = 33
        settings.retention = .days90
        store.save(settings)
        #expect(store.load() == settings)
    }

    @Test("corrupt data falls back to defaults rather than crashing")
    func corruptFallsBack() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "settings.v1")
        #expect(SettingsStore(defaults: defaults).load() == AppSettings.defaults)
    }

    @Test("latches round-trip")
    func latchRoundTrip() {
        let store = SettingsStore(defaults: makeDefaults())
        let id = UUID()
        let latch = RuleLatch.armed(generation: 2, enteredAt: epoch, lastFiredAt: epoch, fireCount: 1)
        store.saveLatches([id: latch])
        #expect(store.loadLatches()[id] == latch)
    }

    @Test("reset clears persisted state")
    func reset() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        var settings = AppSettings.defaults
        settings.retention = .forever
        store.save(settings)
        store.reset()
        #expect(store.load() == AppSettings.defaults)
    }
}

@Suite("Export")
struct ExportTests {
    @Test("CSV uses the documented header and one row per sample")
    func csvGolden() async throws {
        let store = try makeStore()
        try await store.insert(
            snapshot: snapshot(74, source: .ac, charging: .charging), monitoringState: .active)
        try await store.insert(
            snapshot: snapshot(76, source: .ac, charging: .charging, at: 600), monitoringState: .active)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voltguard-export-\(UUID().uuidString).csv")
        try await HistoryExporter(store: store).export(
            format: .csv,
            range: .all,
            to: url,
            now: epoch.addingTimeInterval(86_400)
        )

        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        #expect(lines[0] == "timestamp,battery_percentage,charging,power_source")
        #expect(lines.count == 3)
        #expect(lines[1].contains("74,true,AC Power"))
    }

    @Test("JSON export carries samples, sessions, and alerts")
    func jsonStructure() async throws {
        let store = try makeStore()
        try await store.insert(snapshot: snapshot(50), monitoringState: .active)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voltguard-export-\(UUID().uuidString).json")
        try await HistoryExporter(store: store).export(
            format: .json,
            range: .all,
            to: url,
            now: epoch.addingTimeInterval(86_400)
        )

        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect(object?["samples"] != nil)
        #expect(object?["charging_sessions"] != nil)
        #expect(object?["alerts"] != nil)
    }

    @Test("an empty range still produces a valid file")
    func emptyExport() async throws {
        let store = try makeStore()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voltguard-export-\(UUID().uuidString).csv")
        try await HistoryExporter(store: store).export(format: .csv, range: .lastDays(7), to: url)
        let contents = try String(contentsOf: url, encoding: .utf8)
        #expect(contents == "timestamp,battery_percentage,charging,power_source\n")
    }

    @Test("range presets resolve to the expected interval")
    func rangeResolution() {
        let now = epoch
        #expect(ExportRange.lastDays(7).interval(now: now).duration == 7 * 86_400)
        #expect(ExportRange.custom(now, now.addingTimeInterval(-3_600)).interval(now: now).duration == 3_600)
    }
}

@Suite("Export range bounds")
struct ExportRangeBoundsTests {
    @Test("`all` includes a sample timestamped after the export call")
    func allIsUnbounded() async throws {
        let store = try makeStore()
        let future = Date().addingTimeInterval(3_600)
        try await store.insert(
            snapshot: snapshot(42, at: future.timeIntervalSince(epoch)), monitoringState: .active)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voltguard-export-\(UUID().uuidString).csv")
        try await HistoryExporter(store: store).export(format: .csv, range: .all, to: url)

        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 2)
    }
}
