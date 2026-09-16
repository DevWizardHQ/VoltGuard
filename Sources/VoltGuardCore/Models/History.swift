import Foundation

public struct BatteryHistoryEntry: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let timestamp: Date
    public let percentage: Int
    public let chargingState: ChargingState
    public let powerSource: PowerSource
    public let monitoringState: MonitoringStateKind
    public let cycleCount: Int?
    public let maxCapacityPercent: Int?

    public init(
        id: Int64,
        timestamp: Date,
        percentage: Int,
        chargingState: ChargingState,
        powerSource: PowerSource,
        monitoringState: MonitoringStateKind,
        cycleCount: Int? = nil,
        maxCapacityPercent: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.percentage = percentage
        self.chargingState = chargingState
        self.powerSource = powerSource
        self.monitoringState = monitoringState
        self.cycleCount = cycleCount
        self.maxCapacityPercent = maxCapacityPercent
    }
}

public struct ChargingSession: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let startedAt: Date
    public let endedAt: Date?
    public let startPercentage: Int
    public let endPercentage: Int?
    public let peakPercentage: Int
    public let reachedFullAt: Date?

    public var isInProgress: Bool { endedAt == nil }

    public var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    public var gainedPercentage: Int? {
        guard let endPercentage else { return nil }
        return endPercentage - startPercentage
    }

    public init(
        id: Int64,
        startedAt: Date,
        endedAt: Date?,
        startPercentage: Int,
        endPercentage: Int?,
        peakPercentage: Int,
        reachedFullAt: Date?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.startPercentage = startPercentage
        self.endPercentage = endPercentage
        self.peakPercentage = peakPercentage
        self.reachedFullAt = reachedFullAt
    }
}

public struct AlertLogEntry: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let timestamp: Date
    public let ruleID: UUID
    public let ruleName: String
    public let direction: ThresholdDirection
    public let threshold: Int
    public let percentage: Int
    public let powerSource: PowerSource
    public let channels: [AlertChannel]
    public let wasDelivered: Bool

    public init(
        id: Int64,
        timestamp: Date,
        ruleID: UUID,
        ruleName: String,
        direction: ThresholdDirection,
        threshold: Int,
        percentage: Int,
        powerSource: PowerSource,
        channels: [AlertChannel],
        wasDelivered: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.ruleID = ruleID
        self.ruleName = ruleName
        self.direction = direction
        self.threshold = threshold
        self.percentage = percentage
        self.powerSource = powerSource
        self.channels = channels
        self.wasDelivered = wasDelivered
    }
}

public struct BatteryStatistics: Equatable, Sendable {
    public let range: DateInterval
    public let averagePercentage: Double?
    public let minimumPercentage: Int?
    public let maximumPercentage: Int?
    public let chargingDuration: TimeInterval
    public let dischargingDuration: TimeInterval
    public let lowAlertCount: Int
    public let highAlertCount: Int
    public let sampleCount: Int

    public init(
        range: DateInterval,
        averagePercentage: Double?,
        minimumPercentage: Int?,
        maximumPercentage: Int?,
        chargingDuration: TimeInterval,
        dischargingDuration: TimeInterval,
        lowAlertCount: Int,
        highAlertCount: Int,
        sampleCount: Int
    ) {
        self.range = range
        self.averagePercentage = averagePercentage
        self.minimumPercentage = minimumPercentage
        self.maximumPercentage = maximumPercentage
        self.chargingDuration = chargingDuration
        self.dischargingDuration = dischargingDuration
        self.lowAlertCount = lowAlertCount
        self.highAlertCount = highAlertCount
        self.sampleCount = sampleCount
    }

    public static func empty(range: DateInterval) -> BatteryStatistics {
        BatteryStatistics(
            range: range,
            averagePercentage: nil,
            minimumPercentage: nil,
            maximumPercentage: nil,
            chargingDuration: 0,
            dischargingDuration: 0,
            lowAlertCount: 0,
            highAlertCount: 0,
            sampleCount: 0
        )
    }
}

public struct DailyAggregate: Identifiable, Equatable, Sendable {
    public var id: Date { day }
    public let day: Date
    public let average: Double
    public let minimum: Int
    public let maximum: Int
    public let sampleCount: Int

    public init(day: Date, average: Double, minimum: Int, maximum: Int, sampleCount: Int) {
        self.day = day
        self.average = average
        self.minimum = minimum
        self.maximum = maximum
        self.sampleCount = sampleCount
    }
}
