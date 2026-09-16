import SwiftUI
import VoltGuardCore

public struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var step = 0

    private static let stepCount = 6

    public init() {}

    public var body: some View {
        @Bindable var state = state

        VStack(alignment: .leading, spacing: 20) {
            content(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                Button("Skip") { finish() }
                Spacer()
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                Button(step == Self.stepCount - 1 ? "Start Monitoring" : "Continue") {
                    if step == Self.stepCount - 1 { finish() } else { step += 1 }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460, height: 340)
    }

    @ViewBuilder
    private func content(state: AppState) -> some View {
        @Bindable var state = state

        switch step {
        case 0:
            VStack(alignment: .leading, spacing: 10) {
                Text("Welcome to VoltGuard").font(.title).bold()
                Text("Monitor your Mac's battery and get notified before it gets too low or stays too high.")
                Text("VoltGuard lives in the menu bar and keeps every sample on this Mac.")
                    .foregroundStyle(.secondary)
            }
        case 1:
            VStack(alignment: .leading, spacing: 14) {
                Text("Battery thresholds").font(.title2).bold()
                ForEach($state.settings.rules) { $rule in
                    if rule.isEnabled || rule.direction == .low {
                        Stepper("\(rule.name): \(rule.threshold)%", value: $rule.threshold, in: 0...100)
                    }
                }
            }
        case 2:
            VStack(alignment: .leading, spacing: 14) {
                Text("How should VoltGuard alert you?").font(.title2).bold()
                ForEach(AlertChannel.allCases) { channel in
                    Toggle(channel.displayName, isOn: channelBinding(channel, state: state))
                }
            }
        case 3:
            VStack(alignment: .leading, spacing: 14) {
                Text("Monitoring interval").font(.title2).bold()
                Picker("Check every", selection: $state.settings.monitoring.interval) {
                    ForEach(MonitoringConfiguration.intervalPresets, id: \.self) { interval in
                        Text("\(Int(interval / 60)) minutes").tag(interval)
                    }
                }
                Text("VoltGuard still reacts instantly when you plug in or unplug.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case 4:
            VStack(alignment: .leading, spacing: 14) {
                Text("Launch at login").font(.title2).bold()
                Toggle("Start VoltGuard when I log in", isOn: $state.settings.launchAtLogin)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                Text("VoltGuard is ready").font(.title).bold()
                Text("You'll find it in the menu bar. Open Settings any time from there.")
            }
        }
    }

    private func channelBinding(_ channel: AlertChannel, state: AppState) -> Binding<Bool> {
        Binding(
            get: { state.settings.rules.contains { $0.channels.contains(channel) } },
            set: { isOn in
                for index in state.settings.rules.indices {
                    if isOn {
                        state.settings.rules[index].channels.insert(channel)
                    } else {
                        state.settings.rules[index].channels.remove(channel)
                    }
                }
            }
        )
    }

    private func finish() {
        state.settings.hasCompletedOnboarding = true
        dismissWindow(id: "onboarding")
    }
}
