import AppKit
import Observation

/// Owns the notch panels. A single panel follows the Display setting; "All displays" creates
/// one panel per screen. Only the active panel accepts the pointer and keyboard, and only it
/// opens content. The mirror panels keep drawing the compact state and still show alerts.
@MainActor
final class PanelManager {
    private let state: AppState
    private var panels: [(id: String, controller: PanelController)] = []
    private var activeID: String?
    private var builtFor: DisplayChoice?
    private var builtForScreens: [String] = []
    private var screenObserver: NSObjectProtocol?

    init(state: AppState) {
        self.state = state
        rebuild()
        observeSettings()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state.settings.displayChoice == .all else { return }
                self.rebuild()
            }
        }
    }

    func tearDown() {
        panels.forEach { $0.controller.tearDown() }
        panels.removeAll()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
    }

    private func rebuild() {
        let choice = state.settings.displayChoice
        let screens = NSScreen.screens
        let ids = screens.map(Self.id)
        if choice == .all {
            guard builtFor != .all || builtForScreens != ids else { return }
            replacePanels()
            let start = ScreenReader.builtIn().flatMap { screen in
                ids.first { $0 == Self.id(screen) }
            } ?? ids.first
            activeID = start
            panels = screens.map { screen in
                let id = Self.id(screen)
                let controller = PanelController(
                    state: state,
                    fixedScreen: screen,
                    isActive: id == activeID
                )
                controller.onActivate = { [weak self] in self?.activate(id) }
                return (id, controller)
            }
            builtForScreens = ids
        } else {
            guard builtFor != choice || builtForScreens != ids else { return }
            replacePanels()
            let controller = PanelController(state: state)
            let id = controller.currentScreenID ?? Self.id(ScreenReader.builtIn())
            activeID = id
            panels = [(id, controller)]
            builtForScreens = ids
        }
        builtFor = choice
    }

    private func replacePanels() {
        panels.forEach { $0.controller.tearDown() }
        panels.removeAll()
    }

    private func activate(_ id: String) {
        guard state.settings.displayChoice == .all, activeID != id,
              panels.contains(where: { $0.id == id }) else { return }
        activeID = id
        for panel in panels {
            panel.controller.setActive(panel.id == id)
        }
    }

    private func observeSettings() {
        withObservationTracking {
            _ = state.settings.displayChoice
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.rebuild()
                self?.observeSettings()
            }
        }
    }

    private static func id(_ screen: NSScreen?) -> String {
        guard let screen else { return "none" }
        if let uuid = ScreenReader.uuid(for: screen) { return uuid }
        let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        return "display:\(number)"
    }
}
