import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VoltGuardCore
import VoltGuardStore

struct HistoryTab: View {
    @Environment(AppState.self) private var state
    @State private var format: ExportFormat = .csv
    @State private var rangeSelection = 1
    @State private var customStart = Date().addingTimeInterval(-7 * 86_400)
    @State private var customEnd = Date()
    @State private var sampleCount = 0
    @State private var confirmation: Confirmation?

    private enum Confirmation: Identifiable {
        case deleteAll
        case deleteOlder

        var id: Int {
            switch self {
            case .deleteAll: 0
            case .deleteOlder: 1
            }
        }
    }

    var body: some View {
        @Bindable var state = state

        Form {
            Section("Retention") {
                Picker("Keep history for", selection: $state.settings.retention) {
                    ForEach(RetentionPolicy.allCases) { Text($0.displayName).tag($0) }
                }
                LabeledContent("Stored samples", value: "\(sampleCount)")
            }

            Section("Export") {
                Picker("Format", selection: $format) {
                    ForEach(ExportFormat.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Range", selection: $rangeSelection) {
                    Text("All").tag(0)
                    Text("Last 7 days").tag(1)
                    Text("Last 30 days").tag(2)
                    Text("Custom").tag(3)
                }
                if rangeSelection == 3 {
                    DatePicker("From", selection: $customStart, displayedComponents: .date)
                    DatePicker("To", selection: $customEnd, displayedComponents: .date)
                }
                Button("Export…") { Task { await export() } }
            }

            Section("Delete") {
                Button("Export Before Deleting…") { Task { await exportThenPrune() } }
                Button("Delete Older Than Retention…") { confirmation = .deleteOlder }
                Button("Delete All History…", role: .destructive) { confirmation = .deleteAll }
            }
        }
        .formStyle(.grouped)
        .task { await refreshCount() }
        .alert(item: $confirmation) { item in
            switch item {
            case .deleteAll:
                Alert(
                    title: Text("Delete all battery history?"),
                    message: Text("This cannot be undone. Your settings are not affected."),
                    primaryButton: .destructive(Text("Delete")) { Task { await deleteAll() } },
                    secondaryButton: .cancel()
                )
            case .deleteOlder:
                Alert(
                    title: Text("Delete history older than \(state.settings.retention.displayName)?"),
                    message: Text("This cannot be undone. Export first if you want to keep it."),
                    primaryButton: .destructive(Text("Delete")) { Task { await prune() } },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var exportRange: ExportRange {
        switch rangeSelection {
        case 0: .all
        case 2: .lastDays(30)
        case 3: .custom(customStart, customEnd)
        default: .lastDays(7)
        }
    }

    /// The delete only runs once the export file exists on disk; a cancelled
    /// or failed export must not take the history with it.
    private func exportThenPrune() async {
        guard let url = await export() else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        await prune()
    }

    @discardableResult
    private func export() async -> URL? {
        guard let store = state.history else { return nil }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "voltguard-history.\(format.fileExtension)"
        panel.allowedContentTypes = [UTType(filenameExtension: format.fileExtension) ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        let exporter = HistoryExporter(store: store)
        do {
            try await exporter.export(format: format, range: exportRange, to: url)
            return url
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
    }

    private func deleteAll() async {
        guard let store = state.history else { return }
        try? await store.deleteAll()
        await refreshCount()
    }

    private func prune() async {
        await state.pruneHistory()
        await refreshCount()
    }

    private func refreshCount() async {
        guard let store = state.history else { return }
        sampleCount = (try? await store.count()) ?? 0
    }
}
