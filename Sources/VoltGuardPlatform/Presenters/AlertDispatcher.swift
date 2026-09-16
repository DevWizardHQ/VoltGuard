import Foundation
import VoltGuardCore

public struct DispatcherConfiguration: Sendable {
    public var sound: SoundConfiguration
    public var voice: VoiceConfiguration

    public init(sound: SoundConfiguration, voice: VoiceConfiguration) {
        self.sound = sound
        self.voice = voice
    }
}

public actor AlertDispatcher: AlertDelivering {
    private let notifications: any NotificationPresenting
    private let sounds: any SoundPlaying
    private let speech: any SpeechPresenting
    private let dialogs: any DialogPresenting

    private var configuration: DispatcherConfiguration
    private var lastDelivered: [AlertChannel: AlertEventKey] = [:]

    public init(
        notifications: any NotificationPresenting,
        sounds: any SoundPlaying,
        speech: any SpeechPresenting,
        dialogs: any DialogPresenting,
        configuration: DispatcherConfiguration
    ) {
        self.notifications = notifications
        self.sounds = sounds
        self.speech = speech
        self.dialogs = dialogs
        self.configuration = configuration
    }

    public func apply(configuration newValue: DispatcherConfiguration) {
        configuration = newValue
    }

    public func deliver(_ event: AlertEvent) async -> [AlertChannel: ChannelOutcome] {
        var outcomes: [AlertChannel: ChannelOutcome] = [:]
        let channels = event.rule.channels

        let soundName = event.rule.soundName ?? configuration.sound.defaultSoundName
        let customPath = event.rule.soundName == nil ? configuration.sound.customSoundPath : nil

        // A notification carries the sound itself, so enabling both channels
        // must not produce two sounds for one alert.
        let soundRidesOnNotification =
            channels.contains(.notification)
            && channels.contains(.sound)
            && customPath == nil

        if channels.contains(.notification), !isDuplicate(.notification, event.key) {
            let outcome = await notifications.present(
                event,
                soundName: soundRidesOnNotification ? soundName : nil
            )
            outcomes[.notification] = outcome
            if outcome == .delivered { markDelivered(.notification, event.key) }
        }

        if channels.contains(.sound), !isDuplicate(.sound, event.key) {
            let notificationDelivered = outcomes[.notification] == .delivered
            if soundRidesOnNotification && notificationDelivered {
                outcomes[.sound] = .delivered
                markDelivered(.sound, event.key)
            } else {
                let outcome = await sounds.play(named: soundName, customPath: customPath)
                outcomes[.sound] = outcome
                if outcome == .delivered { markDelivered(.sound, event.key) }
            }
        }

        if channels.contains(.voice), !isDuplicate(.voice, event.key) {
            let outcome = await speech.speak(event.body, configuration: configuration.voice)
            outcomes[.voice] = outcome
            if outcome == .delivered { markDelivered(.voice, event.key) }
        }

        if channels.contains(.dialog), !isDuplicate(.dialog, event.key) {
            let outcome = await dialogs.present(event)
            outcomes[.dialog] = outcome
            if outcome == .delivered { markDelivered(.dialog, event.key) }
        }

        for channel in channels where outcomes[channel] == nil {
            outcomes[channel] = .suppressed(.alreadyFiredThisGeneration)
        }

        Log.info(
            .alerts,
            "Alert \(event.rule.name) delivered: \(outcomes.keys.map(\.rawValue).joined(separator: ","))")
        return outcomes
    }

    private func isDuplicate(_ channel: AlertChannel, _ key: AlertEventKey) -> Bool {
        lastDelivered[channel] == key
    }

    private func markDelivered(_ channel: AlertChannel, _ key: AlertEventKey) {
        lastDelivered[channel] = key
    }
}
