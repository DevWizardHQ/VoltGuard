import SwiftUI
import VoltGuardCore

public struct VoltGuardScenes: Scene {
    private let state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environment(state)
        } label: {
            MenuBarLabel(state: state)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(state)
                .tint(AccentColor.color(fromHex: state.settings.accentColorHex))
        }

        WindowGroup(id: MainWindowTab.windowID, for: MainWindowTab.self) { $tab in
            MainWindow(tab: tab ?? .history)
                .environment(state)
                .tint(AccentColor.color(fromHex: state.settings.accentColorHex))
        }
        .defaultSize(width: 760, height: 520)
        .windowResizability(.contentMinSize)

        Window("Welcome to VoltGuard", id: "onboarding") {
            OnboardingView()
                .environment(state)
                .tint(AccentColor.color(fromHex: state.settings.accentColorHex))
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

private struct MenuBarLabel: View {
    let state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let status = state.status
        HStack(spacing: 4) {
            Image(nsImage: StatusIcon.image(for: status))
            if let text = StatusIcon.menuBarText(
                for: status, showPercentage: state.settings.showPercentageInMenuBar)
            {
                Text(text)
            }
        }
        .accessibilityLabel(StatusIcon.accessibilityLabel(for: status))
        .task {
            guard state.needsOnboarding else { return }
            state.onboardingPresented()
            WindowActivation.prepareForWindow()
            openWindow(id: "onboarding")
            WindowActivation.focusNewestWindow()
        }
    }
}
