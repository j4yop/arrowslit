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
        if let command = ProcessInfo.processInfo.environment["ARROWSLIT_DEBUG_COMMAND"] {
            run(command)
        }
    }

    private func run(_ command: String) {
        switch command {
        case "expand": state.expand(.timer)
        case "home": state.expand(.home)
        case "collapse": state.collapse()
        case "nowplaying": state.expand(.nowPlaying)
        case "timer": state.expand(.timer)
        case "calendar": state.expand(.calendar)
        case "calendaralert":
            state.receive(.upcomingEvent(
                title: "Design review",
                startsAt: Date().addingTimeInterval(5 * 60),
                joinURL: URL(string: "https://meet.google.com/abc-defg-hij"),
                provider: .meet
            ))
        case "calendaralert-nojoin":
            state.receive(.upcomingEvent(
                title: "Weekly planning",
                startsAt: Date().addingTimeInterval(2 * 60),
                joinURL: nil,
                provider: nil
            ))
        case "dismissalert": state.dismissAlert()
        case "tray": state.expand(.tray)
        case "addfile": state.tray.add([URL(fileURLWithPath: "/etc/hosts")])
        case "mirror": state.expand(.mirror)
        case "clipboard": state.expand(.clipboard)
        case "notes": state.expand(.notes)
        case "stats": state.expand(.stats)
        case "reminders": state.expand(.reminders)
        case "stopwatch": state.expand(.stopwatch)
        case "keepawake": state.expand(.keepAwake)
        case "launcher": state.expand(.launcher)
        case "settings":
            state.collapse()
            state.onOpenSettings?()
        case "editshortcuts":
            state.expand(.launcher)
            state.isEditingShortcuts = true
        case "focus": state.startFocus()
        case "start5": state.startTimer(minutes: 5)
        case "start25": state.startTimer(minutes: 25)
        case "toggle": state.toggleTimer()
        case "reset": state.resetTimer()
        default: break
        }
    }
}
#endif
