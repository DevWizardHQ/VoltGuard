import SwiftUI
import VoltGuardCore

struct AppearanceTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        Form {
            Section("Theme") {
                Picker("Appearance", selection: $state.settings.theme) {
                    ForEach(AppearanceTheme.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.inline)
            }

            Section("Accent Color") {
                Picker(
                    "Accent",
                    selection: Binding(
                        get: { state.settings.accentColorHex ?? "" },
                        set: { state.settings.accentColorHex = $0.isEmpty ? nil : $0 }
                    )
                ) {
                    Text("System").tag("")
                    ForEach(AccentColor.presets, id: \.hex) { preset in
                        Text(preset.name).tag(preset.hex)
                    }
                }
                Button("Reset to Default") { state.settings.accentColorHex = nil }
                    .disabled(state.settings.accentColorHex == nil)
            }

            Section("Menu Bar") {
                Toggle(
                    "Show battery percentage in the menu bar", isOn: $state.settings.showPercentageInMenuBar)
                Text(
                    "The menu bar icon always changes shape with battery state, so status is readable without relying on color."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
