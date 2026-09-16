import Foundation

public enum ThresholdDirection: Int, Codable, Sendable, CaseIterable {
    case low
    case high

    public var displayName: String {
        switch self {
        case .low: "Low"
        case .high: "High"
        }
    }
}

public enum PowerCondition: Int, Codable, Sendable, CaseIterable {
    case onBatteryOnly
    case onACOnly
    case any

    public var displayName: String {
        switch self {
        case .onBatteryOnly: "Only on battery power"
        case .onACOnly: "Only while plugged in"
        case .any: "Any power source"
        }
    }
}

public enum AlertChannel: String, Codable, Sendable, CaseIterable, Identifiable {
    case notification
    case sound
    case voice
    case dialog

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .notification: "Notification"
        case .sound: "Sound"
        case .voice: "Voice"
        case .dialog: "Dialog"
        }
    }
}

public enum ComparisonOperator: Int, Codable, Sendable {
    case lessThanOrEqual
    case greaterThanOrEqual
    case equal

    public func matches(_ lhs: Int, _ rhs: Int) -> Bool {
        switch self {
        case .lessThanOrEqual: lhs <= rhs
        case .greaterThanOrEqual: lhs >= rhs
        case .equal: lhs == rhs
        }
    }
}

public enum RuleCondition: Codable, Equatable, Sendable {
    case percentage(ComparisonOperator, Int)
    case powerSource(PowerSource)
    case charging(Bool)

    public func matches(_ snapshot: BatterySnapshot) -> Bool {
        switch self {
        case let .percentage(op, value):
            guard let current = snapshot.combinedPercentage else { return false }
            return op.matches(current, value)
        case let .powerSource(source):
            return snapshot.powerSource == source
        case let .charging(expected):
            return snapshot.chargingState.isCharging == expected
        }
    }
}

public enum RepetitionPolicy: Codable, Equatable, Sendable, Hashable {
    case once
    case interval(TimeInterval)
    case untilConditionChanges

    public static let presets: [RepetitionPolicy] = [
        .once,
        .interval(300),
        .interval(600),
        .interval(900),
        .interval(1800),
        .interval(3600),
        .untilConditionChanges,
    ]

    public var displayName: String {
        switch self {
        case .once: "Once"
        case let .interval(seconds): "Every \(Int(seconds / 60)) minutes"
        case .untilConditionChanges: "Until condition changes"
        }
    }
}

public struct AlertRule: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var threshold: Int
    public var direction: ThresholdDirection
    public var powerCondition: PowerCondition
    public var channels: Set<AlertChannel>
    public var message: String?
    public var soundName: String?
    public var repetition: RepetitionPolicy
    public var releaseMarginPercent: Int
    public var extraConditions: [RuleCondition]
    public var dialogIsDismissible: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        threshold: Int,
        direction: ThresholdDirection,
        powerCondition: PowerCondition,
        channels: Set<AlertChannel> = [.notification, .sound],
        message: String? = nil,
        soundName: String? = nil,
        repetition: RepetitionPolicy = .interval(600),
        releaseMarginPercent: Int = 3,
        extraConditions: [RuleCondition] = [],
        dialogIsDismissible: Bool = true
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.threshold = min(max(threshold, 0), 100)
        self.direction = direction
        self.powerCondition = powerCondition
        self.channels = channels
        self.message = message
        self.soundName = soundName
        self.repetition = repetition
        self.releaseMarginPercent = max(releaseMarginPercent, 0)
        self.extraConditions = extraConditions
        self.dialogIsDismissible = dialogIsDismissible
    }

    /// Conditions derived from the simple fields, ANDed with `extraConditions`.
    public var resolvedConditions: [RuleCondition] {
        var conditions: [RuleCondition] = [
            .percentage(direction == .low ? .lessThanOrEqual : .greaterThanOrEqual, threshold)
        ]
        switch powerCondition {
        case .onBatteryOnly: conditions.append(.powerSource(.battery))
        case .onACOnly: conditions.append(.powerSource(.ac))
        case .any: break
        }
        return conditions + extraConditions
    }

    public func matches(_ snapshot: BatterySnapshot) -> Bool {
        guard isEnabled, snapshot.hasBattery else { return false }
        return resolvedConditions.allSatisfy { $0.matches(snapshot) }
    }

    /// Latched rules only release once the reading clears the threshold by the
    /// margin; without it a battery oscillating at the boundary re-alerts.
    public func hasReleased(_ snapshot: BatterySnapshot) -> Bool {
        guard let current = snapshot.combinedPercentage else { return true }
        let releasePoint =
            direction == .low
            ? threshold + releaseMarginPercent
            : threshold - releaseMarginPercent
        let clearedThreshold =
            direction == .low
            ? current >= releasePoint
            : current <= releasePoint
        let otherConditions = resolvedConditions.filter {
            if case .percentage = $0 { return false }
            return true
        }
        return clearedThreshold || !otherConditions.allSatisfy { $0.matches(snapshot) }
    }
}
