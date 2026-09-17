import AVFoundation
import VoltGuardCore

public final class SpeechPresenter: SpeechPresenting, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public func availableVoices() -> [SystemVoice] {
        VoiceCatalog.installed().sorted {
            if $0.isSiri != $1.isSiri { return $0.isSiri }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    public func speak(_ text: String, configuration: VoiceConfiguration) async -> ChannelOutcome {
        let utterance = AVSpeechUtterance(string: text)
        utterance.volume = configuration.volume
        utterance.pitchMultiplier = configuration.pitch
        utterance.rate =
            AVSpeechUtteranceMinimumSpeechRate
            + (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * configuration.rate

        // Automatic resolves to the best installed voice — Siri's natural
        // voice when it is there — and an uninstalled explicit choice falls
        // back rather than failing the alert.
        if let identifier = VoiceCatalog.resolve(preferred: configuration.voiceIdentifier) {
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                utterance.voice = voice
            } else {
                Log.warning(.alerts, "Voice \(identifier) unavailable; using the system default")
            }
        }

        synthesizer.speak(utterance)
        return .delivered
    }
}
