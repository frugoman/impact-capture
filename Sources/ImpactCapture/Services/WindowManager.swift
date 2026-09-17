import AppKit
import SwiftUI

/// Opens branded standalone windows (setup, settings, export) for this menu bar app.
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    private var windows: [String: NSWindow] = [:]

    func show<Content: View>(id: String, size: NSSize, @ViewBuilder content: () -> Content) {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier(id)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(Brand.background)
        window.contentView = NSHostingView(rootView: content())
        window.delegate = self
        window.center()
        windows[id] = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close(id: String) {
        windows[id]?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let id = (notification.object as? NSWindow)?.identifier?.rawValue else { return }
        windows[id] = nil
    }
}
