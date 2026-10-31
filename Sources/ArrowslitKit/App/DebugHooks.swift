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
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                self?.run(command)
            }
        }
    }

    private func run(_ command: String) {
        switch command {
        case "expand": state.expand(.timer)
        case "home": state.expand(.home)
        case "collapse": state.collapse()
        case "nowplaying": state.expand(.nowPlaying)
        case "nowplaying-demo":
            showDemoTrack()
            state.expand(.nowPlaying)
        case "home-demo":
            showDemoTrack()
            state.expand(.home)
        case "fakeupdate":
            state.updater.showDemo(version: "0.4.5")
            state.onOpenSettings?()
        case "lockscreen":
            state.settings.showOnLockScreen = true
            state.nowPlaying.hideForDemo()
            state.system.showDemoPower()
            state.session.simulateLocked(true)
        case "unlockscreen":
            state.session.endSimulation()
            state.system.endDemoPower()
            state.nowPlaying.endDemo()
        case "alert-charging":
            state.receive(.charging(level: 80, isCharging: true))
        case "alert-battery":
            state.receive(.lowBattery(level: 20))
        case "alert-headphones":
            state.receive(.headphones(name: "AirPods Pro"))
        case "alert-volume":
            state.receive(.level(kind: .volume, value: 0.62, muted: false))
        case "alert-brightness":
            state.receive(.level(kind: .brightness, value: 0.45, muted: false))
        case "audio-debug":
            let line = "ARROWSLIT_AUDIO \(state.system.debugAudio())\n"
            FileHandle.standardError.write(Data(line.utf8))
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

    private func showDemoTrack() {
        state.nowPlaying.showDemo(
            title: "Blinding Lights",
            artist: "The Weeknd",
            album: "After Hours",
            artwork: demoArtwork(),
            accent: ArtworkAccent(red: 1, green: 0.55, blue: 0.12),
            duration: 202,
            elapsed: 4
        )
        state.settings.lyricsEnabled = false
    }

    private func demoArtwork() -> NSImage {
        let image = NSImage(size: NSSize(width: 112, height: 112))
        image.lockFocus()
        NSColor(red: 0.92, green: 0.42, blue: 0.12, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 112, height: 112)).fill()
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(ovalIn: NSRect(x: 14, y: 28, width: 84, height: 84)).fill()
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: NSRect(x: 22, y: 74, width: 68, height: 8), xRadius: 4, yRadius: 4).fill()
        image.unlockFocus()
        return image
    }
}
#endif
