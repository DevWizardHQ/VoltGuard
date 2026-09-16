import AppKit
import VoltGuardCore

public final class SoundPlayer: SoundPlaying, @unchecked Sendable {
    public init() {}

    public func play(named: String?, customPath: String?) async -> ChannelOutcome {
        await MainActor.run { Self.playSound(named: named, customPath: customPath) }
    }

    public func preview(named: String?, customPath: String?) async -> ChannelOutcome {
        await play(named: named, customPath: customPath)
    }

    @MainActor
    private static func playSound(named: String?, customPath: String?) -> ChannelOutcome {
        if let customPath, !customPath.isEmpty {
            if let sound = NSSound(contentsOfFile: customPath, byReference: true) {
                sound.play()
                return .delivered
            }
            // A deleted custom sound must not silence the alert.
            Log.warning(.alerts, "Custom sound missing at \(customPath); using the default")
        }
        if let named, let sound = NSSound(named: named) {
            sound.play()
            return .delivered
        }
        if let fallback = NSSound(named: "Submarine") {
            fallback.play()
            return .delivered
        }
        NSSound.beep()
        return .delivered
    }
}
