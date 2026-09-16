import Foundation
import VoltGuardCore

public protocol UpdateService: AnyObject, Sendable {
    var isUpdaterAvailable: Bool { get }
    var lastCheckDate: Date? { get }
    var channel: UpdateChannel { get set }
    var automaticChecksEnabled: Bool { get set }
    func checkForUpdates()
    func checkInBackground()
}

public final class NoopUpdateService: UpdateService, @unchecked Sendable {
    public var isUpdaterAvailable: Bool { false }
    public var lastCheckDate: Date?
    public var channel: UpdateChannel = .stable
    public var automaticChecksEnabled = false

    public init() {}
    public func checkForUpdates() {}
    public func checkInBackground() {}
}
