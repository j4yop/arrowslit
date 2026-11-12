import AppKit
import SwiftUI

@MainActor
final class CommandCenterWindowController {
    private let state: AppState
    private let clipboardShelf: ClipboardShelfWindowController
    private let capture: CaptureController
    private var window: NSWindow?
    private var resignObserver: NSObjectProtocol?
    private var keyMonitor: Any?

    init(state: AppState) {
        self.state = state
        self.clipboardShelf = ClipboardShelfWindowController(state: state)
        self.capture = CaptureController(state: state)
    }

    var isVisible: Bool { window?.isVisible == true }

    func showClipboardShelf() {
        close()
        clipboardShelf.show()
    }

    func startCapture(_ mode: CaptureMode) {
        close()
        capture.start(mode)
    }

    func toggle() {
        if isVisible { close() } else { show() }
    }

    func show(startTab: CommandCenterTab = .home) {
        close()
        guard let screen = ScreenReader.screen(for: state.settings.displayChoice) ?? NSScreen.main else { return }
        state.collapse()
        let width: CGFloat = 352
        let height: CGFloat = 576
        let mouse = NSEvent.mouseLocation
        let nearMenuBar = mouse.y > screen.frame.maxY - 56
        let proposedX = nearMenuBar ? mouse.x - width / 2 : screen.visibleFrame.maxX - width - 12
        let x = min(max(proposedX, screen.frame.minX + 8), screen.frame.maxX - width - 8)
        let frame = NSRect(
            x: x,
            y: max(screen.visibleFrame.minY + 8, screen.frame.maxY - height - 38),
            width: width,
            height: height
        )
        let panel = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.contentView = NSHostingView(rootView: CommandCenterView(
            state: state,
            startTab: startTab,
            onClose: { [weak self] in self?.close() },
            onOpenClipboard: { [weak self] in
                self?.close()
                self?.clipboardShelf.show()
            },
            onCapture: { [weak self] mode in
                self?.close()
                self?.capture.start(mode)
            }
        ))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        window = panel

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.close() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.close()
                return nil
            }
            return event
        }
    }

    func close() {
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver); self.resignObserver = nil }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        window?.orderOut(nil)
        window = nil
    }
}
