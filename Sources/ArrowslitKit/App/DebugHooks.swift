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
        case "parity-compact":
            state.settings.appearance = .standard
            state.settings.collapseOnLeave = false
            state.settings.showWhenIdle = true
            state.collapse()
        case "parity-home":
            state.settings.appearance = .standard
            state.settings.collapseOnLeave = false
            state.settings.showWhenIdle = false
            state.expand(.home)
        case "parity-elongated":
            var appearance = NotchAppearance.standard
            appearance.nookLayout = .elongated
            state.settings.appearance = appearance
            state.settings.collapseOnLeave = false
            state.settings.showWhenIdle = false
            state.expand(.home)
        case "parity-calendar":
            state.settings.appearance = .standard
            state.settings.collapseOnLeave = false
            state.expand(.calendar)
        case "parity-timer":
            state.settings.appearance = .standard
            state.settings.collapseOnLeave = false
            state.expand(.timer)
        case "parity-stats":
            state.settings.appearance = .standard
            state.settings.collapseOnLeave = false
            state.expand(.stats)
        case "parity-notes":
            state.settings.appearance = .standard
            state.settings.collapseOnLeave = false
            state.expand(.notes)
        case "parity-launcher":
            state.settings.appearance = .standard
            state.settings.collapseOnLeave = false
            state.expand(.launcher)
        case "parity-tray":
            state.settings.appearance = .standard
            state.settings.collapseOnLeave = false
            state.expand(.tray)
        case "parity-clipboard":
            state.settings.appearance = .standard
            state.settings.collapseOnLeave = false
            state.expand(.clipboard)
        case "parity-hud":
            state.settings.appearance = .standard
            state.dismissAlert()
            state.collapse()
            state.receive(.level(kind: .volume, value: 0.62, muted: false))
        case "parity-goal":
            state.settings.appearance = .standard
            state.settings.setTabEnabled(.sports, true)
            state.dismissAlert()
            state.collapse()
            state.receive(.sportsGoal(SportsGoalEvent(
                matchID: "parity-football-1",
                teamName: "Real Madrid",
                teamShortName: "RMA",
                homeShortName: "RMA",
                awayShortName: "BAR",
                homeScore: 2,
                awayScore: 1,
                minute: "67'"
            )))
        case "parity-nowplaying":
            state.settings.appearance = .standard
            showDemoTrack()
            state.expand(.nowPlaying)
        case "parity-agent":
            state.settings.appearance = .standard
            state.dismissAlert()
            state.collapse()
            state.receive(.agentRequest(AgentRequest(
                kind: .opencode,
                project: "arrowslit",
                toolName: "Bash",
                title: "Run a command",
                detail: "swift test --build-system native"
            )))
        case "parity-reset":
            state.settings.appearance = .standard
            state.settings.collapseOnLeave = false
            state.settings.showWhenIdle = false
            state.dismissAlert()
            state.collapse()
        case "expand": state.expand(.timer)
        case "home": state.expand(.home)
        case "elongated":
            state.settings.appearance.nookLayout = .elongated
            state.expand(.home)
        case "elongated-hold":
            state.settings.appearance.nookLayout = .elongated
            state.settings.collapseOnLeave = false
            state.expand(.home)
        case "todo-demo":
            state.todos.add("Review the notch layout")
            state.todos.add("Ship the parity port")
            state.expand(.home)
        case "clipboard-demo":
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString("Arrowslit clipboard preview: a copied paragraph that should wrap onto a second line.", forType: .string)
            state.expand(.clipboard)
        case "collapse": state.collapse()
        case "nowplaying": state.expand(.nowPlaying)
        case "nowplaying-demo":
            showDemoTrack()
            state.expand(.nowPlaying)
        case "nowplaying-sources":
            showDemoTrack()
            state.nowPlaying.showDemoSource(
                name: "Spotify",
                bundleID: "com.spotify.client",
                title: "One More Time",
                artist: "Daft Punk"
            )
            state.expand(.nowPlaying)
        case "home-demo":
            showDemoTrack()
            state.expand(.home)
        case "fakeupdate":
            state.updater.showDemo(version: "0.4.5")
            state.onOpenSettings?()
        case "update-alert":
            state.updater.showDemo(version: "0.5.2")
            state.receive(.update(version: "0.5.2"))
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
        case "alert-agent-finished":
            state.receive(.agentEvent(provider: "OpenCode", title: "Finished", detail: "2m 14s · $0.03"))
        case "alert-agent-limit":
            state.receive(.agentEvent(provider: "Codex", title: "Session", detail: "92% used"))
        case "alert-track":
            state.receive(.track(title: "Low Beam", artist: "Instrumental"))
        case "alert-clipboard":
            state.receive(.clipboard(kind: "Text"))
        case "alert-mic":
            state.receive(.microphone(muted: true))
        case "alert-input":
            state.receive(.inputSource(code: "EN", name: "ABC"))
        case "alert-notification":
            state.receive(.systemNotification(app: "GitHub", title: "Review requested", body: "j4yop/arrowslit #31"))
        case "alert-capture":
            state.receive(.capture(kind: "Screenshot"))
        case "alert-watch":
            state.receive(.watch(title: "Build", detail: "Passed"))
        case "alert-timer-done":
            state.receive(.timerFinished)
        case "hold-agent-finished":
            hold { [weak self] in self?.state.receive(.agentEvent(provider: "OpenCode", title: "Finished", detail: "2m 14s · $0.03")) }
        case "hold-clipboard":
            hold { [weak self] in self?.state.receive(.clipboard(kind: "Text")) }
        case "hold-track":
            hold { [weak self] in self?.state.receive(.track(title: "Low Beam", artist: "Instrumental")) }
        case "hold-mic":
            hold { [weak self] in self?.state.receive(.microphone(muted: true)) }
        case "hold-notification":
            hold { [weak self] in self?.state.receive(.systemNotification(app: "GitHub", title: "Review requested", body: "j4yop/arrowslit #31")) }
        case "hold-timer-done":
            hold { [weak self] in self?.state.receive(.timerFinished) }
        case "hold-capture":
            hold { [weak self] in self?.state.receive(.capture(kind: "Screenshot")) }
        case "hold-watch":
            hold { [weak self] in self?.state.receive(.watch(title: "Build", detail: "Passed")) }
        case "hold-agent-limit":
            hold { [weak self] in self?.state.receive(.agentEvent(provider: "Codex", title: "Session", detail: "92% used")) }
        case "hold-timer-pomodoro":
            state.timer.startFocus(minutes: 1)
            hold { [weak self] in self?.state.receive(.timerFinished) }
        case "hold-download":
            hold { [weak self] in self?.state.receive(.download(name: "arrowslit-demo.zip")) }
        case "hold-input":
            hold { [weak self] in self?.state.receive(.inputSource(code: "EN", name: "ABC")) }
        case "music-notch":
            state.setTabEnabled(.nowPlaying, true)
            state.setTabEnabled(.agents, false)
            showDemoTrack()
            state.collapse()
        case "timer-notch":
            state.timer.start(minutes: 25)
            state.collapse()
        case "stopwatch-notch":
            state.stopwatch.start()
            state.collapse()
        case "keepawake-notch":
            state.setTabEnabled(.keepAwake, true)
            state.setTabEnabled(.agents, false)
            state.keepAwake.start()
            state.collapse()
        case "agents-on":
            state.setTabEnabled(.agents, true)
        case "calendar-notch":
            state.setTabEnabled(.calendar, true)
            state.setTabEnabled(.agents, false)
            state.calendar.showDemoEvent()
            state.collapse()
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
        case "traylink":
            state.tray.add([URL(string: "https://example.com/article")!])
            state.expand(.tray)
        case "addfile": state.tray.add([URL(fileURLWithPath: "/etc/hosts")])
        case "mirror": state.expand(.mirror)
        case "clipboard": state.expand(.clipboard)
        case "notes": state.expand(.notes)
        case "stats": state.expand(.stats)
        case "sports": state.expand(.sports)
        case "goal-alert":
            state.settings.setTabEnabled(.sports, true)
            state.receive(.sportsGoal(SportsGoalEvent(
                matchID: "demo-football-1",
                teamName: "Real Madrid",
                teamShortName: "RMA",
                homeShortName: "RMA",
                awayShortName: "BAR",
                homeScore: 2,
                awayScore: 1,
                minute: "67'"
            )))
        case "sports-notch":
            state.settings.setTabEnabled(.agents, false)
            state.settings.setTabEnabled(.sports, true)
            if let demo = SportsDemoData.matches().first {
                state.sports.showDemoCompact(demo)
            }
            state.collapse()
        case "reminders": state.expand(.reminders)
        case "stopwatch": state.expand(.stopwatch)
        case "keepawake": state.expand(.keepAwake)
        case "launcher": state.expand(.launcher)
        case "downloads-on": state.setDownloadsEnabled(true)
        case "download-state":
            let items = state.downloadProgress.items
            let text = items.map { "\($0.name):\($0.completed)/\($0.total)" }.joined(separator: ",")
            FileHandle.standardError.write(Data("ARROWSLIT_DOWNLOADS count=\(items.count) \(text)\n".utf8))
        case "download-tab": state.expand(.download)
        case "download-progress":
            state.setDownloadsEnabled(true)
            state.setTabEnabled(.agents, false)
            state.downloadProgress.showDemo()
            state.collapse()
        case "download-end":
            state.downloadProgress.endDemo()
            state.collapse()
        case "agent-ready":
            state.agents.enabledKinds = Set(AgentKind.allCases)
            state.agents.start()
            FileHandle.standardError.write(Data("ARROWSLIT_AGENT_READY \(state.agents.socketPath) running=\(state.agents.isRunning)\n".utf8))
        case "agent-demo":
            state.agents.enabledKinds = Set(AgentKind.allCases)
            state.agents.start()
            state.agents.showDemo(kind: .opencode)
        case "agent-alert":
            state.receive(.agentRequest(AgentRequest(
                kind: .opencode,
                project: "arrowslit",
                toolName: "Bash",
                title: "Run a command",
                detail: "swift test --build-system native"
            )))
        case "settings":
            state.collapse()
            state.onOpenSettings?()
        case "editshortcuts":
            state.expand(.launcher)
            state.isEditingShortcuts = true
        case "focus": state.startFocus()
        case "layout-state":
            let a = state.settings.appearance
            let size = state.panelSize(for: state.presentation, geometry: ScreenReader.current)
            FileHandle.standardError.write(Data("ARROWSLIT_LAYOUT size=\(a.size) scale=\(a.size.scale) width=\(a.width) height=\(a.height) tab=\(state.activeTab) panel=\(size) presentation=\(state.presentation)\n".utf8))
        case "presentation-state":
            FileHandle.standardError.write(Data("ARROWSLIT_PRESENT active=\(state.presentation) mirror=\(state.mirrorPresentation) alert=\(String(describing: state.currentAlert))\n".utf8))
        case "ax-state":
            FileHandle.standardError.write(Data("ARROWSLIT_AX trusted=\(AXIsProcessTrusted())\n".utf8))
        case "window-state":
            let key = NSApp.keyWindow
            let responder = key?.firstResponder.map { String(describing: type(of: $0)) } ?? "none"
            let accepts = (key as? NSPanel).map { _ in "?" } ?? "?"
            FileHandle.standardError.write(Data(
                "ARROWSLIT_STATE expanded=\(state.isExpanded) typing=\(state.isTypingInNook) key=\(key != nil) responder=\(responder) accepts=\(accepts)\n".utf8
            ))
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
    private func hold(_ action: @escaping @MainActor () -> Void) {
        for step in 0..<30 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step)) {
                MainActor.assumeIsolated { action() }
            }
        }
    }

}
#endif
