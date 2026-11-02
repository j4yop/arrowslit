import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case activities
    case home
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .activities: "Activities"
        case .home: "Home"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "capsule"
        case .activities: "square.stack.3d.up"
        case .home: "house"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @Bindable var state: AppState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var tab: SettingsTab = .general
    var onTabChange: (String) -> Void = { _ in }

    private let featureTabs: [WorkbenchTab] = [
        .nowPlaying, .timer, .stopwatch, .calendar,
        .clipboard, .keepAwake, .mirror, .notes, .stats, .sports, .reminders
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().overlay(ArrowTheme.hairline)
            Form {
                tabContent
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 520, height: 608)
        .background(ArrowTheme.ink)
        .preferredColorScheme(.dark)
        .onAppear {
            syncLogin()
            state.shortcuts.reload()
            onTabChange(tab.title)
        }
        .onChange(of: tab) { _, newTab in
            onTabChange(newTab.title)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { tab = item }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 19, weight: .regular))
                        Text(item.title)
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(tab == item ? Color.accentColor : Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tab == item ? Color.white.opacity(0.09) : Color.clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
                .accessibilityIdentifier("settings.tab.\(item.rawValue)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .general: generalTab
        case .appearance: appearanceTab
        case .activities: activitiesTab
        case .home: homeTab
        case .about: aboutTab
        }
    }

    private var generalTab: some View {
        Group {
            SettingsSection(
                title: "Behavior",
                note: "How the notch behaves while you work."
            ) {
                SettingsToggle(
                    title: "Show when idle",
                    detail: "Keep a small clock pill visible when nothing is happening. Off means the notch hides until you hover or something happens.",
                    isOn: Binding(
                        get: { state.settings.showWhenIdle },
                        set: { state.settings.showWhenIdle = $0 }
                    )
                )
                SettingsToggle(
                    title: "Open notch on hover",
                    detail: "Hold the pointer over the notch for a moment.",
                    isOn: Binding(
                        get: { state.settings.openOnHover },
                        set: { state.settings.openOnHover = $0 }
                    )
                )
                SettingsToggle(
                    title: "Collapse when the pointer leaves",
                    detail: "Close the notch after a short pause.",
                    isOn: Binding(
                        get: { state.settings.collapseOnLeave },
                        set: { state.settings.collapseOnLeave = $0 }
                    )
                )
                SettingsToggle(
                    title: "Liquid animations",
                    isOn: Binding(
                        get: { state.settings.liquidAnimations },
                        set: { state.setLiquidAnimations($0) }
                    )
                )
                SettingsToggle(
                    title: "Haptic feedback",
                    isOn: Binding(
                        get: { state.settings.hapticFeedback },
                        set: { state.settings.hapticFeedback = $0 }
                    )
                )
            }

            SettingsSection(
                title: "Interface",
                note: "Startup and the menu bar."
            ) {
                SettingsToggle(
                    title: "Open Settings on launch",
                    detail: "Show this window when Arrowslit starts.",
                    isOn: Binding(
                        get: { state.settings.openSettingsOnLaunch },
                        set: { state.settings.openSettingsOnLaunch = $0 }
                    )
                )
                SettingsToggle(
                    title: "Show menu bar icon",
                    detail: "Keep a small slit in the menu bar.",
                    isOn: Binding(
                        get: { state.settings.showMenuBarIcon },
                        set: { state.setMenuBarIconVisible($0) }
                    )
                )
                Picker("Display", selection: Binding(
                    get: { state.settings.displayChoice },
                    set: { state.settings.displayChoice = $0 }
                )) {
                    Text("Built-in display").tag(DisplayChoice.automatic)
                    Text("Main display").tag(DisplayChoice.main)
                    Text("Follow the pointer").tag(DisplayChoice.followPointer)
                    Text("All displays").tag(DisplayChoice.all)
                    Divider()
                    ForEach(DisplayOption.connected) { option in
                        Text(option.name).tag(DisplayChoice.specific(option.uuid))
                    }
                    if case .specific(let uuid) = state.settings.displayChoice,
                       !DisplayOption.connected.contains(where: { $0.uuid == uuid }) {
                        Text("Saved display (not connected)").tag(state.settings.displayChoice)
                    }
                }
                .pickerStyle(.menu)
                SettingsToggle(
                    title: "Open at login",
                    detail: "Start Arrowslit when you sign in.",
                    isOn: $launchAtLogin
                )
                .onChange(of: launchAtLogin) { _, value in
                    setLaunchAtLogin(value)
                }
                if let loginError {
                    Text(loginError)
                        .font(ArrowTheme.caption)
                        .foregroundStyle(ArrowTheme.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
            }

            LockScreenSection(state: state)

            SettingsSection(title: "Timer") {
                SettingsToggle(
                    title: "Play a sound when a timer ends",
                    isOn: Binding(
                        get: { state.settings.timerSound },
                        set: { state.setTimerSound($0) }
                    )
                )
            }
        }
    }

    private var appearanceTab: some View {
        AppearanceSettingsSection(state: state)
    }

    private var activitiesTab: some View {
        Group {
            SettingsSection(
                title: "Live Activities",
                note: "What the notch watches while you work."
            ) {
                SettingsToggle(
                    title: "Calls & Microphone",
                    detail: "FaceTime, Zoom, Meet, Teams and any app using the microphone. Mute and hang up from the notch when the app supports it.",
                    isOn: Binding(
                        get: { state.settings.callsEnabled },
                        set: { state.setCallsEnabled($0) }
                    )
                )
            }

            CodingAssistantSection(state: state)

            NowPlayingAppsSection(state: state)

            SettingsSection(
                title: "Playback",
                note: "How long a paused track stays in the notch."
            ) {
                HStack(spacing: 12) {
                    Text("Keep paused media for")
                        .font(ArrowTheme.body)
                        .fontWeight(.medium)
                        .foregroundStyle(ArrowTheme.bone)
                    Spacer(minLength: 8)
                    Picker("", selection: Binding(
                        get: { state.settings.pausedMediaLinger },
                        set: { state.setPausedMediaLinger($0) }
                    )) {
                        ForEach(SettingsStore.lingerChoices, id: \.self) { seconds in
                            Text(lingerLabel(seconds)).tag(seconds)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }

            SportsSettingsSection(state: state)

            SettingsSection(
                title: "Music",
                note: "Now Playing stays local. Timed lyrics are optional."
            ) {
                SettingsToggle(
                    title: "Show timed lyrics",
                    detail: "Looks up the current song on lrclib.net, with a timed fallback. Sends only the title, artist, album and length.",
                    isOn: Binding(
                        get: { state.settings.lyricsEnabled },
                        set: { state.settings.lyricsEnabled = $0 }
                    )
                )
            }

            SettingsSection(
                title: "Alerts",
                note: "A quick heads-up in the notch."
            ) {
                AlertToggleRow(
                    symbol: "bolt.fill",
                    tint: Color(red: 0.27, green: 0.78, blue: 0.40),
                    title: "Charging",
                    detail: nil,
                    isOn: Binding(
                        get: { state.settings.alertCharging },
                        set: { state.settings.alertCharging = $0 }
                    )
                )
                AlertToggleRow(
                    symbol: "battery.25",
                    tint: ArrowTheme.red,
                    title: "Low Battery",
                    detail: "At 20% and 10%",
                    isOn: Binding(
                        get: { state.settings.alertLowBattery },
                        set: { state.settings.alertLowBattery = $0 }
                    )
                )
                AlertToggleRow(
                    symbol: "headphones",
                    tint: Color.white.opacity(0.22),
                    title: "Headphones",
                    detail: "When AirPods or other Bluetooth headphones connect",
                    isOn: Binding(
                        get: { state.settings.alertHeadphones },
                        set: { state.settings.alertHeadphones = $0 }
                    )
                )
                AlertToggleRow(
                    symbol: "speaker.wave.2.fill",
                    tint: Color(red: 0.04, green: 0.52, blue: 1),
                    title: "Volume & Brightness",
                    detail: "Shows the level in the notch when you change it",
                    isOn: Binding(
                        get: { state.settings.alertVolumeBrightness },
                        set: { state.settings.alertVolumeBrightness = $0 }
                    )
                )
            }
        }
    }

    private var homeTab: some View {
        Group {
            SettingsSection(
                title: "Features",
                note: "Choose what appears in the launcher."
            ) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4)
                    ],
                    spacing: 0
                ) {
                    ForEach(featureTabs) { item in
                        FeatureSelectionButton(state: state, tab: item)
                    }
                }
                .padding(6)
                FileTraySettingsRow(state: state)
            }

            SettingsSection(
                title: "Downloads",
                note: "A heads-up when a file lands in Downloads. macOS asks for access once."
            ) {
                SettingsToggle(
                    title: "Download progress & finished downloads",
                    detail: "Shows browser downloads in the notch, with Stop and Show in Finder. Off until you turn it on.",
                    isOn: Binding(
                        get: { state.settings.downloadsEnabled },
                        set: { state.setDownloadsEnabled($0) }
                    )
                )
            }

            SettingsSection(
                title: "Shortcuts",
                note: "Run your favourite Shortcuts from Home."
            ) {
                SettingsToggle(
                    title: "Shortcuts",
                    detail: "Pick up to \(SettingsStore.maximumFavoriteShortcuts) to show on Home.",
                    isOn: Binding(
                        get: { state.settings.shortcutsEnabled },
                        set: { state.settings.shortcutsEnabled = $0 }
                    )
                )
                if state.settings.shortcutsEnabled {
                    if !state.shortcuts.isSupported {
                        Text("The Shortcuts app isn't available on this Mac.")
                            .font(ArrowTheme.detail)
                            .foregroundStyle(ArrowTheme.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                    } else if state.shortcuts.isLoading && state.shortcuts.available.isEmpty {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                    } else if state.shortcuts.available.isEmpty {
                        Text("You don't have any shortcuts yet. Make some in the Shortcuts app.")
                            .font(ArrowTheme.detail)
                            .foregroundStyle(ArrowTheme.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                    } else {
                        ForEach(state.shortcuts.available, id: \.self) { name in
                            let isFavorite = state.settings.favoriteShortcuts.contains(name)
                            Toggle(isOn: Binding(
                                get: { isFavorite },
                                set: { _ in state.settings.toggleFavorite(name) }
                            )) {
                                HStack {
                                    Text(name)
                                        .font(ArrowTheme.body)
                                        .foregroundStyle(ArrowTheme.bone)
                                    Spacer(minLength: 8)
                                }
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .disabled(!isFavorite && state.settings.favoriteShortcuts.count >= SettingsStore.maximumFavoriteShortcuts)
                        }
                    }
                }
            }

            SettingsSection(
                title: "Access",
                note: "Allow these once. macOS remembers your choice for the installed app."
            ) {
                AccessStatusRow(
                    title: "Calendar",
                    symbol: "calendar",
                    detail: calendarDetail,
                    tint: calendarTint,
                    granted: state.calendar.access == .granted,
                    actionTitle: calendarActionTitle,
                    action: calendarAction
                )
                AccessStatusRow(
                    title: "Reminders",
                    symbol: "checklist",
                    detail: remindersDetail,
                    tint: remindersTint,
                    granted: state.reminders.access == .granted,
                    actionTitle: remindersActionTitle,
                    action: remindersAction
                )
                AccessStatusRow(
                    title: "Camera",
                    symbol: "person.crop.square",
                    detail: cameraDetail,
                    tint: cameraTint,
                    granted: state.camera.state == .granted,
                    actionTitle: cameraActionTitle,
                    action: cameraAction
                )
            }
        }
    }

    private var aboutTab: some View {
        Group {
            SettingsSection(
                title: "Updates",
                note: "Checks github.com on launch and once a day. No account or tracking."
            ) {
                SettingsToggle(
                    title: "Check for updates automatically",
                    detail: "On launch and once a day, ask GitHub for the latest release.",
                    isOn: Binding(
                        get: { state.settings.checksForUpdates },
                        set: { state.setChecksForUpdates($0) }
                    )
                )
                UpdateStatusRow(state: state)
            }

            SettingsSection(title: "About") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arrowslit")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                    Text("Version \(version) (\(build))")
                        .font(ArrowTheme.detail)
                        .foregroundStyle(ArrowTheme.muted)
                    Text("Local-first. No account or analytics. Update checks contact GitHub; lyrics are optional.")
                        .font(ArrowTheme.detail)
                        .foregroundStyle(ArrowTheme.muted)
                    Text("GPL-3.0 · © 2026 Jay Gopal and contributors")
                        .font(ArrowTheme.caption)
                        .foregroundStyle(ArrowTheme.faint)
                        .padding(.top, 2)
                    HStack(spacing: 14) {
                        Link("Source Code", destination: URL(string: "https://github.com/j4yop/arrowslit")!)
                        Link("License", destination: URL(string: "https://github.com/j4yop/arrowslit/blob/main/LICENSE")!)
                    }
                    .font(ArrowTheme.caption)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func lingerLabel(_ seconds: TimeInterval) -> String {
        seconds < 60 ? "\(Int(seconds)) seconds" : (seconds == 60 ? "1 minute" : "\(Int(seconds / 60)) minutes")
    }

    private var calendarDetail: String {
        switch state.calendar.access {
        case .granted: "Your next event appears in the notch."
        case .notAsked: "Not connected."
        case .denied: "Access is off. Open Privacy & Security to allow it."
        case .limited: "Access is limited. Open Privacy & Security to change it."
        }
    }

    private var calendarTint: Color {
        switch state.calendar.access {
        case .granted: ArrowTheme.green
        case .denied, .limited: ArrowTheme.red
        case .notAsked: ArrowTheme.faint
        }
    }

    private var calendarActionTitle: String? {
        switch state.calendar.access {
        case .granted: nil
        case .notAsked: "Connect"
        case .denied, .limited: "Open Settings"
        }
    }

    private func calendarAction() {
        switch state.calendar.access {
        case .notAsked: state.calendar.requestAccess()
        case .denied, .limited: state.calendar.openPrivacySettings()
        case .granted: break
        }
    }

    private var remindersDetail: String {
        switch state.reminders.access {
        case .granted: "Today's reminders appear in the notch."
        case .notAsked: "Not connected."
        case .denied: "Access is off. Open Privacy & Security to allow it."
        }
    }

    private var remindersTint: Color {
        switch state.reminders.access {
        case .granted: ArrowTheme.green
        case .denied: ArrowTheme.red
        case .notAsked: ArrowTheme.faint
        }
    }

    private var remindersActionTitle: String? {
        switch state.reminders.access {
        case .granted: nil
        case .notAsked: "Connect"
        case .denied: "Open Settings"
        }
    }

    private func remindersAction() {
        switch state.reminders.access {
        case .notAsked: state.reminders.requestAccess()
        case .denied: state.reminders.openPrivacySettings()
        case .granted: break
        }
    }

    private var cameraDetail: String {
        switch state.camera.state {
        case .granted: "Shows a local preview. Nothing is recorded."
        case .notAsked: "Not connected."
        case .denied: "Access is off. Open Privacy & Security to allow it."
        case .noCamera: "No camera found on this Mac."
        }
    }

    private var cameraTint: Color {
        switch state.camera.state {
        case .granted: ArrowTheme.green
        case .denied: ArrowTheme.red
        case .notAsked, .noCamera: ArrowTheme.faint
        }
    }

    private var cameraActionTitle: String? {
        switch state.camera.state {
        case .granted, .noCamera: nil
        case .notAsked: "Connect"
        case .denied: "Open Settings"
        }
    }

    private func cameraAction() {
        switch state.camera.state {
        case .notAsked: state.camera.request()
        case .denied: state.camera.openPrivacySettings()
        case .granted, .noCamera: break
        }
    }

    private func syncLogin() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled || status == .requiresApproval
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = "Could not change the login item. \(error.localizedDescription)"
            syncLogin()
        }
    }
}

/// Coding assistants' permission requests, answered from the notch.
private struct CodingAssistantSection: View {
    @Bindable var state: AppState
    @State private var problem: (kind: AgentKind, text: String)?

    var body: some View {
        SettingsSection(
            title: "Coding Assistants",
            note: "When an assistant wants to run a command or change a file, the notch shows what it wants to do, with Allow and Deny. Close it, or wait two minutes, and the assistant asks in its own window. Switching one on adds a hook; switching it off removes it. New sessions pick it up."
        ) {
            ForEach(AgentKind.allCases) { kind in
                Toggle(isOn: enabled(kind)) {
                    HStack(spacing: 10) {
                        Image(systemName: symbol(kind))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ArrowTheme.amber)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.displayName)
                                .font(ArrowTheme.body)
                                .foregroundStyle(ArrowTheme.bone)
                            Text(detail(kind))
                                .font(ArrowTheme.detail)
                                .foregroundStyle(ArrowTheme.muted)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.accentColor)
                if let problem, problem.kind == kind {
                    Text(problem.text)
                        .font(ArrowTheme.caption)
                        .foregroundStyle(ArrowTheme.red)
                        .padding(.leading, 30)
                }
            }
        }
    }

    private func detail(_ kind: AgentKind) -> String {
        let path = AgentHookSettings.displayPath(for: kind)
        return kind.asksOnlyWhenNeeded
            ? "Only when it would ask you anyway · \(path)"
            : "Asks before every terminal command · \(path)"
    }

    private func symbol(_ kind: AgentKind) -> String {
        switch kind {
        case .claude, .codex, .copilot, .opencode: "terminal.fill"
        case .antigravity, .cursor: "chevron.left.forwardslash.chevron.right"
        }
    }

    private func enabled(_ kind: AgentKind) -> Binding<Bool> {
        Binding {
            state.settings.agentApprovals.contains(kind)
        } set: { isOn in
            problem = nil
            if let error = state.setAgentApproval(kind, enabled: isOn) {
                problem = (kind, error)
            }
        }
    }
}

/// Every app's music, or only the apps ticked here.
private struct NowPlayingAppsSection: View {
    @Bindable var state: AppState

    private static let suggested = ["com.spotify.client", "com.apple.Music"]

    var body: some View {
        SettingsSection(
            title: "Now Playing Apps",
            note: "Choose which apps can appear in the notch."
        ) {
            HStack(spacing: 12) {
                Text("Show music from")
                    .font(ArrowTheme.body)
                    .fontWeight(.medium)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 8)
                Picker("", selection: mode) {
                    Text("All apps").tag(MediaAppFilter.Mode.all)
                    Text("Only these apps").tag(MediaAppFilter.Mode.chosen)
                }
                .labelsHidden()
                .frame(width: 160)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            if state.settings.nowPlayingAppMode == .chosen {
                if rows.isEmpty {
                    Text("No apps yet. Add one below.")
                        .font(ArrowTheme.detail)
                        .foregroundStyle(ArrowTheme.muted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                } else {
                    ForEach(rows) { app in
                        Toggle(isOn: allowed(app.id)) {
                            HStack(spacing: 10) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(app.name)
                                    .font(ArrowTheme.body)
                                    .foregroundStyle(ArrowTheme.bone)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .contextMenu {
                            Button("Remove from List") { state.forgetMediaApp(app.id) }
                        }
                    }
                }
                Button("Add App…", action: addApp)
                    .buttonStyle(NookPressStyle())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone)
                    .padding(.horizontal, 12)
                    .frame(height: 30, alignment: .leading)
                Text("Apps join this list once they play something. YouTube and other websites play through your browser, so leave the browser off to keep them out.")
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
    }

    private var mode: Binding<MediaAppFilter.Mode> {
        Binding {
            state.settings.nowPlayingAppMode
        } set: { newMode in
            if newMode == .chosen, state.settings.nowPlayingApps.isEmpty {
                for id in Self.suggested where MediaAppInfo.isInstalled(id) {
                    state.setMediaApp(id, allowed: true)
                }
            }
            state.setMediaAppMode(newMode)
        }
    }

    private func allowed(_ id: String) -> Binding<Bool> {
        Binding {
            state.settings.nowPlayingApps.contains(id)
        } set: { isOn in
            state.setMediaApp(id, allowed: isOn)
        }
    }

    private var rows: [MediaAppInfo] {
        var ids = state.settings.nowPlayingApps
        ids += state.settings.recentMediaApps.identifiers.filter {
            !ids.contains($0) && $0 != Bundle.main.bundleIdentifier
        }
        return ids.map(MediaAppInfo.lookup)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier {
                state.setMediaApp(id, allowed: true)
            }
        }
    }
}

/// An app's name and icon, looked up once per launch.
@MainActor
private struct MediaAppInfo: Identifiable {
    let id: String
    let name: String
    let icon: NSImage

    private static var cache: [String: MediaAppInfo] = [:]

    static func isInstalled(_ id: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil
    }

    static func lookup(_ id: String) -> MediaAppInfo {
        if let cached = cache[id] { return cached }
        let info: MediaAppInfo
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            let name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            info = MediaAppInfo(id: id, name: name, icon: NSWorkspace.shared.icon(forFile: url.path))
        } else {
            return MediaAppInfo(id: id, name: id, icon: NSWorkspace.shared.icon(for: .application))
        }
        cache[id] = info
        return info
    }
}

private struct AppearanceSettingsSection: View {
    @Bindable var state: AppState

    private var appearance: NotchAppearance { state.settings.appearance }

    private func binding<Value>(_ keyPath: WritableKeyPath<NotchAppearance, Value>) -> Binding<Value> {
        Binding(
            get: { state.settings.appearance[keyPath: keyPath] },
            set: { state.settings.appearance[keyPath: keyPath] = $0 }
        )
    }

    var body: some View {
        SettingsSection(
            title: "Appearance",
            note: "Match the closed shape to your display. The open panel follows the same scale."
        ) {
            row("Home layout") {
                Picker("", selection: binding(\.nookLayout)) {
                    Text("Standard").tag(NookLayout.standard)
                    Text("Elongated").tag(NookLayout.elongated)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 190)
            }


            row("Theme") {
                Picker("", selection: binding(\.theme)) {
                    Text("Black").tag(NotchTheme.black)
                    Text("Glass").tag(NotchTheme.glass)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 190)
            }

            if appearance.theme == .glass {
                row("Glass") {
                    HStack(spacing: 8) {
                        Text("Clear").font(ArrowTheme.caption).foregroundStyle(ArrowTheme.faint)
                        Slider(value: binding(\.glassTint), in: NotchAppearance.glassTintRange)
                            .frame(width: 120)
                        Text("Tinted").font(ArrowTheme.caption).foregroundStyle(ArrowTheme.faint)
                    }
                }
            } else {
                SettingsToggle(
                    title: "Pitch black",
                    detail: "Remove the shadow and outline so the extension blends into the notch.",
                    isOn: binding(\.pitchBlack)
                )
            }


            row("Size") {
                Picker("", selection: binding(\.size)) {
                    Text("Small").tag(NotchSize.small)
                    Text("Medium").tag(NotchSize.medium)
                    Text("Large").tag(NotchSize.large)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 190)
            }


            sliderRow("Width", value: binding(\.width), range: NotchAppearance.widthRange, step: 2)


            sliderRow("Thickness", value: binding(\.height), range: NotchAppearance.heightRange, step: 1)


            HStack(spacing: 12) {
                Text("The shape stays visible while this section is open, so you can see each change.")
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                Spacer(minLength: 8)
                Button("Restore Defaults") {
                    state.settings.resetAppearance()
                }
                .buttonStyle(NookPressStyle())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ArrowTheme.bone)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .disabled(appearance == .standard)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(ArrowTheme.body)
                .fontWeight(.medium)
                .foregroundStyle(ArrowTheme.bone)
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        let rounded = Binding(
            get: { value.wrappedValue },
            set: { value.wrappedValue = (($0 / step).rounded() * step) }
        )
        return row(title) {
            HStack(spacing: 10) {
                Slider(value: rounded, in: range)
                    .frame(width: 150)
                Text("\(Int(value.wrappedValue.rounded())) pt")
                    .font(ArrowTheme.caption)
                    .monospacedDigit()
                    .foregroundStyle(ArrowTheme.muted)
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }
}

private struct SportsSettingsSection: View {
    @Bindable var state: AppState
    @State private var keyDraft = ""
    @State private var isEditingKey = false

    private var service: SportsService { state.sports }
    private var isOn: Bool { state.settings.isTabEnabled(.sports) }

    var body: some View {
        SettingsSection(
            title: "Sports",
            note: "Live football from BigBallsData. Off by default; nothing is requested until you connect."
        ) {
            SettingsToggle(
                title: "Sports in the launcher",
                detail: "Premier League, La Liga, Champions League, Serie A, Bundesliga and Ligue 1.",
                isOn: Binding(
                    get: { isOn },
                    set: { state.setTabEnabled(.sports, $0) }
                )
            )

            if isOn {
                providerRow
                keyRow
                SettingsToggle(
                    title: "Preview with sample matches",
                    detail: service.hasAPIKey
                        ? "Shows demo matches without using BigBallsData requests."
                        : "Connect a key below to switch from preview to live scores.",
                    isOn: Binding(
                        get: { state.settings.sportsPreview },
                        set: { value in
                            guard service.hasAPIKey else {
                                state.settings.sportsPreview = true
                                return
                            }
                            state.settings.sportsPreview = value
                            state.sports.refresh(force: true)
                        }
                    )
                )
                SettingsToggle(
                    title: "Show live score in the notch",
                    detail: "Uses the pinned match first, otherwise the first live favorite. Needs a live key.",
                    isOn: Binding(
                        get: { state.settings.sportsShowInNotch },
                        set: { state.settings.sportsShowInNotch = $0 }
                    )
                )
                SettingsToggle(
                    title: "Goal notifications",
                    detail: "Shows a popup and a haptic when the match in the notch scores. Only while Arrowslit is running.",
                    isOn: Binding(
                        get: { state.settings.sportsGoalAlerts },
                        set: { state.setSportsGoalAlerts($0) }
                    )
                )
                refreshRow
                competitions
                quotaRow
            }
        }
    }

    private var providerRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.20, green: 0.72, blue: 0.45))
                Image(systemName: "soccerball")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("BigBallsData")
                    .font(ArrowTheme.body)
                    .fontWeight(.medium)
                    .foregroundStyle(ArrowTheme.bone)
                Text(service.coverageNote ?? service.account.map { "\($0.plan.capitalized) plan" } ?? "Free plan")
                    .font(ArrowTheme.detail)
                    .foregroundStyle(service.coverageNote == nil ? ArrowTheme.muted : ArrowTheme.amber)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if service.hasAPIKey {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.green)
            } else {
                Text("Not connected")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(ArrowTheme.faint)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var keyRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            if service.hasAPIKey, !isEditingKey {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(ArrowTheme.amber)
                    Text(service.keyHint ?? "Key saved")
                        .font(.system(size: 10.5))
                        .foregroundStyle(ArrowTheme.muted)
                    Spacer(minLength: 4)
                    Button("Test") { service.validateKey() }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(ArrowTheme.bone)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    Button("Replace") { isEditingKey = true }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(ArrowTheme.bone)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    Button("Remove") { service.removeAPIKey() }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(ArrowTheme.red)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                }
            } else {
                HStack(spacing: 7) {
                    SecureField("bbs_live_…", text: $keyDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ArrowTheme.bone)
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(ArrowTheme.hairline, lineWidth: 0.5)
                        }
                    Button("Save") {
                        service.saveAPIKey(keyDraft)
                        keyDraft = ""
                        isEditingKey = false
                    }
                    .buttonStyle(NookPressStyle())
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.white.opacity(0.12)
                                : ArrowTheme.amber)
                    )
                    .disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Get a free key") {
                        if let url = URL(string: "https://bigballsdata.com/signup?plan=free") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(NookPressStyle())
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
                }
                Text("Stored in the macOS Keychain. Arrowslit never puts the key in the app bundle or logs.")
                    .font(ArrowTheme.caption)
                    .foregroundStyle(ArrowTheme.faint)
            }

            if let error = service.errorMessage {
                Text(error)
                    .font(ArrowTheme.caption)
                    .foregroundStyle(ArrowTheme.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var refreshRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Refresh while Sports is open")
                    .font(ArrowTheme.body)
                    .fontWeight(.medium)
                    .foregroundStyle(ArrowTheme.bone)
                Text("Free tier: one request refreshes all live football.")
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
            }
            Spacer(minLength: 8)
            Picker("", selection: Binding(
                get: { state.settings.sportsRefreshSeconds },
                set: { state.settings.sportsRefreshSeconds = $0 }
            )) {
                Text("30s").tag(30)
                Text("60s").tag(60)
                Text("120s").tag(120)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var competitions: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Competitions")
                    .font(ArrowTheme.body)
                    .fontWeight(.medium)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer()
                Text("Following + Featured")
                    .font(ArrowTheme.caption)
                    .foregroundStyle(ArrowTheme.faint)
            }
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)],
                spacing: 5
            ) {
                ForEach(SportsCatalog.all) { competition in
                    SportsCompetitionToggle(state: state, competition: competition)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var quotaRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(service.quota.isLow ? ArrowTheme.amber : ArrowTheme.green)
            Text(service.quota.summary)
                .font(ArrowTheme.caption)
                .foregroundStyle(ArrowTheme.muted)
            Spacer(minLength: 4)
            Button("Data by BigBallsData") {
                if let url = URL(string: "https://bigballsdata.com") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(ArrowTheme.amber)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

private struct SportsCompetitionToggle: View {
    @Bindable var state: AppState
    let competition: SportsCompetition
    @State private var isHovering = false

    private var isOn: Bool {
        state.settings.sportsCompetitionIDs.contains(competition.id)
    }

    var body: some View {
        Button {
            state.sports.setCompetition(competition.id, enabled: !isOn)
        } label: {
            HStack(spacing: 6) {
                Text(competition.shortName)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isOn ? ArrowTheme.bone : ArrowTheme.muted)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isOn ? ArrowTheme.green : ArrowTheme.faint)
            }
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.06) : Color.white.opacity(0.028))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isOn ? ArrowTheme.green.opacity(0.25) : ArrowTheme.hairline, lineWidth: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle(pressedScale: 0.97))
        .onHover { isHovering = $0 }
    }
}

