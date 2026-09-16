import Foundation

public enum SamplingPolicy {
    public static func shouldRecord(
        previous: BatterySnapshot?,
        current: BatterySnapshot,
        maxGap: TimeInterval
    ) -> Bool {
        guard let previous else { return true }
        if previous.combinedPercentage != current.combinedPercentage { return true }
        if previous.chargingState != current.chargingState { return true }
        if previous.powerSource != current.powerSource { return true }
        return current.timestamp.timeIntervalSince(previous.timestamp) >= maxGap
    }

    /// A plug or unplug must be acted on immediately; everything else waits for
    /// the configured interval so IOKit's per-percent notifications cannot
    /// turn into per-percent evaluations.
    public static func shouldEvaluate(
        trigger: TickTrigger,
        previous: BatterySnapshot?,
        current: BatterySnapshot,
        lastEvaluation: Date?,
        interval: TimeInterval
    ) -> Bool {
        if trigger == .manual || trigger == .wake { return true }
        if let previous {
            if previous.powerSource != current.powerSource { return true }
            if previous.chargingState != current.chargingState { return true }
        }
        guard let lastEvaluation else { return true }
        let elapsed = current.timestamp.timeIntervalSince(lastEvaluation)
        return elapsed < 0 || elapsed >= interval
    }
}
