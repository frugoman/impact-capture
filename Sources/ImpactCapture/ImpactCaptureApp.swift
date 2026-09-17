import AppKit
import ImpactCaptureCore
import SwiftUI

@main
struct ImpactCaptureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Everything lives in the status item popover and branded windows.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusBar: StatusBarController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if SnapshotRenderer.runIfRequested() {
            NSApp.terminate(nil)
            return
        }
        #endif
        statusBar = StatusBarController(model: model)
        model.start()
    }

    /// Opening the app again (Finder, Spotlight, Raycast) shows the popover instead of doing nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model.settings.hasCompletedOnboarding {
            statusBar?.showPopover()
        } else {
            model.showOnboarding()
        }
        return false
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard
            let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
            let url = URL(string: string),
            let command = URLCommand(url: url)
        else { return }
        model.handle(command)
    }
}

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()

    init(model: AppModel) {
        self.model = model
        super.init()

        item.button?.image = MenuBarIcon.image
        item.button?.setAccessibilityLabel("Impact Capture")
        item.button?.target = self
        item.button?.action = #selector(togglePopover)

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(model: model, close: { [weak self] in self?.popover.performClose(nil) })
        )
    }

    func showPopover() {
        guard let button = item.button, !popover.isShown else { return }
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }
}
