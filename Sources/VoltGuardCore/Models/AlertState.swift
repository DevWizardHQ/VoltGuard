import Foundation

public enum RuleLatch: Codable, Equatable, Sendable {
    case clear
    case armed(generation: Int, enteredAt: Date, lastFiredAt: Date?, fireCount: Int)

    public var isArmed: Bool {
        if case .armed = self { return true }
        return false
    }

    public var generation: Int {
        if case let .armed(generation, _, _, _) = self { return generation }
        return 0
    }
}

public struct AlertEventKey: Hashable, Codable, Sendable {
    public let ruleID: UUID
    public let generation: Int
    public let powerSessionID: UUID

    public init(ruleID: UUID, generation: Int, powerSessionID: UUID) {
        self.ruleID = ruleID
        self.generation = generation
        self.powerSessionID = powerSessionID
    }
}

public struct AlertEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let key: AlertEventKey
    public let rule: AlertRule
    public let snapshot: BatterySnapshot
    public let title: String
    public let body: String
    public let firedAt: Date

    public init(
        id: UUID = UUID(),
        key: AlertEventKey,
        rule: AlertRule,
        snapshot: BatterySnapshot,
        title: String,
        body: String,
        firedAt: Date
    ) {
        self.id = id
        self.key = key
        self.rule = rule
        self.snapshot = snapshot
        self.title = title
        self.body = body
        self.firedAt = firedAt
    }
}

public enum SuppressionReason: String, Codable, Sendable {
    case repetitionIntervalNotElapsed
    case alreadyFiredThisGeneration
    case dialogAlreadyPresented
    case monitoringPaused
    case outsideSchedule
    case reconcilingAfterRestartOrWake
    case alertsDisabled
}

public enum ChannelError: Error, Equatable, Sendable {
    case permissionDenied
    case resourceUnavailable(String)
    case presentationFailed(String)
}

public enum ChannelOutcome: Equatable, Sendable {
    case delivered
    case suppressed(SuppressionReason)
    case failed(ChannelError)
}

public struct AlertDelivery: Equatable, Sendable {
    public let event: AlertEvent
    public let outcomes: [AlertChannel: ChannelOutcome]

    public init(event: AlertEvent, outcomes: [AlertChannel: ChannelOutcome]) {
        self.event = event
        self.outcomes = outcomes
    }

    public var deliveredChannels: [AlertChannel] {
        outcomes.filter { $0.value == .delivered }.keys.sorted { $0.rawValue < $1.rawValue }
    }
}
