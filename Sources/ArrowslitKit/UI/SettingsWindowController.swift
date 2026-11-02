import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let state: AppState
    private var window: NSWindow?
    private var contentHeight: CGFloat = 672

    init(state: AppState) {
        self.state = state
        super.init()
    }

    func show() {
        state.collapse()
        NSApp.setActivationPolicy(.regular)
        let window = window ?? makeWindow()
        if !window.isVisible, let screen = NSScreen.main {
            let size = NSSize(width: 520, height: contentHeight + 32)
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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: contentHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "General"
        window.titleVisibility = .visible
        let root = SettingsView(state: state) { [weak self] title, height in
            guard let self else { return }
            self.window?.title = title
            self.contentHeight = height
            guard let window = self.window, window.isVisible else { return }
            let target = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 520, height: height))
            var frame = window.frame
            frame.origin.y += frame.height - target.height
            frame.size = target.size
            window.setFrame(frame, display: true, animate: true)
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
