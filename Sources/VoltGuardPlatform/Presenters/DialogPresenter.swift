import AppKit
import VoltGuardCore

public final class DialogPresenter: DialogPresenting, @unchecked Sendable {
    private let isPresenting = OSAllocatedLock()

    public init() {}

    public func present(_ event: AlertEvent) async -> ChannelOutcome {
        // Only one dialog at a time; a second event loses the dialog channel
        // rather than stacking modal windows over the user's work.
        guard isPresenting.tryAcquire() else {
            return .suppressed(.dialogAlreadyPresented)
        }

        let outcome = await MainActor.run { () -> ChannelOutcome in
            let alert = NSAlert()
            alert.messageText = event.title
            alert.informativeText = event.body
            alert.alertStyle = event.rule.direction == .low ? .critical : .informational
            alert.addButton(withTitle: "Dismiss")

            NSApplication.shared.activate(ignoringOtherApps: true)
            NSAccessibility.post(
                element: NSApplication.shared as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: "\(event.title). \(event.body)",
                    .priority: NSAccessibilityPriorityLevel.high.rawValue,
                ]
            )

            alert.runModal()
            return .delivered
        }

        isPresenting.release()
        return outcome
    }
}

final class OSAllocatedLock: @unchecked Sendable {
    private let lock = NSLock()
    private var isHeld = false

    func tryAcquire() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isHeld else { return false }
        isHeld = true
        return true
    }

    func release() {
        lock.lock()
        isHeld = false
        lock.unlock()
    }
}
