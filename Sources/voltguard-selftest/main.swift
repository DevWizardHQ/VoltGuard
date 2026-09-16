import Foundation
import VoltGuardCore
import VoltGuardPlatform
import VoltGuardStore

/// Exercises the real monitoring stack — IOKit, SQLite, the engine and the
/// alert pipeline — against this machine, so the parts unit tests can only
/// fake are verified on real hardware. Presentation is excluded: it needs a
/// UI session, and this must run headless in CI.
@main
enum SelfTest {
    static func main() async {
        var failures: [String] = []

        func check(_ name: String, _ condition: @autoclosure () -> Bool, _ detail: String = "") {
            if condition() {
                print("  ok    \(name)")
            } else {
                print("  FAIL  \(name) \(detail)")
                failures.append(name)
            }
        }

        print("VoltGuard self-test")
        print("===================")

        print("\n[1] IOKit power source")
        var snapshot: BatterySnapshot?
        do {
            snapshot = try await IOKitPowerSourceReader().read()
            print("  read ok: \(describe(snapshot!))")
            if let percentage = snapshot!.combinedPercentage {
                check("power source is normalized", snapshot!.powerSource != .unknown)
                check("percentage within 0...100", (0...100).contains(percentage), "got \(percentage)")
                check("charging state is known", snapshot!.chargingState != .unknown)
            } else {
                // A batteryless Mac — a desktop, or a CI VM — reports no
                // sources at all, so `unknown` is the correct answer here.
                print("  note: no battery present — exercising the desktop path")
                check("no sources are reported present", snapshot!.sources.allSatisfy { !$0.isPresent })
            }
        } catch {
            check("IOKit read succeeds", false, "\(error)")
        }

        print("\n[2] Power source notifications")
        let monitor = PowerSourceMonitor()
        monitor.start {}
        monitor.stop()
        check("run loop source attaches and detaches", true)

        print("\n[3] SQLite history")
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voltguard-selftest-\(UUID().uuidString).sqlite")
        do {
            let store = try HistoryStore(url: dbURL)
            let now = Date()
            try await store.insert(
                snapshot: make(50, .battery, .discharging, now),
                monitoringState: .active
            )
            try await store.insert(
                snapshot: make(51, .ac, .charging, now.addingTimeInterval(600)),
                monitoringState: .active
            )
            try await store.insert(
                snapshot: make(52, .battery, .discharging, now.addingTimeInterval(1_200)),
                monitoringState: .active
            )

            let rows = try await store.samples(
                from: now.addingTimeInterval(-60),
                to: now.addingTimeInterval(7_200)
            )
            check("three samples persisted", rows.count == 3, "got \(rows.count)")

            let sessions = try await store.sessions(
                from: now.addingTimeInterval(-60),
                to: now.addingTimeInterval(7_200)
            )
            check("charging session opened and closed", sessions.count == 1 && !sessions[0].isInProgress)

            let stats = try await store.statistics(
                from: now.addingTimeInterval(-60),
                to: now.addingTimeInterval(7_200),
                maxGap: 1_800
            )
            check("statistics computed", stats.sampleCount == 3 && stats.maximumPercentage == 52)

            let exportURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("voltguard-selftest-\(UUID().uuidString).csv")
            try await HistoryExporter(store: store).export(format: .csv, range: .all, to: exportURL)
            let csv = try String(contentsOf: exportURL, encoding: .utf8)
            check("CSV export has header and rows", csv.split(separator: "\n").count == 4)
            try? FileManager.default.removeItem(at: exportURL)

            _ = try await store.prune(before: now.addingTimeInterval(900))
            let remaining = try await store.count()
            check("retention prune removed old rows", remaining == 1, "remaining \(remaining)")
        } catch {
            check("history store works", false, "\(error)")
        }
        try? FileManager.default.removeItem(at: dbURL)

        print("\n[4] Monitoring engine against a real reader")
        let recorder = CountingRecorder()
        let dispatcher = CountingDispatcher()
        let engine = MonitoringEngine(
            reader: IOKitPowerSourceReader(),
            recorder: recorder,
            dispatcher: dispatcher,
            configuration: EngineConfiguration(
                monitoring: MonitoringConfiguration(interval: 60),
                rules: [
                    AlertRule(
                        name: "Selftest Always",
                        threshold: 100,
                        direction: .low,
                        powerCondition: .any,
                        channels: [.notification],
                        repetition: .untilConditionChanges
                    )
                ]
            )
        )
        await engine.tick(trigger: .manual)
        let stateAfterFirst = await engine.currentStatus().state
        await engine.tick(trigger: .manual)

        let delivered = await dispatcher.count()
        let sampled = await recorder.count()

        if snapshot?.hasBattery == true {
            check("engine reaches active", stateAfterFirst == .active, "state \(stateAfterFirst)")
            check("first tick reconciles, second alerts", delivered == 1, "delivered \(delivered)")
            check("at least one sample recorded", sampled >= 1, "samples \(sampled)")
        } else {
            check("desktop Mac stops monitoring", stateAfterFirst == .noBatteryMac)
            check("no alerts on a desktop Mac", delivered == 0)
        }

        print("\n[5] Settings persistence")
        let defaults = UserDefaults(suiteName: "voltguard-selftest-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        var written = AppSettings.defaults
        written.monitoring.interval = 120
        written.rules[0].threshold = 33
        settings.save(written)
        check("settings round-trip", settings.load() == written)
        check("defaults validate cleanly", RuleValidator.validate(AppSettings.defaults.rules).isEmpty)

        print("\n[6] Logging and diagnostics")
        Log.info(.system, "self-test log line")
        let report = Diagnostics.report(configurationSummary: "self-test")
        check("diagnostic report names the Mac model", report.contains(Diagnostics.modelIdentifier))
        check("diagnostic report includes pmset output", report.contains("pmset"))

        print("\n===================")
        if failures.isEmpty {
            print("PASS — all self-test checks succeeded")
            exit(0)
        }
        print("FAIL — \(failures.count) check(s) failed: \(failures.joined(separator: ", "))")
        exit(1)
    }

    static func make(
        _ percentage: Int,
        _ source: PowerSource,
        _ charging: ChargingState,
        _ date: Date
    ) -> BatterySnapshot {
        BatterySnapshot(
            timestamp: date,
            sources: [
                BatteryReading(
                    identifier: "SelfTest",
                    percentage: percentage,
                    chargingState: charging,
                    powerSource: source,
                    isPresent: true
                )
            ]
        )
    }

    static func describe(_ snapshot: BatterySnapshot) -> String {
        let percentage = snapshot.combinedPercentage.map { "\($0)%" } ?? "no battery"
        return "\(percentage), \(snapshot.chargingState.displayName), \(snapshot.powerSource.displayName), "
            + "\(snapshot.sources.count) source(s)"
    }
}

actor CountingRecorder: HistoryRecording {
    private var samples = 0
    private var deliveries = 0

    func record(snapshot: BatterySnapshot, monitoringState: MonitoringStateKind) async { samples += 1 }
    func record(delivery: AlertDelivery) async { deliveries += 1 }
    func count() -> Int { samples }
}

actor CountingDispatcher: AlertDelivering {
    private var delivered = 0

    func deliver(_ event: AlertEvent) async -> [AlertChannel: ChannelOutcome] {
        delivered += 1
        return [.notification: .delivered]
    }

    func count() -> Int { delivered }
}
