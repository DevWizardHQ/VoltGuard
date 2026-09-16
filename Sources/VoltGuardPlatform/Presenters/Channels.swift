import Foundation
import VoltGuardCore

public protocol NotificationPresenting: Sendable {
    func requestAuthorization() async -> Bool
    func present(_ event: AlertEvent, soundName: String?) async -> ChannelOutcome
}

public protocol SoundPlaying: Sendable {
    func play(named: String?, customPath: String?) async -> ChannelOutcome
    func preview(named: String?, customPath: String?) async -> ChannelOutcome
}

public protocol SpeechPresenting: Sendable {
    func speak(_ text: String, configuration: VoiceConfiguration) async -> ChannelOutcome
    func availableVoices() -> [SystemVoice]
}

public protocol DialogPresenting: Sendable {
    func present(_ event: AlertEvent) async -> ChannelOutcome
}

public struct SystemVoice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let language: String

    public init(id: String, name: String, language: String) {
        self.id = id
        self.name = name
        self.language = language
    }
}
