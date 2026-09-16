import Foundation

public enum PowerReadError: Error, Equatable, Sendable {
    case unavailable(String)
}

public protocol PowerSourceReader: Sendable {
    func read() async throws -> BatterySnapshot
}

public protocol HistoryRecording: Sendable {
    func record(snapshot: BatterySnapshot, monitoringState: MonitoringStateKind) async
    func record(delivery: AlertDelivery) async
}

public protocol AlertDelivering: Sendable {
    func deliver(_ event: AlertEvent) async -> [AlertChannel: ChannelOutcome]
}

public struct EngineConfiguration: Equatable, Sendable {
    public var monitoring: MonitoringConfiguration
    public var rules: [AlertRule]
    public var schedule: MonitoringSchedule

    public init(
        monitoring: MonitoringConfiguration = DefaultConfiguration.monitoring,
        rules: [AlertRule] = DefaultConfiguration.rules,
        schedule: MonitoringSchedule = DefaultConfiguration.schedule
    ) {
        self.monitoring = monitoring
        self.rules = rules
        self.schedule = schedule
    }
}

public struct MonitoringStatus: Equatable, Sendable {
    public let state: MonitoringStateKind
    public let snapshot: BatterySnapshot?
    public let nextCheck: Date?
    public let lastErrorDescription: String?

    public init(
        state: MonitoringStateKind,
        snapshot: BatterySnapshot?,
        nextCheck: Date?,
        lastErrorDescription: String? = nil
    ) {
        self.state = state
        self.snapshot = snapshot
        self.nextCheck = nextCheck
        self.lastErrorDescription = lastErrorDescription
    }
}

public enum TickTrigger: Equatable, Sendable {
    case timer
    case powerSourceChanged
    case manual
    case wake
}
