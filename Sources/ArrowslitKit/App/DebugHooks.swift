#if DEBUG
import AppKit

/// Debug-only switches for screenshots and QA. Release builds do not include this file.
@MainActor
final class DebugHooks {
    private let state: AppState
    private var observer: NSObjectProtocol?

    init(state: AppState) {
        self.state = state
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("Arrowslit.debug"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let command = notification.object as? String else { return }
            MainActor.assumeIsolated { self?.run(command) }
        }
    }

    private func run(_ command: String) {
        switch command {
        case "expand": state.expand(.timer)
        case "collapse": state.collapse()
        case "nowplaying": state.expand(.nowPlaying)
        case "timer": state.expand(.timer)
        case "calendar": state.expand(.calendar)
        case "tray": state.expand(.tray)
        case "mirror": state.expand(.mirror)
        case "clipboard": state.expand(.clipboard)
        case "notes": state.expand(.notes)
        case "stats": state.expand(.stats)
        case "settings":
            state.collapse()
            state.onOpenSettings?()
        case "start5": state.startTimer(minutes: 5)
        case "start25": state.startTimer(minutes: 25)
        case "toggle": state.toggleTimer()
        case "reset": state.resetTimer()
        default: break
        }
    }
}
#endif
