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
    private var hoverTimer: Timer?
    private var hoverStartedAt: Date?
    private var leaveStartedAt: Date?
    private var lastExpandedState = false

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
        startHoverPolling()
    }

    func tearDown() {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        hoverTimer?.invalidate()
        hoverTimer = nil
        panel.orderOut(nil)
    }

    /// One observation loop. The previous version re-installed two separate
    /// trackings every time either property changed, which leaked observers
    /// until the main thread spent all its time walking them.
    private func observe() {
        withObservationTracking {
            _ = state.isExpanded
            _ = state.activeTab
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                await Task.yield()
                guard let self else { return }
                let expandedChanged = self.state.isExpanded != self.lastExpandedState
                self.lastExpandedState = self.state.isExpanded
                if expandedChanged {
                    self.updateFrame(animated: true)
                } else {
                    self.keyboardFocus()
                }
                self.observe()
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

    private func startHoverPolling() {
        let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPointer() }
        }
        timer.tolerance = 0.04
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func pollPointer() {
        guard let screen = ScreenReader.builtIn() else { return }
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame

        if state.isExpanded {
            hoverStartedAt = nil
            guard state.settings.collapseOnLeave,
                  NSEvent.pressedMouseButtons == 0,
                  !NSApp.isActive else {
                leaveStartedAt = nil
                return
            }
            if frame.insetBy(dx: -8, dy: -8).contains(mouse) {
                leaveStartedAt = nil
            } else if let started = leaveStartedAt {
                if Date().timeIntervalSince(started) > 0.45 {
                    leaveStartedAt = nil
                    DispatchQueue.main.async { [weak self] in
                        self?.state.collapse()
                    }
                }
            } else {
                leaveStartedAt = Date()
            }
        } else {
            leaveStartedAt = nil
            guard state.settings.openOnHover else {
                hoverStartedAt = nil
                return
            }
            let zone = frame.insetBy(dx: 0, dy: -3)
            if zone.contains(mouse), screen.frame.contains(mouse) {
                if let started = hoverStartedAt {
                    if Date().timeIntervalSince(started) >= 0.4 {
                        hoverStartedAt = nil
                        DispatchQueue.main.async { [weak self] in
                            self?.state.expand(.home)
                        }
                    }
                } else {
                    hoverStartedAt = Date()
                }
            } else {
                hoverStartedAt = nil
            }
        }
    }

    private func installMonitors() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state.isExpanded else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) {
                    DispatchQueue.main.async { [weak self] in
                        self?.state.collapse()
                    }
                }
            }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor [weak self] in self?.state.collapse() }
                return nil
            }
            return event
        }
    }

    private func updateFrame(animated: Bool) {
        guard let screen = ScreenReader.builtIn() else { return }
        let geometry = ScreenReader.geometry(for: screen)
        let width: CGFloat = state.isExpanded ? 560 : geometry.compactWidth
        let height: CGFloat = state.isExpanded ? 178 : 32
        let x = (screen.frame.minX + geometry.centreX - width / 2).rounded()
        let y = screen.frame.maxY - height
        let frame = NSRect(x: x, y: y, width: width, height: height)
        if animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
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
