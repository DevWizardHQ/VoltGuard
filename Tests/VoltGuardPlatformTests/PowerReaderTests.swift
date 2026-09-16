import Foundation
import Testing
import VoltGuardCore

@testable import VoltGuardPlatform

@Suite("IOKit reading mapping")
struct PowerReaderTests {
    private func description(
        current: Int,
        max: Int = 100,
        charging: Bool,
        charged: Bool = false,
        state: String,
        present: Bool = true
    ) -> [String: Any] {
        [
            kIOPSTypeKey: kIOPSInternalBatteryType,
            kIOPSNameKey: "InternalBattery-0",
            kIOPSIsPresentKey: present,
            kIOPSCurrentCapacityKey: current,
            kIOPSMaxCapacityKey: max,
            kIOPSIsChargingKey: charging,
            kIOPSIsChargedKey: charged,
            kIOPSPowerSourceStateKey: state,
        ]
    }

    @Test("discharging on battery power")
    func discharging() {
        let reading = IOKitPowerSourceReader.makeReading(
            from: description(current: 42, charging: false, state: kIOPSBatteryPowerValue),
            externalPower: false
        )
        #expect(reading?.percentage == 42)
        #expect(reading?.chargingState == .discharging)
        #expect(reading?.powerSource == .battery)
    }

    @Test("charging on AC power")
    func charging() {
        let reading = IOKitPowerSourceReader.makeReading(
            from: description(current: 80, charging: true, state: kIOPSACPowerValue),
            externalPower: true
        )
        #expect(reading?.chargingState == .charging)
        #expect(reading?.powerSource == .ac)
    }

    @Test("plugged in but not charging is distinct from charging")
    func notCharging() {
        let reading = IOKitPowerSourceReader.makeReading(
            from: description(current: 100, charging: false, state: kIOPSACPowerValue),
            externalPower: true
        )
        #expect(reading?.chargingState == .notCharging)
    }

    @Test("a charged battery reports full")
    func full() {
        let reading = IOKitPowerSourceReader.makeReading(
            from: description(current: 100, charging: false, charged: true, state: kIOPSACPowerValue),
            externalPower: true
        )
        #expect(reading?.chargingState == .full)
    }

    @Test("percentage is computed from current over max capacity")
    func scaledCapacity() {
        let reading = IOKitPowerSourceReader.makeReading(
            from: description(current: 2_500, max: 5_000, charging: false, state: kIOPSBatteryPowerValue),
            externalPower: false
        )
        #expect(reading?.percentage == 50)
    }

    @Test("a non-battery power source is ignored")
    func ignoresOtherTypes() {
        var raw = description(current: 50, charging: false, state: kIOPSBatteryPowerValue)
        raw[kIOPSTypeKey] = "USB Mouse"
        #expect(IOKitPowerSourceReader.makeReading(from: raw, externalPower: false) == nil)
    }

    @Test("an unknown power-source string falls back to the providing source")
    func unknownStateFallsBack() {
        var raw = description(current: 50, charging: false, state: "Something New")
        raw[kIOPSPowerSourceStateKey] = "Something New"
        let reading = IOKitPowerSourceReader.makeReading(from: raw, externalPower: true)
        #expect(reading?.powerSource == .ac)
    }
}
