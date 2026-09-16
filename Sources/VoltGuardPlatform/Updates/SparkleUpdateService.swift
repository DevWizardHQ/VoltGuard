import Foundation
import Sparkle
import VoltGuardCore

/// The only file in the project that imports Sparkle.
public final class SparkleUpdateService: NSObject, UpdateService, SPUUpdaterDelegate, @unchecked Sendable {
    private let controller: SPUStandardUpdaterController
    /// Sparkle's own minimum is honored too; this floor keeps a relaunch loop
    /// from turning into a check on every launch.
    private static let minimumCheckInterval: TimeInterval = 4 * 3_600

    public var channel: UpdateChannel {
        didSet { controller.updater.checkForUpdateInformation() }
    }

    public var automaticChecksEnabled: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    public var lastCheckDate: Date? { controller.updater.lastUpdateCheckDate }

    public var isUpdaterAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    public init(channel: UpdateChannel = .stable, automaticChecks: Bool = true) {
        self.channel = channel
        self.controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        guard isUpdaterAvailable else { return }
        controller.updater.automaticallyChecksForUpdates = automaticChecks
        controller.updater.updateCheckInterval = max(
            controller.updater.updateCheckInterval,
            Self.minimumCheckInterval
        )
        controller.startUpdater()
    }

    public func checkForUpdates() {
        guard isUpdaterAvailable else { return }
        controller.updater.checkForUpdates()
    }

    public func checkInBackground() {
        guard isUpdaterAvailable, automaticChecksEnabled else { return }
        controller.updater.checkForUpdatesInBackground()
    }

    public func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        channel == .beta ? ["beta"] : []
    }
}
