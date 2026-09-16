import Foundation
import IOKit.ps
import VoltGuardCore

/// Bridges IOKit's power-source run loop source into an async stream so the
/// engine reacts to plug and unplug without polling for them.
public final class PowerSourceMonitor: @unchecked Sendable {
    private var runLoopSource: CFRunLoopSource?
    private var handler: (@Sendable () -> Void)?

    public init() {}

    public func start(onChange: @escaping @Sendable () -> Void) {
        guard runLoopSource == nil else { return }
        handler = onChange

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard
            let source = IOPSNotificationCreateRunLoopSource(
                { pointer in
                    guard let pointer else { return }
                    let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(pointer).takeUnretainedValue()
                    monitor.handler?()
                }, context)?.takeRetainedValue()
        else {
            Log.warning(.monitoring, "IOPSNotificationCreateRunLoopSource failed; falling back to timer only")
            return
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    public func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
        runLoopSource = nil
        handler = nil
    }

    deinit { stop() }
}
