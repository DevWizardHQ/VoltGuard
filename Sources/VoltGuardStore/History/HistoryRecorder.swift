import Foundation
import VoltGuardCore

public struct HistoryRecorder: HistoryRecording {
    private let store: HistoryStore
    private let onError: @Sendable (Error) -> Void

    public init(store: HistoryStore, onError: @escaping @Sendable (Error) -> Void = { _ in }) {
        self.store = store
        self.onError = onError
    }

    public func record(snapshot: BatterySnapshot, monitoringState: MonitoringStateKind) async {
        do {
            try await store.insert(snapshot: snapshot, monitoringState: monitoringState)
        } catch {
            onError(error)
        }
    }

    public func record(delivery: AlertDelivery) async {
        do {
            try await store.insert(delivery: delivery)
        } catch {
            onError(error)
        }
    }
}
