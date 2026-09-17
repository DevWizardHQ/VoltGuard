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
                name: "Critical",
                threshold: 15,
                direction: .low,
                powerCondition: .onBatteryOnly,
                channels: [.notification, .sound, .voice],
                message:
                    "Battery is {battery} please connect your device to a power source immediately to avoid shutdown.",
                repetition: .interval(300)
            ),
            AlertRule(
                name: "Low",
                threshold: 25,
                direction: .low,
                powerCondition: .onBatteryOnly,
                message: "Battery is {battery} please connect your device to a power source soon."
            ),
            AlertRule(
                name: "Charging Warning",
                threshold: 80,
                direction: .high,
                powerCondition: .onACOnly,
                message:
                    "Battery is {battery} please disconnect your device from the power source to avoid overcharging."
            ),
            AlertRule(
                name: "Full",
                threshold: 100,
                direction: .high,
                powerCondition: .onACOnly,
                message:
                    "Battery is {battery} your device is fully charged and can be disconnected from the power source.",
                repetition: .once
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
