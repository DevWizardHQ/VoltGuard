import Foundation

public enum DefaultConfiguration {
    public static let monitoring = MonitoringConfiguration(
        isEnabled: true,
        interval: 600,
        maxSampleGap: 1_800,
        alertsGloballyEnabled: true
    )

    public static let retention = RetentionPolicy.days30
    public static let theme = AppearanceTheme.system
    public static let launchAtLogin = true
    public static let showPercentageInMenuBar = false
    public static let updateChannel = UpdateChannel.stable
    public static let automaticUpdateChecks = true

    public static var rules: [AlertRule] {
        [
            AlertRule(
                name: "Low Warning",
                threshold: 20,
                direction: .low,
                powerCondition: .onBatteryOnly
            ),
            AlertRule(
                name: "Critical Low",
                threshold: 10,
                direction: .low,
                powerCondition: .onBatteryOnly,
                channels: [.notification, .sound, .voice],
                repetition: .interval(300)
            ),
            AlertRule(
                name: "High Warning",
                threshold: 80,
                direction: .high,
                powerCondition: .onACOnly
            ),
            AlertRule(
                name: "Critical High",
                isEnabled: false,
                threshold: 90,
                direction: .high,
                powerCondition: .onACOnly
            ),
        ]
    }

    public static let schedule = MonitoringSchedule(
        isEnabled: false,
        windows: [
            ScheduleWindow(
                name: "Work Hours",
                isEnabled: false,
                weekdays: Weekday.weekdays,
                startMinuteOfDay: 9 * 60,
                endMinuteOfDay: 18 * 60
            )
        ])

    public static let voice = VoiceConfiguration()
    public static let sound = SoundConfiguration()
}
