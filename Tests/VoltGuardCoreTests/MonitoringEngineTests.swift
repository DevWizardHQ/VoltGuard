import Foundation
import Testing

@testable import VoltGuardCore

@Suite("Monitoring engine")
struct MonitoringEngineTests {
    private func makeEngine(
        snapshots: [BatterySnapshot],
        configuration: EngineConfiguration = EngineConfiguration(rules: [Make.rule()])
    ) -> (MonitoringEngine, RecordingDispatcher, RecordingRecorder) {
        let dispatcher = RecordingDispatcher()
        let recorder = RecordingRecorder()
        let engine = MonitoringEngine(
            clock: FakeClock(now: Make.epoch),
            reader: ScriptedPowerSource(snapshots),
            recorder: recorder,
            dispatcher: dispatcher,
            configuration: configuration
        )
        return (engine, dispatcher, recorder)
    }

    @Test("a desktop Mac stops monitoring instead of polling")
    func desktopMac() async {
        let (engine, dispatcher, _) = makeEngine(snapshots: [Make.snapshot(percentage: nil)])
        await engine.tick(trigger: .manual)
        #expect(await engine.currentStatus().state == .noBatteryMac)
        #expect(await dispatcher.recorded().isEmpty)
    }

    @Test("the first tick reconciles rather than alerting")
    func firstTickReconciles() async {
        let (engine, dispatcher, _) = makeEngine(snapshots: [Make.snapshot(percentage: 8)])
        await engine.tick(trigger: .manual)
        #expect(await dispatcher.recorded().isEmpty)
    }

    @Test("a threshold entered after reconciling alerts")
    func alertsAfterReconcile() async {
        let (engine, dispatcher, _) = makeEngine(snapshots: [
            Make.snapshot(percentage: 60),
            Make.snapshot(percentage: 15, at: 700),
        ])
        await engine.tick(trigger: .manual)
        await engine.tick(trigger: .manual)
        #expect(await dispatcher.recorded().count == 1)
    }

    @Test("a paused engine neither samples nor alerts")
    func pausedIsSilent() async {
        let (engine, dispatcher, recorder) = makeEngine(snapshots: [
            Make.snapshot(percentage: 60),
            Make.snapshot(percentage: 5, at: 700),
        ])
        await engine.tick(trigger: .manual)
        let baseline = await recorder.sampleCount()
        await engine.setPaused(true)
        await engine.tick(trigger: .manual)

        #expect(await engine.currentStatus().state == .pausedByUser)
        #expect(await dispatcher.recorded().isEmpty)
        #expect(await recorder.sampleCount() == baseline + 1)  // the paused sample itself
    }

    @Test("a read failure degrades without stopping the engine")
    func degradedOnFailure() async {
        let dispatcher = RecordingDispatcher()
        let recorder = RecordingRecorder()
        let engine = MonitoringEngine(
            clock: FakeClock(now: Make.epoch),
            reader: ScriptedPowerSource(results: [
                .failure(.unavailable("no power sources")),
                .success(Make.snapshot(percentage: 55, at: 60)),
            ]),
            recorder: recorder,
            dispatcher: dispatcher
        )
        await engine.tick(trigger: .manual)
        #expect(await engine.currentStatus().state == .degraded)

        await engine.tick(trigger: .manual)
        #expect(await engine.currentStatus().state == .active)
    }

    @Test("outside the schedule nothing is evaluated")
    func outsideSchedule() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let window = ScheduleWindow(
            name: "Never",
            weekdays: [],
            startMinuteOfDay: 0,
            endMinuteOfDay: 1
        )
        let configuration = EngineConfiguration(
            rules: [Make.rule()],
            schedule: MonitoringSchedule(
                isEnabled: true,
                windows: [
                    ScheduleWindow(
                        name: "Work",
                        weekdays: [.monday],
                        startMinuteOfDay: window.startMinuteOfDay,
                        endMinuteOfDay: 60
                    )
                ])
        )
        let dispatcher = RecordingDispatcher()
        let engine = MonitoringEngine(
            clock: FakeClock(now: Make.epoch),
            reader: ScriptedPowerSource([Make.snapshot(percentage: 5)]),
            recorder: RecordingRecorder(),
            dispatcher: dispatcher,
            configuration: configuration
        )
        await engine.tick(trigger: .manual)
        #expect(await engine.currentStatus().state == .outsideSchedule)
        #expect(await dispatcher.recorded().isEmpty)
    }

    @Test("waking does not replay an alert the user already saw")
    func wakeDoesNotReplay() async {
        let (engine, dispatcher, _) = makeEngine(snapshots: [
            Make.snapshot(percentage: 60),
            Make.snapshot(percentage: 15, at: 700),
            Make.snapshot(percentage: 15, at: 4_000),
        ])
        await engine.tick(trigger: .manual)
        await engine.tick(trigger: .manual)
        #expect(await dispatcher.recorded().count == 1)

        await engine.systemWillSleep()
        await engine.systemDidWake()
        #expect(await dispatcher.recorded().count == 1)
    }

    @Test("samples are recorded only when something changed")
    func samplingIsSparse() async {
        let (engine, _, recorder) = makeEngine(snapshots: [
            Make.snapshot(percentage: 50),
            Make.snapshot(percentage: 50, at: 60),
            Make.snapshot(percentage: 49, at: 120),
        ])
        await engine.tick(trigger: .manual)
        await engine.tick(trigger: .manual)
        await engine.tick(trigger: .manual)
        #expect(await recorder.sampleCount() == 2)
    }
}
