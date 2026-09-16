import Foundation

public enum Weekday: Int, Codable, Sendable, CaseIterable, Identifiable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public var id: Int { rawValue }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    public var shortName: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    public static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    public static let all: Set<Weekday> = Set(allCases)
}

public struct ScheduleWindow: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var weekdays: Set<Weekday>
    public var startMinuteOfDay: Int
    public var endMinuteOfDay: Int

    public var crossesMidnight: Bool { endMinuteOfDay <= startMinuteOfDay }

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        weekdays: Set<Weekday> = Weekday.all,
        startMinuteOfDay: Int,
        endMinuteOfDay: Int
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.weekdays = weekdays
        self.startMinuteOfDay = min(max(startMinuteOfDay, 0), 1_439)
        self.endMinuteOfDay = min(max(endMinuteOfDay, 0), 1_439)
    }

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        guard isEnabled, !weekdays.isEmpty else { return false }
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard
            let weekdayValue = components.weekday,
            let weekday = Weekday(rawValue: weekdayValue),
            let hour = components.hour,
            let minute = components.minute
        else { return false }

        let minuteOfDay = hour * 60 + minute

        if !crossesMidnight {
            return weekdays.contains(weekday)
                && minuteOfDay >= startMinuteOfDay
                && minuteOfDay < endMinuteOfDay
        }

        // An overnight window belongs to the weekday it started on, so the
        // tail after midnight matches against the previous day.
        if minuteOfDay >= startMinuteOfDay {
            return weekdays.contains(weekday)
        }
        if minuteOfDay < endMinuteOfDay {
            let previous = Weekday(rawValue: weekdayValue == 1 ? 7 : weekdayValue - 1)
            return previous.map(weekdays.contains) ?? false
        }
        return false
    }
}

public struct MonitoringSchedule: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var windows: [ScheduleWindow]

    public init(isEnabled: Bool = false, windows: [ScheduleWindow] = []) {
        self.isEnabled = isEnabled
        self.windows = windows
    }

    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return true }
        let enabled = windows.filter(\.isEnabled)
        guard !enabled.isEmpty else { return true }
        return enabled.contains { $0.contains(date, calendar: calendar) }
    }
}
