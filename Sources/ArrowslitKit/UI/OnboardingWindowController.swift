import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
        super.init()
    }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        if window == nil {
            let root = OnboardingView(state: state) { [weak self] openedNotch in
                guard let self else { return }
                UserDefaults.standard.set(true, forKey: "arrowslit.onboarding.completed")
                self.close()
                if openedNotch {
                    self.state.expandDefault()
                }
            }
            let hosting = NSHostingView(rootView: root)
            hosting.frame = NSRect(x: 0, y: 0, width: 804, height: 756)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 804, height: 756),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to Arrowslit"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.level = .normal
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.contentView = hosting
            window.delegate = self
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: "arrowslit.onboarding.completed")
        window = nil
    }
}
