import SwiftUI
import VoltGuardCore

struct AlertsTab: View {
    @Environment(AppState.self) private var state
    @State private var selection: AlertRule.ID?

    var body: some View {
        @Bindable var state = state

        HSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach($state.settings.rules) { $rule in
                        HStack {
                            Toggle("", isOn: $rule.isEnabled)
                                .labelsHidden()
                                .accessibilityLabel("Enable \(rule.name)")
                            VStack(alignment: .leading) {
                                Text(rule.name)
                                Text("\(rule.direction.displayName) · \(rule.threshold)%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(rule.id)
                    }
                }
                Divider()
                HStack {
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
                .padding(6)
            }
            .frame(minWidth: 190)

            Group {
                if let index = state.settings.rules.firstIndex(where: { $0.id == selection }) {
                    RuleEditor(rule: $state.settings.rules[index])
                } else {
                    ContentUnavailableView("Select a rule", systemImage: "bell")
                }
            }
            .frame(minWidth: 320)
        }
        .safeAreaInset(edge: .bottom) {
            if !state.ruleWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(state.ruleWarnings) { warning in
                        Label(warning.message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.yellow.opacity(0.15))
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
                if rule.channels.contains(.dialog) {
                    Toggle("Dialog can be dismissed", isOn: $rule.dialogIsDismissible)
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

                Button("Reset to Default") { rule.message = nil }
                    .disabled(rule.message == nil)
            }
        }
        .formStyle(.grouped)
    }
}
