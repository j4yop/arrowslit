import AppKit
import CoreGraphics
import Observation
import QuartzCore
import SwiftUI

@MainActor
final class PanelController {
    private let state: AppState
    private let panel = ArrowslitPanel()
    private let fixedScreen: NSScreen?
    private let role: PanelRole
    private var screen: NSScreen?
    private let hostingView: TrackingHostingView<ArrowslitRootView>
    /// Called when the pointer reaches a mirror panel, so the manager can make it active.
    var onActivate: (() -> Void)?

    var currentScreenID: String? {
        guard let screen else { return nil }
        if let uuid = ScreenReader.uuid(for: screen) { return uuid }
        let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        return "display:\(number)"
    }
    private var screenObserver: NSObjectProtocol?
    private var mouseMonitor: Any?
    private var pointerMonitor: Any?
    private var keyMonitor: Any?
    private var hoverOpenTimer: Timer?
    private var leaveTimer: Timer?
    private var fallbackTimer: Timer?
    private var hoverStartedAt: Date?
    private var leaveStartedAt: Date?
    /// After a deliberate close (Escape or auto-collapse), do not immediately reopen just
    /// because the pointer is still resting on the notch.
    private var suppressHover = false

    /// The presentation this panel draws. Mirrors keep the compact strip while content is
    /// open on the active display, but they still show alerts and HUDs.
    private var displayPresentation: NotchPresentation {
        role.isActive ? state.presentation : state.mirrorPresentation
    }

    private var standardLevel: NSWindow.Level {
        NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
    }

