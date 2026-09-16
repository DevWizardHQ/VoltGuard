import SwiftUI

public struct SettingsView: View {
    public init() {}

    public var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            AlertsTab().tabItem { Label("Alerts", systemImage: "bell") }
            ScheduleTab().tabItem { Label("Schedule", systemImage: "calendar") }
            VoiceSoundTab().tabItem { Label("Voice & Sound", systemImage: "speaker.wave.2") }
            HistoryTab().tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            AppearanceTab().tabItem { Label("Appearance", systemImage: "paintbrush") }
            AdvancedTab().tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
            AboutTab().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(minWidth: 640, minHeight: 520)
    }
}
