import Foundation
import VoltGuardCore

public struct AppSettings: Codable, Equatable, Sendable {
    public var monitoring: MonitoringConfiguration
    public var rules: [AlertRule]
    public var schedule: MonitoringSchedule
    public var voice: VoiceConfiguration
    public var sound: SoundConfiguration
    public var theme: AppearanceTheme
    public var accentColorHex: String?
    public var retention: RetentionPolicy
    public var launchAtLogin: Bool
    public var showPercentageInMenuBar: Bool
    public var updateChannel: UpdateChannel
    public var automaticUpdateChecks: Bool
    public var debugLogging: Bool
    public var hasCompletedOnboarding: Bool

    public static let defaults = AppSettings(
        monitoring: DefaultConfiguration.monitoring,
        rules: DefaultConfiguration.rules,
        schedule: DefaultConfiguration.schedule,
        voice: DefaultConfiguration.voice,
        sound: DefaultConfiguration.sound,
        theme: DefaultConfiguration.theme,
        accentColorHex: nil,
        retention: DefaultConfiguration.retention,
        launchAtLogin: DefaultConfiguration.launchAtLogin,
        showPercentageInMenuBar: DefaultConfiguration.showPercentageInMenuBar,
        updateChannel: DefaultConfiguration.updateChannel,
        automaticUpdateChecks: DefaultConfiguration.automaticUpdateChecks,
        debugLogging: false,
        hasCompletedOnboarding: false
    )

    /// True when any enabled rule can actually post a notification, so the
    /// permission prompt is only raised for someone who will see one.
    public var usesNotifications: Bool {
        rules.contains { $0.isEnabled && $0.channels.contains(.notification) }
    }

    public var engineConfiguration: EngineConfiguration {
        EngineConfiguration(monitoring: monitoring, rules: rules, schedule: schedule)
    }
}

public protocol SettingsPersisting: AnyObject, Sendable {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
    func loadLatches() -> [UUID: RuleLatch]
    func saveLatches(_ latches: [UUID: RuleLatch])
}

public final class SettingsStore: SettingsPersisting, @unchecked Sendable {
    private let defaults: UserDefaults
    private let settingsKey = "settings.v1"
    private let latchKey = "latches.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard
            let data = defaults.data(forKey: settingsKey),
            let decoded = try? decoder.decode(AppSettings.self, from: data)
        else { return .defaults }
        return decoded
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }

    public func loadLatches() -> [UUID: RuleLatch] {
        guard
            let data = defaults.data(forKey: latchKey),
            let decoded = try? decoder.decode([String: RuleLatch].self, from: data)
        else { return [:] }
        return decoded.reduce(into: [:]) { result, pair in
            if let id = UUID(uuidString: pair.key) { result[id] = pair.value }
        }
    }

    public func saveLatches(_ latches: [UUID: RuleLatch]) {
        let encodable = latches.reduce(into: [String: RuleLatch]()) { $0[$1.key.uuidString] = $1.value }
        guard let data = try? encoder.encode(encodable) else { return }
        defaults.set(data, forKey: latchKey)
    }

    public func reset() {
        defaults.removeObject(forKey: settingsKey)
        defaults.removeObject(forKey: latchKey)
    }
}
