import Foundation
import Testing

@testable import VoltGuardCore

@Suite("Battery snapshot")
struct BatteryModelTests {
    @Test("a Mac with no battery reports no combined percentage")
    func desktopMac() {
        let snapshot = BatterySnapshot(timestamp: Make.epoch, sources: [])
        #expect(snapshot.combinedPercentage == nil)
        #expect(snapshot.hasBattery == false)
    }

    @Test("two batteries combine by capacity, not by plain average")
    func twoBatteries() {
        let snapshot = BatterySnapshot(
            timestamp: Make.epoch,
            sources: [
                BatteryReading(
                    identifier: "big", percentage: 100, chargingState: .discharging,
                    powerSource: .battery, isPresent: true, maxCapacity: 100
                ),
                BatteryReading(
                    identifier: "small", percentage: 0, chargingState: .discharging,
                    powerSource: .battery, isPresent: true, maxCapacity: 25
                ),
            ])
        #expect(snapshot.combinedPercentage == 80)
    }

    @Test("an absent battery is excluded from the combined value")
    func absentBattery() {
        let snapshot = BatterySnapshot(
            timestamp: Make.epoch,
            sources: [
                BatteryReading(
                    identifier: "present", percentage: 50, chargingState: .discharging,
                    powerSource: .battery, isPresent: true
                ),
                BatteryReading(
                    identifier: "absent", percentage: 0, chargingState: .unknown,
                    powerSource: .unknown, isPresent: false
                ),
            ])
        #expect(snapshot.combinedPercentage == 50)
    }

    @Test("charging on any source wins over discharging")
    func chargingWins() {
        let snapshot = BatterySnapshot(
            timestamp: Make.epoch,
            sources: [
                BatteryReading(
                    identifier: "a", percentage: 50, chargingState: .discharging,
                    powerSource: .battery, isPresent: true
                ),
                BatteryReading(
                    identifier: "b", percentage: 50, chargingState: .charging,
                    powerSource: .ac, isPresent: true
                ),
            ])
        #expect(snapshot.chargingState == .charging)
        #expect(snapshot.powerSource == .ac)
    }

    @Test("percentage is clamped to 0...100")
    func clamping() {
        let reading = BatteryReading(
            identifier: "x", percentage: 140, chargingState: .full,
            powerSource: .ac, isPresent: true
        )
        #expect(reading.percentage == 100)
    }
}

@Suite("Rule validation")
struct RuleValidatorTests {
    @Test("a rule with no channels is flagged")
    func noChannels() {
        var rule = Make.rule()
        rule.channels = []
        #expect(RuleValidator.validate([rule]).count == 1)
    }

    @Test("a low rule at or above a high rule is flagged")
    func invertedThresholds() {
        let low = Make.rule(name: "Low", threshold: 85, direction: .low)
        let high = Make.rule(name: "High", threshold: 80, direction: .high, power: .onACOnly)
        let warnings = RuleValidator.validate([low, high])
        #expect(warnings.contains { $0.message.contains("85%") })
    }

    @Test("duplicate thresholds in the same direction are flagged")
    func duplicates() {
        let first = Make.rule(name: "A", threshold: 20)
        let second = Make.rule(name: "B", threshold: 20)
        #expect(!RuleValidator.validate([first, second]).isEmpty)
    }

    @Test("the shipped defaults validate cleanly")
    func defaultsAreClean() {
        #expect(RuleValidator.validate(DefaultConfiguration.rules).isEmpty)
    }
}

@Suite("Message template")
struct MessageTemplateTests {
    @Test("every placeholder is substituted")
    func substitution() {
        let context = MessageContext(
            percentage: 18,
            threshold: 20,
            chargingState: .discharging,
            powerSource: .battery,
            date: Make.epoch
        )
        let output = MessageTemplate.render(
            "{battery} {threshold} {status} {power_source}",
            context: context
        )
        #expect(output == "18% 20% Discharging Battery Power")
    }

    @Test("an unknown placeholder is left alone")
    func unknownPlaceholder() {
        let context = MessageContext(
            percentage: 18, threshold: 20, chargingState: .discharging,
            powerSource: .battery, date: Make.epoch
        )
        #expect(MessageTemplate.render("{nope}", context: context) == "{nope}")
    }

    @Test("a missing percentage renders as unknown rather than crashing")
    func missingPercentage() {
        let context = MessageContext(
            percentage: nil, threshold: 20, chargingState: .unknown,
            powerSource: .unknown, date: Make.epoch
        )
        #expect(MessageTemplate.render("{battery}", context: context) == "unknown")
    }
}
