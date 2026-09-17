import Foundation
import VoltGuardCore

public enum NotificationAuthorization: Sendable, Equatable {
    /// macOS has never asked; requesting will show the prompt.
    case notDetermined
    /// The user said no. Requesting again does nothing — only System Settings
    /// can undo it.
    case denied
    case authorized
    case provisional
    /// No notification centre: an unbundled or unregistered copy.
    case unavailable

    public var canDeliver: Bool { self == .authorized || self == .provisional }
}

public protocol NotificationPresenting: Sendable {
    func authorizationStatus() async -> NotificationAuthorization
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
    public let quality: String
    /// Apple's natural Siri voices, which sound markedly better than the rest.
    public let isSiri: Bool

    public init(id: String, name: String, language: String, quality: String, isSiri: Bool) {
        self.id = id
        self.name = name
        self.language = language
        self.quality = quality
        self.isSiri = isSiri
    }

    public var displayName: String {
        quality == "Default" ? "\(name) — \(language)" : "\(name) (\(quality)) — \(language)"
    }
}
