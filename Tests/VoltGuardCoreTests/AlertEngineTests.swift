import Foundation
import Testing

@testable import VoltGuardCore

@Suite("Alert engine")
struct AlertEngineTests {
    @Test("fires on entering the threshold state")
    func firesOnEntry() {
        var engine = AlertEngine()
        let rule = Make.rule()
        let result = engine.evaluate(
            snapshot: Make.snapshot(percentage: 18),
            rules: [rule],
            now: Make.epoch
        )
        #expect(result.events.count == 1)
        #expect(engine.latch(for: rule.id).isArmed)
    }

    @Test(
        "fires at exactly the threshold",
        arguments: [
            (ThresholdDirection.low, 20, 20, true),
            (ThresholdDirection.low, 20, 21, false),
            (ThresholdDirection.high, 80, 80, true),
            (ThresholdDirection.high, 80, 79, false),
        ])
    func boundaryComparison(direction: ThresholdDirection, threshold: Int, level: Int, expected: Bool) {
        var engine = AlertEngine()
        let rule = Make.rule(
            threshold: threshold,
            direction: direction,
            power: direction == .low ? .onBatteryOnly : .onACOnly
        )
        let result = engine.evaluate(
            snapshot: Make.snapshot(
                percentage: level,
                source: direction == .low ? .battery : .ac,
                charging: direction == .low ? .discharging : .charging
            ),
            rules: [rule],
            now: Make.epoch
        )
        #expect((result.events.count == 1) == expected)
    }

    @Test("does not refire while latched with .once")
    func onceDoesNotRefire() {
        var engine = AlertEngine()
        let rule = Make.rule(repetition: .once)
        _ = engine.evaluate(snapshot: Make.snapshot(percentage: 18), rules: [rule], now: Make.epoch)
        let second = engine.evaluate(
            snapshot: Make.snapshot(percentage: 17, at: 600),
            rules: [rule],
            now: Make.epoch.addingTimeInterval(600)
        )
        #expect(second.events.isEmpty)
        #expect(second.suppressions[rule.id] == .alreadyFiredThisGeneration)
    }

    @Test("refires once the repetition interval elapses")
    func intervalRefires() {
        var engine = AlertEngine()
        let rule = Make.rule(repetition: .interval(300))
        _ = engine.evaluate(snapshot: Make.snapshot(percentage: 18), rules: [rule], now: Make.epoch)

        let early = engine.evaluate(
            snapshot: Make.snapshot(percentage: 18, at: 120),
            rules: [rule],
            now: Make.epoch.addingTimeInterval(120)
        )
        #expect(early.events.isEmpty)

        let late = engine.evaluate(
            snapshot: Make.snapshot(percentage: 18, at: 400),
            rules: [rule],
            now: Make.epoch.addingTimeInterval(400)
        )
        #expect(late.events.count == 1)
    }

    @Test("untilConditionChanges fires on every evaluation while armed")
    func untilConditionChanges() {
        var engine = AlertEngine()
        let rule = Make.rule(repetition: .untilConditionChanges)
        _ = engine.evaluate(snapshot: Make.snapshot(percentage: 18), rules: [rule], now: Make.epoch)
        let second = engine.evaluate(
            snapshot: Make.snapshot(percentage: 17, at: 10),
            rules: [rule],
            now: Make.epoch.addingTimeInterval(10)
        )
        #expect(second.events.count == 1)
    }