    private var lockScreenLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
    }

    init(state: AppState, fixedScreen: NSScreen? = nil, isActive: Bool = true) {
        self.state = state
        self.fixedScreen = fixedScreen
        role = PanelRole(isActive: isActive)
        screen = fixedScreen ?? ScreenReader.screen(for: state.settings.displayChoice)
        ScreenReader.activeScreen = screen
        hostingView = TrackingHostingView(rootView: ArrowslitRootView(state: state, screen: screen, role: role))
        hostingView.sizingOptions = []
        hostingView.onPointerChanged = { [weak self] in self?.pollPointer() }
        panel.contentView = hostingView
        panel.setAccessibilityLabel("Arrowslit")
        panel.orderFrontRegardless()
        applyLockScreenState()
        updateFrame(animated: false)
        // LaunchServices can finish activating the app after the panel is ordered front; give
        // the window one more compact strip so the closed notch is visible immediately on launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.panel.orderFrontRegardless()
        }
        observe()
        observeScreens()
        installMonitors()
        startPointerWatching()
    }

    func tearDown() {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        if let pointerMonitor { NSEvent.removeMonitor(pointerMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        hoverOpenTimer?.invalidate()
        hoverOpenTimer = nil
        leaveTimer?.invalidate()
        leaveTimer = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        panel.orderOut(nil)
    }

    /// One observation loop. The previous version re-installed two separate
    /// trackings every time either property changed, which leaked observers
    /// until the main thread spent all its time walking them.
    private func observe() {
        withObservationTracking {
            _ = state.presentation
            _ = state.session.isLocked
            _ = state.settings.showOnLockScreen
            _ = state.settings.appearance
            _ = state.settings.displayChoice
            _ = state.isSearchingClipboard
            _ = state.isTypingInNook
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                await Task.yield()
                guard let self else { return }
                self.applyLockScreenState()
                self.updateFrame(animated: true)
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
                self?.refreshScreen()
                self?.updateFrame(animated: false)
                self?.panel.orderFrontRegardless()
            }
        }
    }

    private func applyLockScreenState() {
        let locked = state.session.isLocked
        let show = state.settings.showOnLockScreen

        if locked {
            if state.isExpanded { state.collapse() }
            panel.ignoresMouseEvents = true
            if show {
                panel.level = lockScreenLevel
                panel.orderFrontRegardless()
            } else {
                panel.orderOut(nil)
                panel.level = standardLevel
            }
        } else {
            // An alert can be clicked on any screen; opened content only exists on the active one.
            panel.ignoresMouseEvents = !(role.isActive || displayPresentation.isAlert)
            panel.level = standardLevel
            panel.orderFrontRegardless()
        }
    }

    /// Switches this panel between the active window and a mirror. Only the active panel
    /// accepts the pointer and keyboard; the others keep drawing the compact state.
    func setActive(_ active: Bool) {
        guard role.isActive != active else { return }
        role.isActive = active
        applyLockScreenState()
        updateFrame(animated: false)
        keyboardFocus()
    }

    /// Hover is driven by pointer events, not a repeating timer. The tracking area covers the
    /// panel itself; the global monitor catches the pointer moving toward a mirror on another
    /// screen. A slow fallback exists only when macOS has not granted Accessibility, because
    /// global mouse events are unavailable there.
    private func startPointerWatching() {
        pointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPointer() }
        }
        if pointerMonitor == nil || !AXIsProcessTrusted() {
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.pollPointer() }
            }
            timer.tolerance = 0.2
            RunLoop.main.add(timer, forMode: .common)
            fallbackTimer = timer
        }
    }

    private func scheduleHoverOpen() {
        guard hoverOpenTimer == nil else { return }
        let delay = state.settings.hoverDelay
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.hoverOpenTimer = nil
                guard self.role.isActive, !self.state.isExpanded,
                      self.panel.frame.insetBy(dx: -8, dy: -8).contains(NSEvent.mouseLocation) else { return }
                self.state.expandDefault()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverOpenTimer = timer
    }

    private func scheduleLeaveCheck() {
        guard leaveTimer == nil else { return }
        let timer = Timer(timeInterval: 0.45, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.leaveTimer = nil
                guard self.role.isActive, self.state.isExpanded,
                      self.state.settings.collapseOnLeave,
                      NSEvent.pressedMouseButtons == 0,
                      !NSApp.isActive,
                      !self.panel.frame.insetBy(dx: -8, dy: -8).contains(NSEvent.mouseLocation) else { return }
                // The pointer is already away, so this is not a deliberate close: do not
                // leave the notch suppressed until a second leave happens.
                self.state.collapse()
                self.state.clearHoverSuppression()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        leaveTimer = timer
    }

    private func pollPointer() {
        guard !state.session.isLocked else {
            hoverStartedAt = nil
            leaveStartedAt = nil
            return
        }
        guard let screen = currentScreen() else { return }
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame

        if !role.isActive {
            // Reaching a mirror's notch makes that display the one in use. The next poll runs
            // the normal hover/reveal logic there.
            if frame.insetBy(dx: -8, dy: -8).contains(mouse) {
                onActivate?()
            }
            return
        }

        if displayPresentation.isAlert {
            hoverStartedAt = nil
            leaveStartedAt = nil
            hoverOpenTimer?.invalidate()
            hoverOpenTimer = nil
            leaveTimer?.invalidate()
            leaveTimer = nil
            state.setHoveringNotch(false)
            return
        }

        if state.isExpanded {
            hoverStartedAt = nil
            hoverOpenTimer?.invalidate()
            hoverOpenTimer = nil
            state.setHoveringNotch(false)
            guard state.settings.collapseOnLeave,
                  NSEvent.pressedMouseButtons == 0,
                  !NSApp.isActive else {
                leaveStartedAt = nil
                leaveTimer?.invalidate()
                leaveTimer = nil
                return
            }
            if frame.insetBy(dx: -8, dy: -8).contains(mouse) {
                leaveStartedAt = nil
                leaveTimer?.invalidate()
                leaveTimer = nil
            } else {
                if leaveStartedAt == nil { leaveStartedAt = Date() }
                scheduleLeaveCheck()
            }
        } else {
            leaveStartedAt = nil
            leaveTimer?.invalidate()
            leaveTimer = nil
            // The pointer resting exactly on the top edge has y == screen.maxY, which
            // CGRect.contains excludes; inset by -1 so the notch edge still counts.
            let onScreen = screen.frame.insetBy(dx: -1, dy: -1).contains(mouse)
            let hovering = frame.insetBy(dx: -8, dy: -8).contains(mouse) && onScreen

            if state.suppressHoverUntilLeave {
                state.setHoveringNotch(false)
                if !hovering { state.clearHoverSuppression() }
                hoverStartedAt = nil
                hoverOpenTimer?.invalidate()
                hoverOpenTimer = nil
                return
            }

            state.setHoveringNotch(hovering)

            if suppressHover {
                if !hovering { suppressHover = false }
                hoverStartedAt = nil
                hoverOpenTimer?.invalidate()
                hoverOpenTimer = nil
                return
            }

            guard state.settings.openOnHover else {
                hoverStartedAt = nil
                hoverOpenTimer?.invalidate()
                hoverOpenTimer = nil
                return
            }
            if hovering {
                if hoverOpenTimer == nil, hoverStartedAt == nil {
                    hoverStartedAt = Date()
                    scheduleHoverOpen()
                }
            } else {
                hoverStartedAt = nil
                hoverOpenTimer?.invalidate()
                hoverOpenTimer = nil
            }
        }
    }

    private func installMonitors() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard self.role.isActive, !self.state.session.isLocked else { return }
                guard self.state.isExpanded || self.state.currentAlert != nil else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) {
                    DispatchQueue.main.async { [weak self] in
                        self?.state.outsideClick()
                    }
                }
            }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, self.role.isActive else { return event }
            if event.keyCode == 53 {
                Task { @MainActor [weak self] in
                    self?.suppressHover = true
                    self?.state.outsideClick()
                }
                return nil
            }
            return event
        }
    }

    private func currentScreen() -> NSScreen? {
        if let fixedScreen { return fixedScreen }
        if state.settings.displayChoice == .followPointer,
           state.presentation.isAlert == false,
           state.isExpanded == false {
            let pointer = NSEvent.mouseLocation
            if let underPointer = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }),
               underPointer !== screen {
                screen = underPointer
                ScreenReader.activeScreen = underPointer
            }
        }
        return screen ?? ScreenReader.screen(for: state.settings.displayChoice)
    }

    private func refreshScreen() {
        guard fixedScreen == nil else { return }
        guard let next = ScreenReader.screen(for: state.settings.displayChoice) else { return }
        guard next !== screen else { return }
        screen = next
        ScreenReader.activeScreen = next
        updateFrame(animated: false)
        panel.orderFrontRegardless()
    }

    private func updateFrame(animated: Bool) {
        if fixedScreen == nil,
           state.settings.displayChoice != .followPointer,
           let next = ScreenReader.screen(for: state.settings.displayChoice),
           next !== screen {
            screen = next
            ScreenReader.activeScreen = next
        }
        guard let screen = currentScreen() else { return }
        let geometry = ScreenReader.geometry(for: screen)
        if role.isActive { ScreenReader.activeScreen = screen }
        let presentation = displayPresentation
        let size = state.panelSize(for: presentation, geometry: geometry)
        let anchorWidth = state.panelAnchorWidth(for: presentation, geometry: geometry)
        let x = (screen.frame.minX + geometry.centreX - anchorWidth / 2).rounded()
        let y = screen.frame.maxY - size.height
        let frame = NSRect(x: x, y: y, width: size.width, height: size.height)
        // A HUD replaces the compact strip at the same moment. Animating its
        // resize leaves the old strip visible in the growing window for a
        // frame or two, so the feedback appears only after the swap.
        let isHUD = presentation.hudAlert != nil
        if animated, !isHUD,
           state.settings.liquidAnimations,
           !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
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
        guard role.isActive else {
            if panel.isKeyWindow { panel.resignKey() }
            panel.acceptsKeyboard = false
            return
        }
        let wantsKeyboard = state.isExpanded
            && (state.activeTab == .notes
                || (state.activeTab == .clipboard && state.isSearchingClipboard)
                || (state.activeTab == .home
                    && state.settings.appearance.nookLayout == .elongated
                    && state.isTypingInNook))
        // Elongated Home has inline Notes and to-dos. Accept the keyboard so a click can focus
        // a field, but don't take it from the app you were in until that click happens.
        let mayType = state.isExpanded
            && state.activeTab == .home
            && state.settings.appearance.nookLayout == .elongated
        if wantsKeyboard {
            panel.acceptsKeyboard = true
            panel.makeKey()
        } else if mayType {
            panel.acceptsKeyboard = true
        } else {
            if panel.isKeyWindow { panel.resignKey() }
            panel.acceptsKeyboard = false
        }
    }
}

/// NSHostingView that reports pointer movement and enter/exit even while the app is inactive.
private final class TrackingHostingView<Content: View>: NSHostingView<Content> {
    var onPointerChanged: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onPointerChanged?()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onPointerChanged?()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onPointerChanged?()
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

    /// A click in the elongated Home must reach the text field even though the app is in the
    /// background. Making the panel key here avoids activating the whole app.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, acceptsKeyboard, !isKeyWindow {
            makeKey()
        }
        super.sendEvent(event)
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
