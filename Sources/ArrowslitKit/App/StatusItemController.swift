import AppKit
import Observation

@MainActor
final class StatusItemController: NSObject {
    private let state: AppState
    private let openSettings: () -> Void
    private let openCommandCenter: () -> Void
    private var item: NSStatusItem?

    init(state: AppState, openSettings: @escaping () -> Void, openCommandCenter: @escaping () -> Void) {
        self.state = state
        self.openSettings = openSettings
        self.openCommandCenter = openCommandCenter
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
            item.button?.setAccessibilityLabel("Arrowslit")
            item.button?.target = self
            item.button?.action = #selector(statusClicked)
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            self.item = item
        } else if let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp || !state.settings.commandCenterEnabled {
            showMenu()
        } else {
            openCommandCenter()
        }
    }

    private func showMenu() {
        guard let button = item?.button else { return }
        let menu = makeMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 12), in: button)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let command = NSMenuItem(title: "Command Center", action: #selector(commandAction), keyEquivalent: "")
        command.target = self
        menu.addItem(command)
        menu.addItem(.separator())

        let open = NSMenuItem(title: "Open Arrowslit", action: #selector(openAction), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let hide = NSMenuItem(title: "Hide the Notch", action: #selector(hideNotchAction), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)

        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkUpdatesAction), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)
        menu.addItem(.separator())

        let commandSettings = NSMenuItem(title: "Command Center Settings…", action: #selector(commandSettingsAction), keyEquivalent: "")
        commandSettings.target = self
        menu.addItem(commandSettings)

        let layout = NSMenuItem(title: "Choose a Layout…", action: #selector(layoutAction), keyEquivalent: "")
        layout.target = self
        menu.addItem(layout)

        let reset = NSMenuItem(title: "Reset Layout…", action: #selector(resetLayoutAction), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        let settings = NSMenuItem(title: "Settings…", action: #selector(settingsAction), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Arrowslit", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func commandAction() { openCommandCenter() }
    @objc private func hideNotchAction() { state.collapse() }
    @objc private func checkUpdatesAction() { state.updater.check() }
    @objc private func commandSettingsAction() { openSettings() }
    @objc private func layoutAction() { openSettings() }
    @objc private func resetLayoutAction() { state.settings.appearance = .standard }
    @objc private func openAction() {
        // Let the status menu finish tracking and close before opening the notch. Otherwise the
        // same click is seen outside the panel and immediately collapses it.
        DispatchQueue.main.async { [weak self] in self?.state.expandDefault() }
    }
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