private struct FileTraySettingsRow: View {
    @Bindable var state: AppState

    private var isOn: Bool { state.settings.isTabEnabled(.tray) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: Binding(
                get: { isOn },
                set: { state.setTabEnabled(.tray, $0) }
            )) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(red: 0.17, green: 0.78, blue: 0.93))
                        Image(systemName: "tray.full.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("File Tray")
                            .font(ArrowTheme.body)
                            .fontWeight(.medium)
                            .foregroundStyle(ArrowTheme.bone)
                        Text("Files you drop on the notch, or saved document windows. Up to 30; clears when the app quits, except pinned ones")
                            .font(ArrowTheme.detail)
                            .foregroundStyle(ArrowTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.accentColor)
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            if isOn {
                Button("Allow document window dragging…") {
                    DocumentWindowDrag.requestAccess()
                }
                .buttonStyle(NookPressStyle())
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ArrowTheme.bone)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(ArrowTheme.hairline, lineWidth: 0.5)
                }
                .padding(.horizontal, 12)
                .padding(.top, 9)

                Text("Enable Arrowslit in macOS Accessibility settings to store a saved document by dragging its whole window to the notch. The source app must expose its saved document location. Some apps also ask for Automation access. Unsaved or ambiguous documents cannot be stored.")
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.top, 7)
                    .padding(.bottom, 10)
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let note: String?
    @ViewBuilder var content: Content

    init(title: String, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    var body: some View {
        Section {
            content
        } header: {
            Text(title)
        } footer: {
            if let note {
                Text(note)
            }
        }
    }
}

private struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(ArrowTheme.hairline)
            .frame(height: 0.5)
            .padding(.leading, 14)
    }
}

private struct AccessStatusRow: View {
    let title: String
    let symbol: String
    let detail: String
    let tint: Color
    let granted: Bool
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ArrowTheme.body)
                    .fontWeight(.medium)
                    .foregroundStyle(ArrowTheme.bone)
                Text(detail)
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(NookPressStyle())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(ArrowTheme.hairline, lineWidth: 0.5)
                    }
            } else if granted {
                Label("Allowed", systemImage: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tint)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct SettingsToggle: View {
    let title: String
    var detail: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ArrowTheme.body)
                        .fontWeight(.medium)
                        .foregroundStyle(ArrowTheme.bone)
                    if let detail {
                        Text(detail)
                            .font(ArrowTheme.detail)
                            .foregroundStyle(ArrowTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(.accentColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

private struct LockScreenSection: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { state.settings.showOnLockScreen },
                set: { state.settings.showOnLockScreen = $0 }
            )) {
                Text("Show on Lock Screen")
                    .font(ArrowTheme.body)
                    .fontWeight(.medium)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 12)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.accentColor)
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(ArrowTheme.hairline, lineWidth: 0.5)
            }

            Text("While your Mac is locked, the notch shows a running timer, what's playing, or charging, just as it looks when you're logged in. Anyone at your Mac can see it, so it's off until you turn it on.")
                .font(ArrowTheme.detail)
                .foregroundStyle(ArrowTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }
}

