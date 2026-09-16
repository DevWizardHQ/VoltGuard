import Foundation
import Testing

@testable import VoltGuardCore

@Suite("Schedule")
struct ScheduleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: iso)!
    }

    @Test("a disabled schedule is always active")
    func disabledIsAlwaysActive() {
        let schedule = MonitoringSchedule(isEnabled: false, windows: [])
        #expect(schedule.isActive(at: date("2026-09-16T03:00:00Z"), calendar: calendar))
    }

    @Test("a weekday window matches inside its hours only")
    func weekdayWindow() {
        // 2026-09-16 is a Wednesday.
        let window = ScheduleWindow(
            name: "Work",
            weekdays: Weekday.weekdays,
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 18 * 60
        )
        let schedule = MonitoringSchedule(isEnabled: true, windows: [window])
        #expect(schedule.isActive(at: date("2026-09-16T10:00:00Z"), calendar: calendar))
        #expect(!schedule.isActive(at: date("2026-09-16T20:00:00Z"), calendar: calendar))
        #expect(!schedule.isActive(at: date("2026-09-19T10:00:00Z"), calendar: calendar))  // Saturday
    }

    @Test("an overnight window crosses midnight and belongs to its start day")
    func overnightWindow() {
        // Friday 22:00 → 07:00 Saturday.
        let window = ScheduleWindow(
            name: "Night",
            weekdays: [.friday],
            startMinuteOfDay: 22 * 60,
            endMinuteOfDay: 7 * 60
        )
        let schedule = MonitoringSchedule(isEnabled: true, windows: [window])
        #expect(schedule.isActive(at: date("2026-09-18T23:00:00Z"), calendar: calendar))  // Fri night
        #expect(schedule.isActive(at: date("2026-09-19T03:00:00Z"), calendar: calendar))  // Sat morning
        #expect(!schedule.isActive(at: date("2026-09-19T23:00:00Z"), calendar: calendar))  // Sat night
    }

    @Test("an end exactly at the boundary is excluded")
    func exclusiveEnd() {
        let window = ScheduleWindow(
            name: "Work",
            weekdays: Weekday.all,
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 18 * 60
        )
        let schedule = MonitoringSchedule(isEnabled: true, windows: [window])
        #expect(schedule.isActive(at: date("2026-09-16T09:00:00Z"), calendar: calendar))
        #expect(!schedule.isActive(at: date("2026-09-16T18:00:00Z"), calendar: calendar))
    }

    @Test("an enabled schedule with no usable windows stays active rather than going silent")
    func emptyWindowsFailOpen() {
        let schedule = MonitoringSchedule(isEnabled: true, windows: [])
        #expect(schedule.isActive(at: date("2026-09-16T10:00:00Z"), calendar: calendar))
    }
}

@Suite("Sampling policy")
struct SamplingPolicyTests {
    @Test("the first sample is always recorded")
    func firstSample() {
        #expect(
            SamplingPolicy.shouldRecord(
                previous: nil,
                current: Make.snapshot(percentage: 50),
                maxGap: 1_800
            ))
    }

    @Test("an unchanged reading inside the gap is not recorded")
    func unchangedIsSkipped() {
        #expect(
            !SamplingPolicy.shouldRecord(
                previous: Make.snapshot(percentage: 50),
                current: Make.snapshot(percentage: 50, at: 300),
                maxGap: 1_800
            ))
    }

    @Test("the max gap forces a sample even with no change")
    func gapForcesSample() {
        #expect(
            SamplingPolicy.shouldRecord(
                previous: Make.snapshot(percentage: 50),
                current: Make.snapshot(percentage: 50, at: 1_900),
                maxGap: 1_800
            ))
    }

    @Test("a power source change forces immediate evaluation")
    func powerChangeForcesEvaluation() {
        #expect(
            SamplingPolicy.shouldEvaluate(
                trigger: .powerSourceChanged,
                previous: Make.snapshot(percentage: 50, source: .battery),
                current: Make.snapshot(percentage: 50, source: .ac, charging: .charging, at: 10),
                lastEvaluation: Make.epoch,
                interval: 600
            ))
    }

    @Test("a percentage-only change waits for the interval")
    func percentageChangeWaits() {
        #expect(
            !SamplingPolicy.shouldEvaluate(
                trigger: .powerSourceChanged,
                previous: Make.snapshot(percentage: 50),
                current: Make.snapshot(percentage: 49, at: 10),
                lastEvaluation: Make.epoch,
                interval: 600
            ))
    }
}

@Suite("Statistics")
struct StatisticsTests {
    private func entry(
        _ offset: TimeInterval, _ state: ChargingState, _ monitoring: MonitoringStateKind = .active
    ) -> BatteryHistoryEntry {
        BatteryHistoryEntry(
            id: Int64(offset),
            timestamp: Make.epoch.addingTimeInterval(offset),
            percentage: 50,
            chargingState: state,
            powerSource: state == .charging ? .ac : .battery,
            monitoringState: monitoring
        )
    }

    @Test("durations attribute each gap to the earlier sample")
    func durationAttribution() {
        let durations = StatisticsCalculator.durations(
            samples: [entry(0, .charging), entry(600, .discharging), entry(1_200, .discharging)],
            maxGap: 1_800
        )
        #expect(durations.charging == 600)
        #expect(durations.discharging == 600)
    }

    @Test("a long sleep gap is clamped")
    func clampedGap() {
        let durations = StatisticsCalculator.durations(
            samples: [entry(0, .discharging), entry(3 * 86_400, .discharging)],
            maxGap: 1_800
        )
        #expect(durations.discharging == 2_700)
    }

    @Test("paused stretches contribute nothing")
    func pausedIsExcluded() {
        let durations = StatisticsCalculator.durations(
            samples: [entry(0, .discharging, .pausedByUser), entry(600, .discharging)],
            maxGap: 1_800
        )
        #expect(durations.discharging == 0)
    }

    @Test("downsampling caps the point count")
    func downsampling() {
        let points = (0..<5_000).map { (Make.epoch.addingTimeInterval(Double($0)), Double($0 % 100)) }
        #expect(StatisticsCalculator.downsample(points, limit: 400).count <= 400)
    }

    @Test("a series under the limit is untouched")
    func downsampleNoop() {
        let points = (0..<10).map { (Make.epoch.addingTimeInterval(Double($0)), Double($0)) }
        #expect(StatisticsCalculator.downsample(points, limit: 400).count == 10)
    }
}
