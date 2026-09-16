import Foundation
import UserNotifications
import VoltGuardCore

public final class NotificationPresenter: NotificationPresenting, @unchecked Sendable {
    private let center: UNUserNotificationCenter?

    public init() {
        // Bundle-less runs (tests, `swift run`) have no notification center and
        // would trap inside UserNotifications rather than return an error.
        center = Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    public func authorizationStatus() async -> NotificationAuthorization {
        guard let center else { return .unavailable }
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        @unknown default: return .unavailable
        }
    }

    public func requestAuthorization() async -> Bool {
        guard let center else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // The usual cause is a copy that macOS does not treat as an
            // installed app: run from a disk image, from Downloads under App
            // Translocation, or never registered with Launch Services.
            Log.warning(
                .alerts,
                "Notification authorization failed: \(error.localizedDescription) — running from \(Bundle.main.bundlePath)"
            )
            return false
        }
    }

    public func present(_ event: AlertEvent, soundName: String?) async -> ChannelOutcome {
        guard let center else { return .failed(.presentationFailed("no notification center")) }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        else {
            return .failed(.permissionDenied)
        }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.interruptionLevel =
            event.rule.direction == .low && event.rule.threshold <= 10
            ? .timeSensitive
            : .active
        if let soundName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        }

        let request = UNNotificationRequest(
            identifier: event.id.uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            return .delivered
        } catch {
            return .failed(.presentationFailed(error.localizedDescription))
        }
    }
}