private struct AlertToggleRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint)
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ArrowTheme.body)
                        .fontWeight(.medium)
                        .foregroundStyle(ArrowTheme.bone)
                    if let detail {
                        Text(detail)
                            .font(ArrowTheme.detail)
                            .foregroundStyle(ArrowTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

private struct FeatureSelectionButton: View {
    @Bindable var state: AppState
    let tab: WorkbenchTab
    @State private var isHovering = false

    private var isOn: Bool { state.settings.isTabEnabled(tab) }

    var body: some View {
        Button {
            state.setTabEnabled(tab, !isOn)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isOn ? ArrowTheme.amber : ArrowTheme.faint)
                    .frame(width: 18)
                Text(tab.title)
                    .font(ArrowTheme.body)
                    .foregroundStyle(isOn ? ArrowTheme.bone : ArrowTheme.muted)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ArrowTheme.amber)
                    .frame(width: 12)
                    .opacity(isOn ? 1 : 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.06) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle())
        .onHover { isHovering = $0 }
    }
}


private struct UpdateStatusRow: View {
    @Bindable var state: AppState

    private var updater: UpdateService { state.updater }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ArrowTheme.body)
                    .fontWeight(.medium)
                    .foregroundStyle(ArrowTheme.bone)
                Text(detail)
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var trailing: some View {
        switch updater.state {
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .downloading(let progress):
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 92)
        case .available(let release):
            if updater.canInstallInPlace(release) {
                UpdateActionButton(title: "Install and Relaunch", primary: true) {
                    updater.install(release)
                }
            } else {
                UpdateActionButton(title: "Download & Open", primary: true) {
                    updater.downloadAndOpen(release)
                }
            }
        case .installing:
            ProgressView()
                .controlSize(.small)
        case .downloaded(let url):
            UpdateActionButton(title: "Open DMG", primary: true) {
                NSWorkspace.shared.open(url)
            }
        case .failed:
            UpdateActionButton(title: "Try Again", primary: true) {
                if let release = updater.availableRelease {
                    updater.install(release)
                } else {
                    updater.check()
                }
            }
        case .upToDate:
            UpdateActionButton(title: "Check Again") { updater.check() }
        case .idle:
            UpdateActionButton(title: "Check for Updates") { updater.check() }
        }
    }

    private var symbol: String {
        switch updater.state {
        case .available: "arrow.down.circle.fill"
        case .checking, .downloading, .installing: "arrow.triangle.2.circlepath"
        case .downloaded, .upToDate: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .idle: "arrow.down.circle"
        }
    }

    private var tint: Color {
        switch updater.state {
        case .available, .downloading, .installing: ArrowTheme.amber
        case .downloaded, .upToDate: ArrowTheme.green
        case .failed: ArrowTheme.red
        case .checking, .idle: ArrowTheme.muted
        }
    }

    private var title: String {
        switch updater.state {
        case .available(let release): "Arrowslit \(release.version) is available"
        case .checking: "Checking for updates"
        case .downloading: "Downloading Arrowslit\(updater.availableRelease.map { " \($0.version)" } ?? "")"
        case .downloaded: "Update downloaded"
        case .installing: "Installing Arrowslit…"
        case .upToDate: "You're up to date"
        case .failed: "Couldn't update"
        case .idle: "Arrowslit \(updater.currentVersion?.description ?? "0.0.0")"
        }
    }

    private var detail: String {
        switch updater.state {
        case .available(let release):
            updater.canInstallInPlace(release)
                ? "Verifies the signed update, installs it and relaunches."
                : "Download the DMG, then drag Arrowslit into Applications."
        case .checking: "Contacting GitHub…"
        case .downloading(let progress): "\(Int((progress * 100).rounded()))% downloaded"
        case .installing: "Verifying the signature and replacing the app…"
        case .downloaded: "Open the DMG and drag Arrowslit into Applications."
        case .upToDate: "This is the latest version."
        case .failed(let message): message
        case .idle: "Check GitHub for a newer version."
        }
    }
}

private struct UpdateActionButton: View {
    let title: String
    var primary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if primary {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(primary ? ArrowTheme.ink : ArrowTheme.bone)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(primary ? ArrowTheme.amber : Color.white.opacity(0.08))
            )
            .overlay {
                if !primary {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(ArrowTheme.hairline, lineWidth: 0.5)
                }
            }
        }
        .buttonStyle(NookPressStyle())
    }
}
