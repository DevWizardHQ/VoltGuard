import AppKit
import SwiftUI
import VoltGuardCore
import VoltGuardPlatform
import VoltGuardStore
import VoltGuardUI

@main
struct VoltGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var state: AppState

    init() {
        let state = Composition.makeAppState()
        _state = State(initialValue: state)

        // Startup touches NSApplication and the login item, neither of which
        // exists yet inside App.init(); this ran there and trapped on a nil
        // NSApp on every launch.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { state.start() }
        }
    }

    var body: some Scene {
        VoltGuardScenes(state: state)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        // Closing the last window gives the Dock icon back up.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { WindowActivation.windowDidClose() }
        }
    }

    /// Clicking the Dock icon with no window open should bring something back
    /// rather than doing nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        return true
    }
}

enum Composition {
    @MainActor
    static func makeAppState() -> AppState {
        let settingsStore = SettingsStore()
        let settings = settingsStore.load()

        let historyStore: HistoryStore?
        do {
            historyStore = try HistoryStore(url: try HistoryStore.defaultURL())
        } catch {
            Log.error(.storage, "History store unavailable: \(error)")
            historyStore = nil
        }

        let recorder: any HistoryRecording =
            historyStore.map {
                HistoryRecorder(store: $0) { error in
                    Log.error(.storage, "History write failed: \(error)")
                }
            } ?? NullRecorder()

        let notifications = NotificationPresenter()
        let sounds = SoundPlayer()
        let speech = SpeechPresenter()
        let dialogs = DialogPresenter()

        let dispatcher = AlertDispatcher(
            notifications: notifications,
            sounds: sounds,
            speech: speech,
            dialogs: dialogs,
            configuration: DispatcherConfiguration(sound: settings.sound, voice: settings.voice)
        )

        let engine = MonitoringEngine(
            reader: IOKitPowerSourceReader(),
            recorder: recorder,
            dispatcher: dispatcher,
            configuration: settings.engineConfiguration,
            latches: settingsStore.loadLatches()
        )

        let updateService: any UpdateService =
            Bundle.main.bundleIdentifier == nil
            ? NoopUpdateService()
            : SparkleUpdateService(
                channel: settings.updateChannel,
                automaticChecks: settings.automaticUpdateChecks
            )

        return AppState(
            settingsStore: settingsStore,
            historyStore: historyStore,
            engine: engine,
            dispatcher: dispatcher,
            notifications: notifications,
            sounds: sounds,
            speech: speech,
            updateService: updateService,
            powerMonitor: PowerSourceMonitor(),
            sleepObserver: SleepWakeObserver()
        )
    }
}

struct NullRecorder: HistoryRecording {
    func record(snapshot: BatterySnapshot, monitoringState: MonitoringStateKind) async {}
    func record(delivery: AlertDelivery) async {}
}
