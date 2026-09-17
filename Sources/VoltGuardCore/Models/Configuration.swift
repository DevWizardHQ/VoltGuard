import Foundation

public enum MonitoringStateKind: Int, Codable, Sendable, CaseIterable {
    case active
    case pausedByUser
    case outsideSchedule
    case systemAsleep
    case degraded
    case noBatteryMac

    public var displayName: String {
        switch self {
        case .active: "Active"
        case .pausedByUser: "Paused"
        case .outsideSchedule: "Outside schedule"
        case .systemAsleep: "Asleep"
        case .degraded: "Unavailable"
        case .noBatteryMac: "No battery"
        }
    }

    public var evaluatesRules: Bool { self == .active }
}

public struct MonitoringConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var interval: TimeInterval
    public var maxSampleGap: TimeInterval
    public var alertsGloballyEnabled: Bool

    public static let intervalPresets: [TimeInterval] = [60, 120, 300, 600, 900, 1800, 3600]

    public init(
        isEnabled: Bool = true,
        interval: TimeInterval = 600,
        maxSampleGap: TimeInterval = 1800,
        alertsGloballyEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.interval = max(interval, 30)
        self.maxSampleGap = max(maxSampleGap, interval)
        self.alertsGloballyEnabled = alertsGloballyEnabled
    }
}

public struct VoiceConfiguration: Codable, Equatable, Sendable {
    public var voiceIdentifier: String?
    /// 0...1, mapped onto the speech synthesiser's own rate range.
    public var rate: Float
    /// 0...1.
    public var volume: Float
    /// 0.5...2.0, where 1.0 is the voice's natural pitch.
    public var pitch: Float

    public init(
        voiceIdentifier: String? = nil,
        rate: Float = 0.5,
        volume: Float = 1.0,
        pitch: Float = 1.0
    ) {
        self.voiceIdentifier = voiceIdentifier
        self.rate = min(max(rate, 0), 1)
        self.volume = min(max(volume, 0), 1)
        self.pitch = min(max(pitch, 0.5), 2)
    }

    /// Pitch arrived after the first release, so settings saved without it must
    /// still decode rather than resetting every preference to its default.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            voiceIdentifier: try container.decodeIfPresent(String.self, forKey: .voiceIdentifier),
            rate: try container.decodeIfPresent(Float.self, forKey: .rate) ?? 0.5,
            volume: try container.decodeIfPresent(Float.self, forKey: .volume) ?? 1.0,
            pitch: try container.decodeIfPresent(Float.self, forKey: .pitch) ?? 1.0
        )
    }
}

public struct SoundConfiguration: Codable, Equatable, Sendable {
    public var defaultSoundName: String?
    public var customSoundPath: String?

    public init(defaultSoundName: String? = "Submarine", customSoundPath: String? = nil) {
        self.defaultSoundName = defaultSoundName
        self.customSoundPath = customSoundPath
    }
}

public enum AppearanceTheme: String, Codable, Sendable, CaseIterable, Identifiable {
    case system, light, dark
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public enum RetentionPolicy: Int, Codable, Sendable, CaseIterable, Identifiable {
    case days7 = 7
    case days30 = 30
    case days90 = 90
    case days365 = 365
    case forever = 0

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .days7: "7 days"
        case .days30: "30 days"
        case .days90: "90 days"
        case .days365: "1 year"
        case .forever: "Forever"
        }
    }

    public func cutoff(now: Date) -> Date? {
        guard self != .forever else { return nil }
        return now.addingTimeInterval(-Double(rawValue) * 86_400)
    }
}

public enum UpdateChannel: String, Codable, Sendable, CaseIterable, Identifiable {
    case stable, beta
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}
