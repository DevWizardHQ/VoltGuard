import AVFoundation
import Foundation

/// Chooses which installed voice to speak with.
///
/// The preferred default is Apple's natural Siri voice — "Voice 4" and its
/// siblings — which is markedly better than the older synthesisers. It only
/// exists once the user has downloaded it, so the identifier is never
/// hard-coded: it is resolved against what is actually installed, and falls
/// back through the best remaining option to the system default.
public enum VoiceCatalog {
    public static func installed() -> [SystemVoice] {
        AVSpeechSynthesisVoice.speechVoices().map { voice in
            SystemVoice(
                id: voice.identifier,
                name: voice.name,
                language: voice.language,
                quality: describe(voice.quality),
                isSiri: voice.identifier.contains("siri")
            )
        }
    }

    /// - Parameter preferred: the user's explicit choice, or nil for automatic.
    /// - Returns: nil when the system default should be used.
    public static func resolve(
        preferred: String?, languageCode: String = Locale.current.identifier
    )
        -> String?
    {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        if let preferred, voices.contains(where: { $0.identifier == preferred }) {
            return preferred
        }

        let language = languageCode.replacingOccurrences(of: "_", with: "-")
        let prefix = String(language.prefix(2))
        let candidates = voices.filter { $0.language.hasPrefix(prefix) }
        guard !candidates.isEmpty else { return nil }

        func best(_ pool: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
            pool.sorted {
                if $0.language == language, $1.language != language { return true }
                if $1.language == language, $0.language != language { return false }
                return $0.quality.rawValue > $1.quality.rawValue
            }.first
        }

        let siri = candidates.filter { $0.identifier.contains("siri") }
        if let choice = best(siri) { return choice.identifier }
        return best(candidates.filter { $0.quality != .default })?.identifier
    }

    /// The name shown beside "Automatic" so the user can see what they will hear.
    public static func resolvedName(preferred: String?) -> String? {
        guard
            let identifier = resolve(preferred: preferred),
            let voice = AVSpeechSynthesisVoice(identifier: identifier)
        else { return nil }
        return voice.name
    }

    private static func describe(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return "Default"
        }
    }
}
