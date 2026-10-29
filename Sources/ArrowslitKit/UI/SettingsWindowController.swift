import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        state.collapse()
        let window = window ?? makeWindow()
        if !window.isVisible, let screen = NSScreen.main {
            let size = window.frame.size
            let origin = NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            )
            window.setFrameOrigin(origin)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 620),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Arrowslit Settings"
        window.contentViewController = NSHostingController(rootView: SettingsView(state: state))
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(ArrowTheme.ink)
        self.window = window
        return window
    }
}
