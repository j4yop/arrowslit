import AppKit
import Combine
import AVFoundation
import SwiftUI

// MARK: - AI agents

struct AIAgentsSettingsSection: View {
    @AppStorage("arrowslit.agents.enabled") private var enabled = true
    @AppStorage("arrowslit.agents.period") private var period = AgentPeriod.today.rawValue
    @AppStorage("arrowslit.agents.limitDisplay") private var limitDisplay = NotchAgentLimitDisplay.remaining.rawValue
    @AppStorage("arrowslit.agents.dailyBudget") private var dailyBudget = 0.0
    @AppStorage("arrowslit.agents.limitThreshold") private var limitThreshold = 80.0
    @AppStorage("arrowslit.agents.finishMinimum") private var finishMinimum = 60.0
    @State private var providers: [AgentProvider: Bool] = [:]

    var body: some View {
        SettingsSection(
            title: "AI Agents",
            note: "What the AI page measures and which local provider logs it reads. Changes apply as logs arrive."
        ) {
            SettingsToggle(title: "Read agent usage", isOn: $enabled)
                .onChange(of: enabled) { _, _ in AgentUsageService.shared.syncWithPreferences() }

            row("Reporting period") {
                Picker("", selection: $period) {
                    ForEach(AgentPeriod.allCases) { period in
                        Text(period.rawValue.capitalized).tag(period.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            row("Plan limits show") {
                Picker("", selection: $limitDisplay) {
                    ForEach(NotchAgentLimitDisplay.allCases) { display in
                        Text(display.title).tag(display.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            row("Daily budget") {
                Picker("", selection: $dailyBudget) {
                    Text("Off").tag(0.0)
                    ForEach(NotchAgentSupport.budgets.filter { $0 > 0 }, id: \.self) { value in
                        Text("$\(Int(value))").tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            row("Limit warning at") {
                Picker("", selection: $limitThreshold) {
                    Text("Off").tag(0.0)
                    ForEach(NotchAgentSupport.limitThresholds, id: \.self) { value in
                        Text("\(Int(value))% used").tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            row("Finished turns after") {
                Picker("", selection: $finishMinimum) {
                    Text("Every turn").tag(0.0)
                    ForEach(NotchAgentSupport.finishMinimums.filter { $0 > 0 }, id: \.self) { value in
                        Text(value < 60 ? "\(Int(value)) seconds" : "\(Int(value / 60)) min").tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            ForEach(AgentProvider.allCases) { provider in
                Toggle(isOn: Binding(
                    get: { providers[provider] ?? true },
                    set: { value in
                        providers[provider] = value
                        UserDefaults.standard.set(value, forKey: "arrowslit.agents.provider.\(provider.rawValue)")
                        AgentUsageService.shared.syncWithPreferences()
                    }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: provider.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(provider.tint)
                            .frame(width: 20)
                        Text(provider.displayName)
                            .font(ArrowTheme.settingsBody)
                            .foregroundStyle(ArrowTheme.bone)
                        Spacer(minLength: 8)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
        }
        .onAppear {
            for provider in AgentProvider.allCases {
                providers[provider] = UserDefaults.standard.object(forKey: "arrowslit.agents.provider.\(provider.rawValue)") as? Bool ?? true
            }
        }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(ArrowTheme.settingsBody)
                .foregroundStyle(ArrowTheme.bone)
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

// MARK: - Timer

struct TimerDefaultsSettingsSection: View {
    @Bindable var state: AppState

    var body: some View {
        SettingsSection(
            title: "Timer defaults",
            note: "The values the Timer page opens with. A running timer keeps its own duration."
        ) {
            stepper("Timer", value: Binding(
                get: { state.timer.panelMinutes },
                set: { state.timer.panelMinutes = $0 }
            ), range: RulerMath.timerRange)
            stepper("Pomodoro focus", value: Binding(
                get: { state.timer.focusMinutes },
                set: { state.timer.focusMinutes = $0 }
            ), range: RulerMath.focusRange)
            stepper("Pomodoro break", value: Binding(
                get: { state.timer.breakMinutes },
                set: { state.timer.breakMinutes = $0 }
            ), range: 1...60)
            SettingsToggle(
                title: "Play a sound when a timer ends",
                isOn: Binding(
                    get: { state.settings.timerSound },
                    set: { state.setTimerSound($0) }
                )
            )
        }
    }

    private func stepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(ArrowTheme.settingsBody)
                .foregroundStyle(ArrowTheme.bone)
            Spacer(minLength: 8)
            Text("\(value.wrappedValue) min")
                .font(ArrowTheme.settingsBody)
                .monospacedDigit()
                .foregroundStyle(ArrowTheme.muted)
                .frame(width: 70, alignment: .trailing)
            Stepper("", value: value, in: range)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

// MARK: - Launcher shortcuts

struct LauncherShortcutsSettingsSection: View {
    @Bindable var state: AppState
    private let tabs: [WorkbenchTab] = [
        .nowPlaying, .timer, .stopwatch, .calendar, .sports,
        .reminders, .clipboard, .tray, .notes, .mirror, .keepAwake, .stats, .agents
    ]

    var body: some View {
        SettingsSection(
            title: "Launcher shortcuts",
            note: "The keys shown under a launcher tile. Up to \(SettingsStore.shortcutLimit) at a time; you can also hold a tile to edit them."
        ) {
            ForEach(tabs) { tab in
                Toggle(isOn: Binding(
                    get: { state.settings.isShortcut(tab) },
                    set: { value in
                        guard value != state.settings.isShortcut(tab) else { return }
                        _ = state.settings.toggleShortcut(tab)
                    }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ArrowTheme.amber)
                            .frame(width: 20)
                        Text(tab.title)
                            .font(ArrowTheme.settingsBody)
                            .foregroundStyle(ArrowTheme.bone)
                        Spacer(minLength: 8)
                        if let label = tab.shortcutLabel {
                            Text(label)
                                .font(ArrowTheme.caption)
                                .foregroundStyle(ArrowTheme.faint)
                        }
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
        }
    }
}

// MARK: - Downloads

struct DownloadsFolderSettingsSection: View {
    @Bindable var state: AppState

    private var folderName: String {
        state.settings.downloadsFolderURL.lastPathComponent
    }

    private var isDefault: Bool {
        state.settings.downloadsFolderPath == nil
    }

    var body: some View {
        SettingsSection(
            title: "Download folder",
            note: "Arrowslit watches this folder for finished downloads and browser progress."
        ) {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ArrowTheme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text(folderName)
                        .font(ArrowTheme.settingsBody)
                        .foregroundStyle(ArrowTheme.bone)
                    Text(state.settings.downloadsFolderURL.path)
                        .font(ArrowTheme.caption)
                        .foregroundStyle(ArrowTheme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Button("Choose…", action: chooseFolder)
                    .buttonStyle(NookPressStyle())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                if !isDefault {
                    Button("Use Downloads") { state.setDownloadsFolder(nil) }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ArrowTheme.muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = state.settings.downloadsFolderURL
        panel.prompt = "Watch"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.setDownloadsFolder(url.path)
    }
}

// MARK: - Clipboard

struct ClipboardSettingsSection: View {
    @Bindable var state: AppState

    var body: some View {
        SettingsSection(
            title: "Clipboard",
            note: "History stays in memory. Pinned clips, and images you pin, are the only ones written to disk."
        ) {
            HStack(spacing: 12) {
                Text("Keep")
                    .font(ArrowTheme.settingsBody)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 8)
                Picker("", selection: Binding(
                    get: { state.settings.clipboardCapacity },
                    set: { state.setClipboardCapacity($0) }
                )) {
                    ForEach([10, 20, 50, 100], id: \.self) { value in
                        Text("\(value) clips").tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            SettingsToggle(
                title: "Copy images and files",
                detail: "Show image previews and file cards in the shelf, not just text.",
                isOn: Binding(
                    get: { state.clipboard.capturesRichContent },
                    set: { state.clipboard.setCapturesRichContent($0) }
                )
            )

            SettingsToggle(
                title: "Ignore passwords and transient clips",
                detail: "Leaves out password managers and pasteboard items macOS marks private.",
                isOn: Binding(
                    get: { state.settings.clipboardIgnoreConfidential },
                    set: { state.setClipboardIgnoreConfidential($0) }
                )
            )

            HStack(spacing: 12) {
                Text("\(state.clipboard.entries.count) clips · \(state.clipboard.pinnedCount) pinned")
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                Spacer(minLength: 8)
                Button("Open shelf") {
                    state.onOpenClipboardShelf?()
                    state.collapse()
                }
                .buttonStyle(NookPressStyle())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ArrowTheme.bone)
                Button("Clear history") { state.clipboard.clear() }
                    .buttonStyle(NookPressStyle())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ArrowTheme.red)
                    .disabled(state.clipboard.entries.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }
}

// MARK: - Camera

struct CameraSettingsSection: View {
    @Bindable var state: AppState
    @State private var devices: [CameraAccess.Device] = []

    private var selected: String {
        state.settings.cameraDeviceID ?? "default"
    }

    var body: some View {
        SettingsSection(
            title: "Camera preview",
            note: "Used by Camera Mirror before a call. Nothing is recorded."
        ) {
            HStack(spacing: 12) {
                Text("Camera")
                    .font(ArrowTheme.settingsBody)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 8)
                Picker("", selection: Binding(
                    get: { selected },
                    set: { value in
                        state.settings.cameraDeviceID = value == "default" ? nil : value
                    }
                )) {
                    Text("Default camera").tag("default")
                    ForEach(devices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .labelsHidden()
                .frame(width: 210)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            SettingsToggle(
                title: "Mirror the preview",
                isOn: Binding(
                    get: { state.settings.cameraMirrored },
                    set: { state.settings.cameraMirrored = $0 }
                )
            )

            HStack(spacing: 12) {
                Text("Quality")
                    .font(ArrowTheme.settingsBody)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 8)
                Picker("", selection: Binding(
                    get: { state.settings.cameraQuality },
                    set: { state.settings.cameraQuality = $0 }
                )) {
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 190)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .onAppear { devices = CameraAccess.devices }
    }
}

// MARK: - Stats

struct StatsSettingsSection: View {
    @Bindable var state: AppState

    var body: some View {
        SettingsSection(
            title: "Stats",
            note: "Which tiles the Stats page shows, and how often it samples."
        ) {
            HStack(spacing: 12) {
                Text("Refresh")
                    .font(ArrowTheme.settingsBody)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 8)
                Picker("", selection: Binding(
                    get: { state.settings.statsRefreshSeconds },
                    set: { state.setStatsRefreshSeconds($0) }
                )) {
                    Text("1s").tag(1.0)
                    Text("2s").tag(2.0)
                    Text("5s").tag(5.0)
                    Text("10s").tag(10.0)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            ForEach([("cpu", "CPU"), ("memory", "Memory"), ("disk", "Disk"), ("network", "Network")], id: \.0) { metric in
                Toggle(isOn: Binding(
                    get: { state.settings.statsMetrics.contains(metric.0) },
                    set: { value in
                        var metrics = Set(state.settings.statsMetrics)
                        if value { metrics.insert(metric.0) } else { metrics.remove(metric.0) }
                        state.setStatsMetrics(Array(metrics).sorted())
                    }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: metricSymbol(metric.0))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ArrowTheme.amber)
                            .frame(width: 20)
                        Text(metric.1)
                            .font(ArrowTheme.settingsBody)
                            .foregroundStyle(ArrowTheme.bone)
                        Spacer(minLength: 8)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
        }
    }

    private func metricSymbol(_ id: String) -> String {
        switch id {
        case "cpu": "cpu"
        case "memory": "memorychip"
        case "disk": "internaldrive"
        default: "network"
        }
    }
}

// MARK: - Keep Awake

struct KeepAwakeSettingsSection: View {
    @Bindable var state: AppState

    var body: some View {
        SettingsSection(
            title: "Keep Awake",
            note: "The next session uses these settings. A running session keeps its current choices."
        ) {
            HStack(spacing: 12) {
                Text("Run for")
                    .font(ArrowTheme.settingsBody)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 8)
                Picker("", selection: Binding(
                    get: { state.settings.keepAwakeMinutes },
                    set: { state.settings.keepAwakeMinutes = $0 }
                )) {
                    Text("Until turned off").tag(0)
                    ForEach([15, 30, 60, 120, 240], id: \.self) { minutes in
                        Text(minutes < 60 ? "\(minutes) min" : "\(minutes / 60) hr").tag(minutes)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            SettingsToggle(
                title: "Allow the display to sleep",
                detail: "The Mac stays awake; the screen may turn off.",
                isOn: Binding(
                    get: { state.settings.keepAwakeAllowDisplaySleep },
                    set: { state.settings.keepAwakeAllowDisplaySleep = $0 }
                )
            )
            SettingsToggle(
                title: "Allow disks to sleep",
                detail: "Keeps idle disks awake only while this is off.",
                isOn: Binding(
                    get: { state.settings.keepAwakeAllowDiskSleep },
                    set: { state.settings.keepAwakeAllowDiskSleep = $0 }
                )
            )
        }
    }
}

// MARK: - Reminders

struct RemindersSettingsSection: View {
    @Bindable var state: AppState
    @State private var lists: [ReminderCalendar] = []

    var body: some View {
        SettingsSection(
            title: "Reminders",
            note: "Which lists the notch reads. Today's reminders still appear on their own page."
        ) {
            SettingsToggle(
                title: "Show completed reminders",
                isOn: Binding(
                    get: { state.settings.remindersShowCompleted },
                    set: { state.setRemindersShowCompleted($0) }
                )
            )
            if state.reminders.access == .granted {
                ForEach(lists) { list in
                    Toggle(isOn: Binding(
                        get: { !state.settings.remindersExcludedIDs.contains(list.id) },
                        set: { value in
                            var excluded = Set(state.settings.remindersExcludedIDs)
                            if value { excluded.remove(list.id) } else { excluded.insert(list.id) }
                            state.setRemindersExcluded(Array(excluded))
                        }
                    )) {
                        Text(list.title)
                            .font(ArrowTheme.settingsBody)
                            .foregroundStyle(ArrowTheme.bone)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
            } else {
                Text("Connect Reminders in Access to choose lists.")
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
            }
        }
        .onAppear { lists = state.reminders.calendars() }
        .onChange(of: state.reminders.access) { _, _ in lists = state.reminders.calendars() }
    }
}

// MARK: - Calendar

struct CalendarSettingsSection: View {
    @Bindable var state: AppState
    @State private var lists: [CalendarChoice] = []

    var body: some View {
        SettingsSection(
            title: "Calendar",
            note: "The lead time for reminders and which calendars feed the notch. The calendar still yields to calls, playing media and live sports."
        ) {
            HStack(spacing: 12) {
                Text("Remind me")
                    .font(ArrowTheme.settingsBody)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 8)
                Picker("", selection: Binding(
                    get: { state.settings.calendarLeadMinutes },
                    set: { state.setCalendarLeadMinutes($0) }
                )) {
                    Text("At start").tag(0)
                    ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                        Text("\(minutes) min before").tag(minutes)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            if state.calendar.access == .granted {
                ForEach(lists) { list in
                    Toggle(isOn: Binding(
                        get: { !state.settings.calendarExcludedIDs.contains(list.id) },
                        set: { value in
                            var excluded = Set(state.settings.calendarExcludedIDs)
                            if value { excluded.remove(list.id) } else { excluded.insert(list.id) }
                            state.setCalendarExcluded(Array(excluded))
                        }
                    )) {
                        Text(list.title)
                            .font(ArrowTheme.settingsBody)
                            .foregroundStyle(ArrowTheme.bone)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
            } else {
                Text("Connect Calendar in Access to choose calendars.")
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
            }
        }
        .onAppear { lists = state.calendar.calendars() }
        .onChange(of: state.calendar.access) { _, _ in lists = state.calendar.calendars() }
    }
}

// MARK: - Sports teams and pins

struct SportsFollowSettingsSection: View {
    @Bindable var state: AppState

    private var teams: [SportsTeam] {
        var seen = Set<String>()
        return (state.sports.matches + state.sports.availableMatches)
            .flatMap { [$0.home, $0.away] }
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var pinOptions: [SportsMatch] {
        var seen = Set<String>()
        return (state.sports.matches + state.sports.availableMatches)
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        SettingsSection(
            title: "Followed teams & pinned match",
            note: "Followed teams shape the Sports page and goal alerts. A pinned match takes the notch before other live matches."
        ) {
            HStack(spacing: 12) {
                Text("Pinned match")
                    .font(ArrowTheme.settingsBody)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 8)
                Picker("", selection: Binding(
                    get: { state.settings.sportsPinnedMatchID ?? "none" },
                    set: { value in
                        state.sports.setPinnedMatch(value == "none" ? nil : value)
                    }
                )) {
                    Text("None").tag("none")
                    ForEach(pinOptions) { match in
                        Text("\(match.home.shortName) vs \(match.away.shortName)").tag(match.id)
                    }
                    if let id = state.settings.sportsPinnedMatchID,
                       !pinOptions.contains(where: { $0.id == id }) {
                        Text("Pinned match (not loaded)").tag(id)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            if teams.isEmpty {
                Text("Load the Sports page once to list teams.")
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
            } else {
                ForEach(teams) { team in
                    Toggle(isOn: Binding(
                        get: { state.sports.isFollowing(team) },
                        set: { value in
                            guard value != state.sports.isFollowing(team) else { return }
                            state.sports.toggleFollow(team)
                        }
                    )) {
                        HStack(spacing: 10) {
                            Text(team.shortName)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(ArrowTheme.amber)
                                .frame(width: 34, alignment: .leading)
                            Text(team.name)
                                .font(ArrowTheme.settingsBody)
                                .foregroundStyle(ArrowTheme.bone)
                            Spacer(minLength: 8)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
            }
        }
        .onAppear { state.sports.refresh() }
    }
}

// MARK: - HUD and battery

struct HudDurationSettingsSection: View {
    @Bindable var state: AppState

    var body: some View {
        SettingsSection(
            title: "Feedback duration",
            note: "How long quiet, non-interactive feedback stays in the notch. Urgent prompts keep their own time."
        ) {
            HStack(spacing: 12) {
                Text("Length")
                    .font(ArrowTheme.settingsBody)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 8)
                Picker("", selection: Binding(
                    get: { state.settings.hudDurationScale },
                    set: { state.setHudDurationScale($0) }
                )) {
                    Text("Short").tag(0.6)
                    Text("Standard").tag(1.0)
                    Text("Long").tag(1.5)
                    Text("Extra long").tag(2.0)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 320)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }
}

struct BatteryThresholdsSettingsSection: View {
    @Bindable var state: AppState

    var body: some View {
        SettingsSection(
            title: "Battery warnings",
            note: "System battery only. Accessory connection feedback has no battery threshold because macOS does not expose accessory charge here."
        ) {
            HStack(spacing: 12) {
                Text("Warn at")
                    .font(ArrowTheme.settingsBody)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 8)
                Picker("", selection: Binding(
                    get: { state.settings.batteryWarningLevel },
                    set: { value in
                        state.settings.batteryWarningLevel = value
                        if state.settings.batteryCriticalLevel >= value,
                           let critical = [15, 10, 5].first(where: { $0 < value }) {
                            state.settings.batteryCriticalLevel = critical
                        }
                    }
                )) {
                    ForEach([30, 20, 15], id: \.self) { value in
                        Text("\(value)%").tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            HStack(spacing: 12) {
                Text("Critical at")
                    .font(ArrowTheme.settingsBody)
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 8)
                Picker("", selection: Binding(
                    get: { state.settings.batteryCriticalLevel },
                    set: { state.settings.batteryCriticalLevel = $0 }
                )) {
                    ForEach([15, 10, 5].filter { $0 < state.settings.batteryWarningLevel }, id: \.self) { value in
                        Text("\(value)%").tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }
}

// MARK: - Command Center

struct CommandCenterSettingsSection: View {
    @Bindable var state: AppState

    var body: some View {
        SettingsSection(
            title: "Command Center",
            note: "The panel that opens from the menu-bar Arrowslit icon. Right-click still opens the short menu."
        ) {
            SettingsToggle(
                title: "Open from the menu-bar icon",
                detail: "Left-click opens the Command Center; right-click opens the short menu.",
                isOn: Binding(
                    get: { state.settings.commandCenterEnabled },
                    set: { state.settings.commandCenterEnabled = $0 }
                )
            )
            SettingsToggle(
                title: "Show Now Playing",
                isOn: Binding(
                    get: { state.settings.commandCenterPlayer },
                    set: { state.settings.commandCenterPlayer = $0 }
                )
            )
            SettingsToggle(
                title: "Show Upcoming",
                isOn: Binding(
                    get: { state.settings.commandCenterUpcoming },
                    set: { state.settings.commandCenterUpcoming = $0 }
                )
            )
            SettingsToggle(
                title: "Show System tab",
                isOn: Binding(
                    get: { state.settings.commandCenterSystem },
                    set: { state.settings.commandCenterSystem = $0 }
                )
            )
            SettingsToggle(
                title: "Show appearance tile",
                detail: "The sun or moon tile switches macOS between light and dark.",
                isOn: Binding(
                    get: { state.settings.commandCenterAppearanceTile },
                    set: { state.settings.commandCenterAppearanceTile = $0 }
                )
            )
            Button {
                state.onOpenCommandCenter?()
                state.collapse()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ArrowTheme.amber)
                        .frame(width: 20)
                    Text("Open Command Center")
                        .font(ArrowTheme.settingsBody)
                        .foregroundStyle(ArrowTheme.bone)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ArrowTheme.faint)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .contentShape(Rectangle())
            }
            .buttonStyle(NookPressStyle())
        }
    }
}

// MARK: - Capture

struct CaptureSettingsSection: View {
    @Bindable var state: AppState

    private var folderName: String { state.settings.captureFolderURL.lastPathComponent }

    var body: some View {
        SettingsSection(
            title: "Capture",
            note: "Area, window, fullscreen and text capture live in the Command Center's Capture tab. Each capture opens a floating card with Copy, Save, Pin, Annotate and OCR. The first capture asks for Screen Recording access."
        ) {
            SettingsToggle(
                title: "Copy after capture",
                detail: "Put the screenshot or recognised text on the clipboard immediately.",
                isOn: Binding(
                    get: { state.settings.captureCopy },
                    set: { state.settings.captureCopy = $0 }
                )
            )
            SettingsToggle(
                title: "Include the pointer",
                isOn: Binding(
                    get: { state.settings.captureIncludeCursor },
                    set: { state.settings.captureIncludeCursor = $0 }
                )
            )
            SettingsToggle(
                title: "Play the screenshot sound",
                detail: "The macOS capture sound when a screenshot is taken.",
                isOn: Binding(
                    get: { state.settings.captureSound },
                    set: { state.settings.captureSound = $0 }
                )
            )
            SettingsToggle(
                title: "Hide capture controls until hover",
                detail: "Show the screenshot first; move the pointer over it for Copy, Save, Pin, Annotate and OCR.",
                isOn: Binding(
                    get: { state.settings.captureAutoHideControls },
                    set: { state.settings.captureAutoHideControls = $0 }
                )
            )
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ArrowTheme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text(folderName).font(ArrowTheme.settingsBody).foregroundStyle(ArrowTheme.bone)
                    Text(state.settings.captureFolderURL.path)
                        .font(ArrowTheme.caption)
                        .foregroundStyle(ArrowTheme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Button("Choose…", action: chooseFolder)
                    .buttonStyle(NookPressStyle())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                if state.settings.captureFolderPath != nil {
                    Button("Desktop") { state.settings.captureFolderPath = nil }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ArrowTheme.muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            HStack(spacing: 10) {
                Button {
                    state.onCapture?(.fullscreen)
                } label: {
                    Label("Capture now", systemImage: "camera.viewfinder")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Capsule().fill(ArrowTheme.amber.opacity(0.18)))
                }
                .buttonStyle(NookPressStyle())
                Button("Screen Recording access") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(ArrowTheme.muted)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = state.settings.captureFolderURL
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.settings.captureFolderPath = url.path
    }
}


// MARK: - Permissions

struct PermissionsSettingsSection: View {
    @Bindable var state: AppState
    @State private var permissions = PermissionsCenter()

    var body: some View {
        SettingsSection(
            title: "Permissions",
            note: "macOS manages these. Arrowslit appears in Privacy & Security after you request a permission; you can change every switch here or in System Settings."
        ) {
            VStack(spacing: 0) {
                ForEach(Array(PermissionKind.allCases.enumerated()), id: \.element) { index, kind in
                    if index > 0 {
                        Divider().opacity(0.35)
                    }
                    row(kind)
                }

                Divider().opacity(0.35)

                HStack(spacing: 10) {
                    Button {
                        Task { await permissions.requestAll() }
                    } label: {
                        Label(permissions.isRequesting ? "Requesting…" : "Grant All", systemImage: "checkmark.shield.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ArrowTheme.bone)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(ArrowTheme.amber.opacity(0.16))
                            )
                    }
                    .buttonStyle(NookPressStyle())
                    .disabled(permissions.isRequesting)

                    Spacer(minLength: 8)

                    Button("Open Privacy & Security") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5))
                    .foregroundStyle(ArrowTheme.muted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                if let message = permissions.automationMessage {
                    Text(message)
                        .font(ArrowTheme.caption)
                        .foregroundStyle(ArrowTheme.amber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 9)
                }
            }
        }
        .task { await permissions.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await permissions.refresh() }
        }
    }

    private func row(_ kind: PermissionKind) -> some View {
        let status = permissions.status(for: kind)
        return HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ArrowTheme.amber)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(ArrowTheme.settingsBody)
                    .fontWeight(.medium)
                    .foregroundStyle(ArrowTheme.bone)
                Text(kind.detail)
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            statusView(kind, status: status)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    @ViewBuilder private func statusView(_ kind: PermissionKind, status: PermissionStatus) -> some View {
        if status.isGranted {
            Label("Allowed", systemImage: "checkmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ArrowTheme.green)
                .labelStyle(.titleAndIcon)
        } else {
            Button(status == .denied || status == .restricted || status == .limited ? "Open Settings" : "Grant") {
                if status == .denied || status == .restricted || status == .limited {
                    permissions.openSettings(for: kind)
                } else {
                    Task { await permissions.request(kind) }
                }
            }
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
        }
    }
}
