import AppKit

/// VoltGuard is an accessory app, so it becomes a regular app for as long as a
/// window is on screen; otherwise that window has no Dock icon or ⌘-Tab entry
/// and cannot be brought back to the front.
@MainActor
public enum WindowActivation {
    /// Call immediately before opening a window.
    public static func prepareForWindow() {
        if NSApplication.shared.activationPolicy() != .regular {
            NSApplication.shared.setActivationPolicy(.regular)
        }
    }

    /// Call immediately after opening a window, never before it exists.
    public static func focusNewestWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            guard let window = presentedWindows().last else { return }
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Call when a window closes; drops the Dock icon once none are left.
    public static func windowDidClose() {
        DispatchQueue.main.async {
            guard presentedWindows().isEmpty else { return }
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    /// Excludes the status item and its menu, which are windows too.
    private static func presentedWindows() -> [NSWindow] {
        NSApplication.shared.windows.filter { window in
            window.isVisible && window.canBecomeMain && !window.isExcludedFromWindowsMenu
        }
    }
}
