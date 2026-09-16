import AppKit

public final class SleepWakeObserver: @unchecked Sendable {
    private var observers: [NSObjectProtocol] = []

    public init() {}

    public func start(
        onSleep: @escaping @Sendable () -> Void,
        onWake: @escaping @Sendable () -> Void
    ) {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { _ in onSleep() })
        observers.append(
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { _ in onWake() })
    }

    public func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }

    deinit { stop() }
}
