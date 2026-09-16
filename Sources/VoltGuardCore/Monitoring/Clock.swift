import Foundation

public protocol VoltGuardClock: Sendable {
    var now: Date { get }
    /// Monotonic seconds since an arbitrary origin; unaffected by clock changes.
    var uptime: TimeInterval { get }
    var calendar: Calendar { get }
}

public struct SystemClock: VoltGuardClock {
    public init() {}
    public var now: Date { Date() }
    public var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }
    public var calendar: Calendar { Calendar.current }
}
