import Foundation
import IOKit.ps
import VoltGuardCore

public struct IOKitPowerSourceReader: PowerSourceReader {
    public init() {}

    public func read() async throws -> BatterySnapshot {
        try Self.readSnapshot()
    }

    static func readSnapshot(now: Date = Date()) throws -> BatterySnapshot {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            throw PowerReadError.unavailable("IOPSCopyPowerSourcesInfo returned nil")
        }
        guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            throw PowerReadError.unavailable("IOPSCopyPowerSourcesList returned nil")
        }

        let providingSource = IOPSGetProvidingPowerSourceType(blob)?.takeRetainedValue() as String?
        let externalPower = providingSource == kIOPMACPowerKey

        let readings = list.compactMap { source -> BatteryReading? in
            guard
                let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                    as? [String: Any]
            else { return nil }
            return makeReading(from: description, externalPower: externalPower)
        }

        return BatterySnapshot(timestamp: now, sources: readings)
    }

    static func makeReading(from description: [String: Any], externalPower: Bool) -> BatteryReading? {
        let type = description[kIOPSTypeKey] as? String
        guard type == kIOPSInternalBatteryType || type == kIOPSUPSType else { return nil }

        let isPresent = description[kIOPSIsPresentKey] as? Bool ?? false
        let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
        let percentage = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : 0

        let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
        let isCharged = description[kIOPSIsChargedKey] as? Bool ?? false
        let powerSourceState = description[kIOPSPowerSourceStateKey] as? String

        let powerSource: PowerSource
        switch powerSourceState {
        case kIOPSACPowerValue: powerSource = .ac
        case kIOPSBatteryPowerValue: powerSource = .battery
        case kIOPSOffLineValue: powerSource = .unknown
        default: powerSource = externalPower ? .ac : .battery
        }

        let chargingState: ChargingState
        if isCharging {
            chargingState = .charging
        } else if isCharged {
            chargingState = .full
        } else if powerSource == .ac {
            chargingState = .notCharging
        } else if isPresent {
            chargingState = .discharging
        } else {
            chargingState = .unknown
        }

        let timeToEmpty = description[kIOPSTimeToEmptyKey] as? Int
        let timeToFull = description[kIOPSTimeToFullChargeKey] as? Int
        let minutes = isCharging ? timeToFull : timeToEmpty
        // IOKit reports -1 while it is still estimating.
        let timeRemaining = minutes.flatMap { $0 > 0 ? TimeInterval($0 * 60) : nil }

        let health = BatteryHealth(
            cycleCount: (description["Cycle Count"] as? Int)
                ?? (description[kIOPSHardwareSerialNumberKey] as? Int),
            condition: description["BatteryHealthCondition"] as? String
                ?? description[kIOPSBatteryHealthKey] as? String,
            maxCapacityPercent: description["NominalChargeCapacity"] as? Int
        )

        return BatteryReading(
            identifier: description[kIOPSNameKey] as? String ?? "InternalBattery",
            percentage: percentage,
            chargingState: chargingState,
            powerSource: powerSource,
            isPresent: isPresent,
            maxCapacity: max(maximum, 1),
            timeRemaining: timeRemaining,
            health: health
        )
    }
}
