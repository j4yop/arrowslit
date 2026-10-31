import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    private let featureTabs: [WorkbenchTab] = [
        .nowPlaying, .timer, .stopwatch, .calendar,
        .clipboard, .keepAwake, .mirror, .notes, .stats, .reminders
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(ArrowTheme.hairline)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
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
                            ForEach(featureTabs) { tab in
                                FeatureSelectionButton(state: state, tab: tab)
                            }
                        }
                        .padding(6)
                    }

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
                        title: "Interface",
                        note: "How the notch behaves while you work."
                    ) {
                        SettingsToggle(
                            title: "Open Settings on launch",
                            detail: "Show this window when Arrowslit starts.",
                            isOn: Binding(
                                get: { state.settings.openSettingsOnLaunch },
                                set: { state.settings.openSettingsOnLaunch = $0 }
                            )
                        )
                        SettingsRowDivider()
                        SettingsToggle(
                            title: "Open notch on hover",
                            detail: "Hold the pointer over the strip for a moment.",
                            isOn: Binding(
                                get: { state.settings.openOnHover },
                                set: { state.settings.openOnHover = $0 }
                            )
                        )
                        SettingsRowDivider()
                        SettingsToggle(
                            title: "Collapse when the pointer leaves",
                            detail: "Close the notch after a short pause.",
                            isOn: Binding(
                                get: { state.settings.collapseOnLeave },
                                set: { state.settings.collapseOnLeave = $0 }
                            )
                        )
                        SettingsRowDivider()
                        SettingsToggle(
                            title: "Haptic feedback",
                            detail: "A small tap when the notch opens.",
                            isOn: Binding(
                                get: { state.settings.hapticFeedback },
                                set: { state.settings.hapticFeedback = $0 }
                            )
                        )
                        SettingsRowDivider()
                        SettingsToggle(
                            title: "Show menu bar icon",
                            detail: "Keep a small slit in the menu bar.",
                            isOn: Binding(
                                get: { state.settings.showMenuBarIcon },
                                set: { state.setMenuBarIconVisible($0) }
                            )
                        )
                        SettingsRowDivider()
                        SettingsToggle(
                            title: "Open at login",
                            detail: "Start Arrowslit when you sign in.",
                            isOn: $launchAtLogin
                        )
                        .onChange(of: launchAtLogin) { _, value in
                            setLaunchAtLogin(value)
                        }
                        if let loginError {
                            SettingsRowDivider()
                            Text(loginError)
                                .font(ArrowTheme.caption)
                                .foregroundStyle(ArrowTheme.red)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
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
                        SettingsRowDivider()
                        AccessStatusRow(
                            title: "Reminders",
                            symbol: "checklist",
                            detail: remindersDetail,
                            tint: remindersTint,
                            granted: state.reminders.access == .granted,
                            actionTitle: remindersActionTitle,
                            action: remindersAction
                        )
                        SettingsRowDivider()
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

                    SettingsSection(
                        title: "Updates",
                        note: "Checks github.com once a day. No account or tracking."
                    ) {
                        SettingsToggle(
                            title: "Check for updates automatically",
                            detail: "Once a day, ask GitHub for the latest release.",
                            isOn: Binding(
                                get: { state.settings.checksForUpdates },
                                set: { state.setChecksForUpdates($0) }
                            )
                        )
                        SettingsRowDivider()
                        UpdateStatusRow(state: state)
                    }

                    SettingsSection(title: "About") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arrowslit")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ArrowTheme.bone)
                            Text("Version \(version)")
                                .font(ArrowTheme.detail)
                                .foregroundStyle(ArrowTheme.muted)
                            Text("Local-first. No account or analytics. Update checks contact GitHub; lyrics are optional.")
                                .font(ArrowTheme.detail)
                                .foregroundStyle(ArrowTheme.muted)
                            Text("GPL-3.0 · © 2026 Jay Gopal and contributors")
                                .font(ArrowTheme.caption)
                                .foregroundStyle(ArrowTheme.faint)
                                .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                }
                .padding(20)
            }
            .nookScrollBounce()
        }
        .frame(width: 540, height: 620)
        .background(ArrowTheme.ink)
        .onAppear { syncLogin() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Group {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 32, height: 32)
                } else {
                    SlitMark(height: 24)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Arrowslit")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                Text("Settings")
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
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
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                if let note {
                    Text(note)
                        .font(ArrowTheme.detail)
                        .foregroundStyle(ArrowTheme.muted)
                }
            }
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(ArrowTheme.hairline, lineWidth: 0.5)
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
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ArrowTheme.body)
                    .fontWeight(.medium)
                    .foregroundStyle(ArrowTheme.bone)
                Text(detail)
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(ArrowTheme.amber)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
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
            UpdateActionButton(title: "Download & Open", primary: true) {
                updater.downloadAndOpen(release)
            }
        case .downloaded(let url):
            UpdateActionButton(title: "Open DMG", primary: true) {
                NSWorkspace.shared.open(url)
            }
        case .failed:
            UpdateActionButton(title: "Try Again", primary: true) {
                if let release = updater.availableRelease {
                    updater.downloadAndOpen(release)
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
        case .checking, .downloading: "arrow.triangle.2.circlepath"
        case .downloaded, .upToDate: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .idle: "arrow.down.circle"
        }
    }

    private var tint: Color {
        switch updater.state {
        case .available, .downloading: ArrowTheme.amber
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
        case .upToDate: "You're up to date"
        case .failed: "Couldn't update"
        case .idle: "Arrowslit \(updater.currentVersion?.description ?? "0.0.0")"
        }
    }

    private var detail: String {
        switch updater.state {
        case .available: "Download the DMG, then drag Arrowslit into Applications."
        case .checking: "Contacting GitHub…"
        case .downloading(let progress): "\(Int((progress * 100).rounded()))% downloaded"
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
