import AppKit
import Observation

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let state: AppState
    private let openSettings: () -> Void
    private var item: NSStatusItem?

    init(state: AppState, openSettings: @escaping () -> Void) {
        self.state = state
        self.openSettings = openSettings
        super.init()
        refresh()
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = state.settings.showMenuBarIcon
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.observe()
            }
        }
    }

    private func refresh() {
        if state.settings.showMenuBarIcon {
            guard item == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = Self.icon()
            item.button?.toolTip = "Arrowslit"
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            self.item = item
        } else if let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let open = NSMenuItem(title: "Open Arrowslit", action: #selector(openAction), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        if state.timer.isActive {
            let remaining = ClockFormat.clock(state.timer.remaining, roundingUp: true)
            let pause = NSMenuItem(
                title: state.timer.isPaused ? "Resume Timer · \(remaining)" : "Pause Timer · \(remaining)",
                action: #selector(toggleTimerAction),
                keyEquivalent: ""
            )
            pause.target = self
            menu.addItem(pause)
            let reset = NSMenuItem(title: "Stop Timer", action: #selector(resetTimerAction), keyEquivalent: "")
            reset.target = self
            menu.addItem(reset)
        } else {
            let start = NSMenuItem(title: "Start Timer", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for minutes in [5, 10, 25, 50] {
                let entry = NSMenuItem(
                    title: ClockFormat.presetLabel(minutes: minutes),
                    action: #selector(startTimerAction(_:)),
                    keyEquivalent: ""
                )
                entry.tag = minutes
                entry.target = self
                submenu.addItem(entry)
            }
            start.submenu = submenu
            menu.addItem(start)
        }

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(settingsAction), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "Quit Arrowslit", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func openAction() { state.expandDefault() }
    @objc private func toggleTimerAction() { state.toggleTimer() }
    @objc private func resetTimerAction() { state.resetTimer() }
    @objc private func startTimerAction(_ sender: NSMenuItem) { state.startTimer(minutes: sender.tag) }
    @objc private func settingsAction() { openSettings() }
    @objc private func quitAction() { NSApp.terminate(nil) }

    private static func icon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.white.setFill()
            let slit = NSBezierPath(
                roundedRect: NSRect(x: 7.75, y: 4.5, width: 2.5, height: 11.5),
                xRadius: 1.25,
                yRadius: 1.25
            )
            slit.fill()
            let base = NSBezierPath(
                roundedRect: NSRect(x: 4, y: 2, width: 10, height: 2.5),
                xRadius: 1.25,
                yRadius: 1.25
            )
            base.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
