import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
        super.init()
    }

    func show() {
        state.collapse()
        NSApp.setActivationPolicy(.regular)
        let window = window ?? makeWindow()
        if !window.isVisible, let screen = NSScreen.main {
            let size = NSSize(width: 520, height: 640)
            let origin = NSPoint(
                x: screen.visibleFrame.minX + (screen.visibleFrame.width - size.width) / 2,
                y: screen.visibleFrame.minY + (screen.visibleFrame.height - size.height) / 2
            )
            window.setFrame(NSRect(origin: origin, size: size), display: true)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 608),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "General"
        window.titleVisibility = .visible
        let root = SettingsView(state: state) { [weak self] title in
            self?.window?.title = title
        }
        window.contentViewController = NSHostingController(rootView: root)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(ArrowTheme.ink)
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
