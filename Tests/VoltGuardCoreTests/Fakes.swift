import Foundation

@testable import VoltGuardCore

struct FakeClock: VoltGuardClock {
    var now: Date
    var uptime: TimeInterval = 0
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}

enum Make {
    static let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    static func snapshot(
        percentage: Int?,
        source: PowerSource = .battery,
        charging: ChargingState = .discharging,
        at offset: TimeInterval = 0
    ) -> BatterySnapshot {
        guard let percentage else {
            return BatterySnapshot(timestamp: epoch.addingTimeInterval(offset), sources: [])
        }
        return BatterySnapshot(
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

    static func rule(
        name: String = "Low Warning",
        threshold: Int = 20,
        direction: ThresholdDirection = .low,
        power: PowerCondition = .onBatteryOnly,
        repetition: RepetitionPolicy = .once,
        margin: Int = 3
    ) -> AlertRule {
        AlertRule(
            name: name,
            threshold: threshold,
            direction: direction,
            powerCondition: power,
            repetition: repetition,
            releaseMarginPercent: margin
        )
    }
}

actor ScriptedPowerSource: PowerSourceReader {
    private var snapshots: [Result<BatterySnapshot, PowerReadError>]
    private var index = 0

    init(_ snapshots: [BatterySnapshot]) {
        self.snapshots = snapshots.map { .success($0) }
    }

    init(results: [Result<BatterySnapshot, PowerReadError>]) {
        self.snapshots = results
    }

    func read() async throws -> BatterySnapshot {
        guard index < snapshots.count else {
            guard let last = snapshots.last else { throw PowerReadError.unavailable("empty script") }
            return try last.get()
        }
        defer { index += 1 }
        return try snapshots[index].get()
    }
}

actor RecordingDispatcher: AlertDelivering {
    private(set) var events: [AlertEvent] = []

    func deliver(_ event: AlertEvent) async -> [AlertChannel: ChannelOutcome] {
        events.append(event)
        return Dictionary(uniqueKeysWithValues: event.rule.channels.map { ($0, ChannelOutcome.delivered) })
    }

    func recorded() -> [AlertEvent] { events }
}

actor RecordingRecorder: HistoryRecording {
    private(set) var samples: [(BatterySnapshot, MonitoringStateKind)] = []
    private(set) var deliveries: [AlertDelivery] = []

    func record(snapshot: BatterySnapshot, monitoringState: MonitoringStateKind) async {
        samples.append((snapshot, monitoringState))
    }

    func record(delivery: AlertDelivery) async {
        deliveries.append(delivery)
    }

    func sampleCount() -> Int { samples.count }
}
