import SwiftUI
import VoltGuardCore

struct AlertsTab: View {
    @Environment(AppState.self) private var state
    @State private var selection: AlertRule.ID?

    var body: some View {
        @Bindable var state = state

        // HSplitView collapses to its children's intrinsic height inside a
        // fixed-size settings window, which left the rule list floating in the
        // middle of the tab with rows clipped.
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach($state.settings.rules) { $rule in
                        HStack(spacing: 8) {
                            Toggle("", isOn: $rule.isEnabled)
                                .labelsHidden()
                                .accessibilityLabel("Enable \(rule.name)")
                            VStack(alignment: .leading, spacing: 1) {
                                Text(rule.name)
                                Text("\(rule.direction.displayName) · \(rule.threshold)%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                        .tag(rule.id)
                    }
                }
                .listStyle(.inset)
                .frame(maxHeight: .infinity)

                Divider()

                HStack(spacing: 2) {
                    Button {
                        let rule = AlertRule(
                            name: "New Rule",
                            threshold: 50,
                            direction: .low,
                            powerCondition: .onBatteryOnly
                        )
                        state.settings.rules.append(rule)
                        selection = rule.id
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add alert rule")

                    Button {
                        guard let selection else { return }
                        state.settings.rules.removeAll { $0.id == selection }
                        self.selection = nil
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(selection == nil)
                    .accessibilityLabel("Remove alert rule")

                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(width: 212)
            .frame(maxHeight: .infinity)

            Divider()

            Group {
                if let index = state.settings.rules.firstIndex(where: { $0.id == selection }) {
                    RuleEditor(rule: $state.settings.rules[index])
                } else {
                    ContentUnavailableView(
                        "Select a rule",
                        systemImage: "bell",
                        description: Text("Pick a rule on the left to change what it does.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !state.ruleWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(state.ruleWarnings) { warning in
                        Label(warning.message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.yellow.opacity(0.15))
                .overlay(alignment: .top) { Divider() }
            }
        }
    }
}

private struct RuleEditor: View {
    @Binding var rule: AlertRule
    @Environment(AppState.self) private var state

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $rule.name)
                Stepper("Threshold: \(rule.threshold)%", value: $rule.threshold, in: 0...100)
                Picker("Direction", selection: $rule.direction) {
                    ForEach(ThresholdDirection.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker("Applies", selection: $rule.powerCondition) {
                    ForEach(PowerCondition.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Stepper(
                    "Release margin: \(rule.releaseMarginPercent)%", value: $rule.releaseMarginPercent,
                    in: 0...20)
            }

            Section("Channels") {
                ForEach(AlertChannel.allCases) { channel in
                    Toggle(
                        channel.displayName,
                        isOn: Binding(
                            get: { rule.channels.contains(channel) },
                            set: { isOn in
                                if isOn {
                                    rule.channels.insert(channel)
                                } else {
                                    rule.channels.remove(channel)
                                }
                            }
                        ))
                }
            }

            Section("Repetition") {
                Picker("Repeat", selection: $rule.repetition) {
                    ForEach(RepetitionPolicy.presets, id: \.self) { Text($0.displayName).tag($0) }
                }
            }

            Section("Message") {
                TextField(
                    "Message",
                    text: Binding(
                        get: { rule.message ?? MessageTemplate.defaultMessage(for: rule) },
                        set: { rule.message = $0 }
                    ),
                    axis: .vertical
                )
                .lineLimit(2...5)

                Text("Variables: \(MessageTemplate.placeholders.joined(separator: "  "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Listen") { state.speak(rule: rule) }
                        .disabled(!rule.channels.contains(.voice))
                    Button("Reset to Default") { rule.message = nil }
                        .disabled(rule.message == nil)
                }
                if !rule.channels.contains(.voice) {
                    Text("Turn on the Voice channel above to hear this message.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
