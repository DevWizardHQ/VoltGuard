import AppKit
import Foundation
import Observation
import SwiftUI
import VoltGuardCore
import VoltGuardPlatform
import VoltGuardStore

@MainActor
@Observable
public final class AppState {
    public private(set) var status: MonitoringStatus
    public private(set) var voices: [SystemVoice] = []
    public private(set) var notificationAuthorization: NotificationAuthorization = .authorized
    public private(set) var ruleWarnings: [RuleWarning] = []
    public private(set) var historyIsAvailable = true

    public var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persistAndApply(previous: oldValue)
        }
    }

    private let settingsStore: SettingsStore
    private let historyStore: HistoryStore?
    private let engine: MonitoringEngine
    private let dispatcher: AlertDispatcher
    private let speech: any SpeechPresenting
    private let sounds: any SoundPlaying
    private let notifications: any NotificationPresenting
    private let powerMonitor: PowerSourceMonitor
    private let sleepObserver: SleepWakeObserver
    private var retentionTask: Task<Void, Never>?
    public let updateService: any UpdateService

    public init(
        settingsStore: SettingsStore,
        historyStore: HistoryStore?,
        engine: MonitoringEngine,
        dispatcher: AlertDispatcher,
        notifications: any NotificationPresenting,
        sounds: any SoundPlaying,
        speech: any SpeechPresenting,
        updateService: any UpdateService,
        powerMonitor: PowerSourceMonitor,
        sleepObserver: SleepWakeObserver
    ) {
        self.settingsStore = settingsStore
        self.historyStore = historyStore
        self.engine = engine
        self.dispatcher = dispatcher
        self.notifications = notifications
        self.sounds = sounds
        self.speech = speech
        self.updateService = updateService
        self.powerMonitor = powerMonitor
        self.sleepObserver = sleepObserver
        self.settings = settingsStore.load()
        self.historyIsAvailable = historyStore != nil
        self.status = MonitoringStatus(state: .active, snapshot: nil, nextCheck: nil)
        self.ruleWarnings = RuleValidator.validate(settings.rules)
    }

    // MARK: - Lifecycle

    public func start() {
        Log.info(
            .system,
            "VoltGuard \(Diagnostics.appVersion) (\(Diagnostics.buildNumber)) starting on \(Diagnostics.modelIdentifier)"
        )
        voices = speech.availableVoices()
        applyTheme()
        FileLogSink.shared.isDebugEnabled = settings.debugLogging
        syncLoginItem()

        refreshNotificationAuthorization(requestIfUnasked: true)

        // The user can grant or revoke notifications in System Settings while
        // VoltGuard is running; without this the menu keeps reporting whatever
        // was true at launch.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshNotificationAuthorization() }
        }

        Task { [weak self] in
            guard let self else { return }
            for await status in await engine.statusStream {
                self.status = status
                self.persistLatches()
            }
        }

        powerMonitor.start { [weak self] in
            Task { await self?.engine.tick(trigger: .powerSourceChanged) }
        }

        sleepObserver.start(
            onSleep: { [weak self] in Task { await self?.engine.systemWillSleep() } },
            onWake: { [weak self] in Task { await self?.engine.systemDidWake() } }
        )

        Task { await engine.start() }
        startRetentionSweep()
        updateService.checkInBackground()
    }

    public func shutDown() {
        retentionTask?.cancel()
        retentionTask = nil
        powerMonitor.stop()
        sleepObserver.stop()
        Task { await engine.stop() }
        persistLatches()
    }

    // MARK: - Commands

    public func togglePause() {
        settings.monitoring.isEnabled.toggle()
    }

    public func toggleAlerts() {
        settings.monitoring.alertsGloballyEnabled.toggle()
    }

    public func checkNow() {
        Task { await engine.tick(trigger: .manual) }
    }

    public func previewSound(named: String?, customPath: String?) {
        Task { _ = await sounds.preview(named: named, customPath: customPath) }
    }

    public func previewVoice() {
        Task {
            _ = await speech.speak(
                "Battery low. Please connect the charger.",
                configuration: settings.voice
            )
        }
    }

    public func resetAllSettings() {
        settingsStore.reset()
        settings = .defaults
    }

    public func openLogs() {
        NSWorkspace.shared.open(FileLogSink.shared.directory)
    }

    public func clearLogs() {
        FileLogSink.shared.clear()
    }

    public func diagnosticReport() -> String {
        Diagnostics.report(configurationSummary: configurationSummary)
    }

    public func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - History

    public var history: HistoryStore? { historyStore }

    /// Retention has to apply to a Mac left running for weeks, not only at
    /// launch, so the sweep repeats daily.
    private func startRetentionSweep() {
        retentionTask?.cancel()
        retentionTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pruneHistory()
                try? await Task.sleep(for: .seconds(86_400))
            }
        }
    }

    public func pruneHistory() async {
        guard let historyStore else { return }
        try? await historyStore.recoverAbandonedSession(
            maxGap: settings.monitoring.maxSampleGap,
            now: Date()
        )
        guard let cutoff = settings.retention.cutoff(now: Date()) else { return }
        _ = try? await historyStore.prune(before: cutoff)
    }

    // MARK: - Private

    private var configurationSummary: String {
        let rules = settings.rules
            .map {
                "  \($0.name): \($0.threshold)% \($0.direction.displayName) \($0.isEnabled ? "on" : "off")"
            }
            .joined(separator: "\n")
        return """
            Monitoring enabled : \(settings.monitoring.isEnabled)
            Interval           : \(Int(settings.monitoring.interval / 60)) min
            Alerts enabled     : \(settings.monitoring.alertsGloballyEnabled)
            Schedule enabled   : \(settings.schedule.isEnabled)
            Retention          : \(settings.retention.displayName)
            Update channel     : \(settings.updateChannel.displayName)
            Rules:
            \(rules)
            """
    }

    private func persistAndApply(previous: AppSettings) {
        settingsStore.save(settings)
        ruleWarnings = RuleValidator.validate(settings.rules)
        FileLogSink.shared.isDebugEnabled = settings.debugLogging

        if settings.theme != previous.theme || settings.accentColorHex != previous.accentColorHex {
            applyTheme()
        }
        if settings.launchAtLogin != previous.launchAtLogin {
            LoginItemManager.setEnabled(settings.launchAtLogin)
        }
        if settings.updateChannel != previous.updateChannel {
            updateService.channel = settings.updateChannel
        }
        if settings.automaticUpdateChecks != previous.automaticUpdateChecks {
            updateService.automaticChecksEnabled = settings.automaticUpdateChecks
        }
        if settings.retention != previous.retention {
            Task { await pruneHistory() }
        }
        if settings.usesNotifications, !previous.usesNotifications {
            refreshNotificationAuthorization(requestIfUnasked: true)
        }

        let engineConfiguration = settings.engineConfiguration
        let dispatcherConfiguration = DispatcherConfiguration(sound: settings.sound, voice: settings.voice)
        Task {
            await dispatcher.apply(configuration: dispatcherConfiguration)
            await engine.apply(configuration: engineConfiguration)
        }
    }

    private func persistLatches() {
        Task { [weak self] in
            guard let self else { return }
            let latches = await engine.latchSnapshot()
            settingsStore.saveLatches(latches)
        }
    }

    /// The user can disable the login item in System Settings, so the stored
    /// preference is reconciled against what SMAppService actually reports.
    private func refreshNotificationAuthorization(requestIfUnasked: Bool = false) {
        Task { [weak self] in
            guard let self else { return }
            var status = await notifications.authorizationStatus()
            if requestIfUnasked, status == .notDetermined, settings.usesNotifications {
                _ = await notifications.requestAuthorization()
                status = await notifications.authorizationStatus()
            }
            self.notificationAuthorization = status
            if status == .denied {
                Log.warning(.alerts, "Notifications are denied for VoltGuard in System Settings")
            }
        }
    }

    private func syncLoginItem() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        LoginItemManager.setEnabled(settings.launchAtLogin)
        let actual = LoginItemManager.isEnabled
        if actual != settings.launchAtLogin {
            settings.launchAtLogin = actual
        }
    }

    private func applyTheme() {
        switch settings.theme {
        case .system: NSApplication.shared.appearance = nil
        case .light: NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark: NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