    @Test("release margin prevents boundary flapping")
    func releaseMargin() {
        var engine = AlertEngine()
        let rule = Make.rule(repetition: .once, margin: 3)
        _ = engine.evaluate(snapshot: Make.snapshot(percentage: 20), rules: [rule], now: Make.epoch)

        // 22 is above the threshold but inside the margin: still latched.
        _ = engine.evaluate(
            snapshot: Make.snapshot(percentage: 22, at: 60),
            rules: [rule],
            now: Make.epoch.addingTimeInterval(60)
        )
        #expect(engine.latch(for: rule.id).isArmed)

        // 23 clears the margin and releases.
        _ = engine.evaluate(
            snapshot: Make.snapshot(percentage: 23, at: 120),
            rules: [rule],
            now: Make.epoch.addingTimeInterval(120)
        )
        #expect(engine.latch(for: rule.id) == .clear)

        // Re-entry is a new generation and alerts again.
        let reentry = engine.evaluate(
            snapshot: Make.snapshot(percentage: 19, at: 180),
            rules: [rule],
            now: Make.epoch.addingTimeInterval(180)
        )
        #expect(reentry.events.count == 1)
        #expect(reentry.events[0].key.generation == 2)
    }

    @Test("reconciling mode arms without firing")
    func reconcileDoesNotFire() {
        var engine = AlertEngine()
        let rule = Make.rule()
        let result = engine.evaluate(
            snapshot: Make.snapshot(percentage: 8),
            rules: [rule],
            now: Make.epoch,
            mode: .reconciling
        )
        #expect(result.events.isEmpty)
        #expect(result.suppressions[rule.id] == .reconcilingAfterRestartOrWake)
        #expect(engine.latch(for: rule.id).isArmed)
    }

    @Test("charging state gates the rule")
    func powerConditionGates() {
        var engine = AlertEngine()
        let rule = Make.rule(power: .onBatteryOnly)
        let onAC = engine.evaluate(
            snapshot: Make.snapshot(percentage: 15, source: .ac, charging: .charging),
            rules: [rule],
            now: Make.epoch
        )
        #expect(onAC.events.isEmpty)
    }

    @Test("a battery jumping past several thresholds arms each rule once")
    func multiThresholdJump() {
        var engine = AlertEngine()
        let low = Make.rule(name: "Low", threshold: 20)
        let critical = Make.rule(name: "Critical", threshold: 10)
        let result = engine.evaluate(
            snapshot: Make.snapshot(percentage: 5),
            rules: [low, critical],
            now: Make.epoch
        )
        #expect(result.events.count == 2)
    }

    @Test("power session identity changes when the power source flips")
    func powerSessionRotates() {
        var engine = AlertEngine()
        let rule = Make.rule(power: .any, repetition: .untilConditionChanges)
        let first = engine.evaluate(snapshot: Make.snapshot(percentage: 15), rules: [rule], now: Make.epoch)
        let second = engine.evaluate(
            snapshot: Make.snapshot(percentage: 15, source: .ac, charging: .charging, at: 60),
            rules: [rule],
            now: Make.epoch.addingTimeInterval(60)
        )
        #expect(first.events[0].key.powerSessionID != second.events[0].key.powerSessionID)
    }

    @Test("a disabled rule never fires and clears its latch")
    func disabledRule() {
        var engine = AlertEngine()
        var rule = Make.rule()
        _ = engine.evaluate(snapshot: Make.snapshot(percentage: 15), rules: [rule], now: Make.epoch)
        rule.isEnabled = false
        let result = engine.evaluate(
            snapshot: Make.snapshot(percentage: 15, at: 60),
            rules: [rule],
            now: Make.epoch.addingTimeInterval(60)
        )
        #expect(result.events.isEmpty)
        #expect(engine.latch(for: rule.id) == .clear)
    }

    @Test("a backwards clock change does not silence a repeating rule")
    func backwardsClock() {
        var engine = AlertEngine()
        let rule = Make.rule(repetition: .interval(600))
        _ = engine.evaluate(snapshot: Make.snapshot(percentage: 18), rules: [rule], now: Make.epoch)
        let rewound = engine.evaluate(
            snapshot: Make.snapshot(percentage: 18, at: -3_600),
            rules: [rule],
            now: Make.epoch.addingTimeInterval(-3_600)
        )
        #expect(rewound.events.count == 1)
    }
}
