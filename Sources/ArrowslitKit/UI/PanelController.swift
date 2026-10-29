import AppKit
import Observation
import QuartzCore
import SwiftUI

@MainActor
final class PanelController {
    private let state: AppState
    private let panel = ArrowslitPanel()
    private let hostingView: NSHostingView<ArrowslitRootView>
    private var screenObserver: NSObjectProtocol?
    private var mouseMonitor: Any?
    private var keyMonitor: Any?

    init(state: AppState) {
        self.state = state
        hostingView = NSHostingView(rootView: ArrowslitRootView(state: state))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.setAccessibilityLabel("Arrowslit")
        panel.orderFrontRegardless()
        updateFrame(animated: false)
        observe()
        observeScreens()
        installMonitors()
    }

    func tearDown() {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        panel.orderOut(nil)
    }

    private func observe() {
        withObservationTracking {
            _ = state.isExpanded
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateFrame(animated: true)
                self?.observe()
            }
        }

        withObservationTracking {
            _ = state.activeTab
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.keyboardFocus()
                self?.observe()
            }
        }
    }

    private func observeScreens() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateFrame(animated: false)
                self?.panel.orderFrontRegardless()
            }
        }
    }

    private func installMonitors() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state.isExpanded else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) {
                    self.state.collapse()
                }
            }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            MainActor.assumeIsolated {
                if event.keyCode == 53, self?.state.isExpanded == true {
                    self?.state.collapse()
                    return nil
                }
                return event
            }
        }
    }

    private func updateFrame(animated: Bool) {
        guard let screen = ScreenReader.builtIn() else { return }
        let geometry = ScreenReader.geometry(for: screen)
        let width: CGFloat = state.isExpanded ? 720 : 360
        let height: CGFloat = state.isExpanded ? 420 : 36
        let x = (screen.frame.minX + geometry.centreX - width / 2).rounded()
        let y = screen.frame.maxY - height
        let frame = NSRect(x: x, y: y, width: width, height: height)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
        keyboardFocus()
    }

    private func keyboardFocus() {
        if state.isExpanded, state.activeTab == .notes {
            panel.acceptsKeyboard = true
            panel.makeKey()
        } else {
            if panel.isKeyWindow { panel.resignKey() }
            panel.acceptsKeyboard = false
        }
    }
}

private final class ArrowslitPanel: NSPanel {
    var acceptsKeyboard = false

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
