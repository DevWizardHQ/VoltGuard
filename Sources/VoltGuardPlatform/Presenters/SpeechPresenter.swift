import AVFoundation
import VoltGuardCore

public final class SpeechPresenter: SpeechPresenting, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public func availableVoices() -> [SystemVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .map { SystemVoice(id: $0.identifier, name: $0.name, language: $0.language) }
            .sorted { $0.name < $1.name }
    }

    public func speak(_ text: String, configuration: VoiceConfiguration) async -> ChannelOutcome {
        let utterance = AVSpeechUtterance(string: text)
        utterance.volume = configuration.volume
        utterance.rate =
            AVSpeechUtteranceMinimumSpeechRate
            + (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * configuration.rate

        if let identifier = configuration.voiceIdentifier {
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                utterance.voice = voice
            } else {
                // An uninstalled voice falls back rather than failing the alert.
                Log.warning(.alerts, "Voice \(identifier) unavailable; using the system default")
            }
        }

        synthesizer.speak(utterance)
        return .delivered
    }
}
