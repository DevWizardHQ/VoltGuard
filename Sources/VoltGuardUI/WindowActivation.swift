import AppKit

/// VoltGuard runs as an accessory app so it keeps out of the Dock while it is
/// only a menu bar item. That leaves an open window unreachable: no Dock icon,
/// no ⌘-Tab entry, and no reliable way to bring it back to the front.
///
/// The app therefore becomes a regular app for exactly as long as it has a
/// window on screen, and drops back to accessory when the last one closes.
@MainActor
public enum WindowActivation {
    /// Call immediately before opening a window.
    public static func prepareForWindow() {
        if NSApplication.shared.activationPolicy() != .regular {
            NSApplication.shared.setActivationPolicy(.regular)
        }
    }

    /// Call immediately after opening a window.
    ///
    /// Activation has to happen once the window exists, not before: the
    /// previous order activated the app and only then created the window, so
    /// the window arrived un-keyed behind whatever the user was working in.
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

    /// Ordinary windows only. The status item and the menu it opens are
    /// windows too, and they must not keep the Dock icon alive.
    private static func presentedWindows() -> [NSWindow] {
        NSApplication.shared.windows.filter { window in
            window.isVisible && window.canBecomeMain && !window.isExcludedFromWindowsMenu
        }
    }
}
