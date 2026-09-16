import AppKit
import SwiftUI

struct AdvancedTab: View {
    @Environment(AppState.self) private var state
    @State private var diagnostics: String?
    @State private var isConfirmingReset = false

    var body: some View {
        @Bindable var state = state

        Form {
            Section("Logging") {
                Toggle("Enable debug logging", isOn: $state.settings.debugLogging)
                HStack {
                    Button("Open Logs") { state.openLogs() }
                    Button("Clear Logs") { state.clearLogs() }
                }
            }

            Section("Diagnostics") {
                Button("Export Diagnostics…") { diagnostics = state.diagnosticReport() }
                Text(
                    "You review the report before it leaves your Mac. VoltGuard never submits it automatically."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Reset") {
                Button("Reset All Settings…", role: .destructive) { isConfirmingReset = true }
            }
        }
        .formStyle(.grouped)
        .alert("Reset all settings?", isPresented: $isConfirmingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { state.resetAllSettings() }
        } message: {
            Text("This restores every VoltGuard setting to its default. Battery history will not be deleted.")
        }
        .sheet(
            item: Binding(
                get: { diagnostics.map(DiagnosticReport.init) },
                set: { diagnostics = $0?.text }
            )
        ) { report in
            DiagnosticSheet(text: report.text) { diagnostics = nil }
        }
    }
}

private struct DiagnosticReport: Identifiable {
    let text: String
    var id: String { text }
}

private struct DiagnosticSheet: View {
    let text: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review before sharing")
                .font(.headline)
            ScrollView {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 320)

            HStack {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                Button("Save…") { save() }
                Spacer()
                Button("Close", action: onClose).keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 620)
    }

    private func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "voltguard-diagnostics.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
