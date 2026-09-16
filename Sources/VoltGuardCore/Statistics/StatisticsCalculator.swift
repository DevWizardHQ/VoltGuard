import Foundation

public enum StatisticsCalculator {
    /// Sums the gaps between consecutive samples, attributing each gap to the
    /// earlier sample's state. Gaps are clamped so a machine asleep for days
    /// does not register days of discharging.
    public static func durations(
        samples: [BatteryHistoryEntry],
        maxGap: TimeInterval
    ) -> (charging: TimeInterval, discharging: TimeInterval) {
        guard samples.count > 1 else { return (0, 0) }
        let clamp = maxGap * 1.5
        var charging: TimeInterval = 0
        var discharging: TimeInterval = 0

        for (earlier, later) in zip(samples, samples.dropFirst()) {
            let gap = min(max(later.timestamp.timeIntervalSince(earlier.timestamp), 0), clamp)
            guard earlier.monitoringState == .active else { continue }
            switch earlier.chargingState {
            case .charging: charging += gap
            case .discharging: discharging += gap
            case .full, .notCharging, .unknown: break
            }
        }
        return (charging, discharging)
    }

    public static func downsample(_ points: [(Date, Double)], limit: Int = 400) -> [(Date, Double)] {
        guard points.count > limit, limit > 0 else { return points }
        let bucketSize = Int((Double(points.count) / Double(limit)).rounded(.up))
        var result: [(Date, Double)] = []
        result.reserveCapacity(limit)

        var index = 0
        while index < points.count {
            let slice = points[index..<min(index + bucketSize, points.count)]
            let averageValue = slice.reduce(0.0) { $0 + $1.1 } / Double(slice.count)
            let midpoint = slice[slice.startIndex + slice.count / 2].0
            result.append((midpoint, averageValue))
            index += bucketSize
        }
        return result
    }
}
