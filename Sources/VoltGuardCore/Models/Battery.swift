import Foundation

public enum PowerSource: Int, Codable, Sendable, CaseIterable {
    case battery
    case ac
    case ups
    case unknown

    public var displayName: String {
        switch self {
        case .battery: "Battery Power"
        case .ac: "AC Power"
        case .ups: "UPS"
        case .unknown: "Unknown"
        }
    }
}

public enum ChargingState: Int, Codable, Sendable, CaseIterable {
    case discharging
    case charging
    case full
    case notCharging
    case unknown

    public var displayName: String {
        switch self {
        case .discharging: "Discharging"
        case .charging: "Charging"
        case .full: "Fully Charged"
        case .notCharging: "Not Charging"
        case .unknown: "Unknown"
        }
    }

    public var isCharging: Bool { self == .charging }
}

public struct BatteryHealth: Codable, Equatable, Sendable {
    public let cycleCount: Int?
    public let condition: String?
    public let maxCapacityPercent: Int?

    public init(cycleCount: Int? = nil, condition: String? = nil, maxCapacityPercent: Int? = nil) {
        self.cycleCount = cycleCount
        self.condition = condition
        self.maxCapacityPercent = maxCapacityPercent
    }
}

public struct BatteryReading: Codable, Equatable, Sendable {
    public let identifier: String
    public let percentage: Int
    public let chargingState: ChargingState
    public let powerSource: PowerSource
    public let isPresent: Bool
    public let maxCapacity: Int
    public let timeRemaining: TimeInterval?
    public let health: BatteryHealth?

    public init(
        identifier: String,
        percentage: Int,
        chargingState: ChargingState,
        powerSource: PowerSource,
        isPresent: Bool,
        maxCapacity: Int = 100,
        timeRemaining: TimeInterval? = nil,
        health: BatteryHealth? = nil
    ) {
        self.identifier = identifier
        self.percentage = min(max(percentage, 0), 100)
        self.chargingState = chargingState
        self.powerSource = powerSource
        self.isPresent = isPresent
        self.maxCapacity = max(maxCapacity, 1)
        self.timeRemaining = timeRemaining
        self.health = health
    }
}

public struct BatterySnapshot: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let sources: [BatteryReading]
    public let combinedPercentage: Int?
    public let powerSource: PowerSource
    public let chargingState: ChargingState

    public var hasBattery: Bool { combinedPercentage != nil }

    public var primaryHealth: BatteryHealth? {
        sources.first(where: { $0.isPresent })?.health
    }

    public var timeRemaining: TimeInterval? {
        sources.compactMap(\.timeRemaining).max()
    }

    public init(timestamp: Date, sources: [BatteryReading]) {
        self.timestamp = timestamp
        self.sources = sources

        let present = sources.filter(\.isPresent)
        if present.isEmpty {
            self.combinedPercentage = nil
        } else {
            // Capacity-weighted so an internal battery is not averaged flat
            // against a much smaller attached one.
            let totalCapacity = present.reduce(0) { $0 + $1.maxCapacity }
            let weighted = present.reduce(0) { $0 + $1.percentage * $1.maxCapacity }
            self.combinedPercentage =
                totalCapacity > 0
                ? Int((Double(weighted) / Double(totalCapacity)).rounded())
                : nil
        }

        self.powerSource = Self.resolvePowerSource(present.isEmpty ? sources : present)
        self.chargingState = Self.resolveChargingState(present)
    }

    private static func resolvePowerSource(_ readings: [BatteryReading]) -> PowerSource {
        if readings.contains(where: { $0.powerSource == .ac }) { return .ac }
        if readings.contains(where: { $0.powerSource == .battery }) { return .battery }
        if readings.contains(where: { $0.powerSource == .ups }) { return .ups }
        return .unknown
    }

    private static func resolveChargingState(_ readings: [BatteryReading]) -> ChargingState {
        if readings.isEmpty { return .unknown }
        if readings.contains(where: { $0.chargingState == .charging }) { return .charging }
        if readings.allSatisfy({ $0.chargingState == .full }) { return .full }
        if readings.contains(where: { $0.chargingState == .discharging }) { return .discharging }
        if readings.contains(where: { $0.chargingState == .notCharging }) { return .notCharging }
        return .unknown
    }
}
