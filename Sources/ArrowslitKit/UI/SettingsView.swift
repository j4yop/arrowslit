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
            HStack(spacing: 12) {
                Group {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 34, height: 34)
                    } else {
                        SlitMark(height: 26)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("ARROWSLIT")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(ArrowTheme.bone)
                    Text("SETTINGS")
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(ArrowTheme.amber)
                }
                Spacer()
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(ArrowTheme.faint)
            }
            .padding(.horizontal, 24)
            .frame(height: 74)

            Divider().overlay(ArrowTheme.hairline)

            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(ArrowTheme.green)
                    .frame(width: 6, height: 6)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Arrowslit is live in the notch")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                    Text("Hover the top of the screen, or click the slit in the menu bar. You can close this window; Arrowslit keeps running.")
                        .font(.system(size: 10))
                        .foregroundStyle(ArrowTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.035))

            Divider().overlay(ArrowTheme.hairline)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    SettingsSection(title: "LAUNCHER", note: "Choose which features appear in the grid. Clipboard history skips password-manager items.") {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            spacing: 8
                        ) {
                            ForEach(featureTabs) { tab in
                                FeatureSelectionButton(state: state, tab: tab)
                            }
                        }
                        .padding(10)
                    }

                    SettingsSection(title: "INTERFACE", note: "Keep Arrowslit close without taking over the menu bar.") {
                        SettingsToggle(
                            title: "Open Settings on launch",
                            detail: "Show this window when Arrowslit starts.",
                            isOn: Binding(
                                get: { state.settings.openSettingsOnLaunch },
                                set: { state.settings.openSettingsOnLaunch = $0 }
                            )
                        )
                        SettingsToggle(
                            title: "Open notch on hover",
                            detail: "Hold the pointer over the strip for 0.4 seconds.",
                            isOn: Binding(
                                get: { state.settings.openOnHover },
                                set: { state.settings.openOnHover = $0 }
                            )
                        )
                        SettingsToggle(
                            title: "Collapse when the pointer leaves",
                            detail: "Close the nook after a short pause outside it.",
                            isOn: Binding(
                                get: { state.settings.collapseOnLeave },
                                set: { state.settings.collapseOnLeave = $0 }
                            )
                        )
                        SettingsToggle(
                            title: "Haptic feedback",
                            detail: "A small tap when the notch opens.",
                            isOn: Binding(
                                get: { state.settings.hapticFeedback },
                                set: { state.settings.hapticFeedback = $0 }
                            )
                        )
                        SettingsToggle(
                            title: "Show menu bar icon",
                            detail: "A small slit in the menu bar. Turn it off to keep only the notch.",
                            isOn: Binding(
                                get: { state.settings.showMenuBarIcon },
                                set: { state.setMenuBarIconVisible($0) }
                            )
                        )
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
                                .font(.system(size: 10))
                                .foregroundStyle(ArrowTheme.red)
                        }
                    }

                    SettingsSection(title: "ACCESS", note: "macOS remembers these for the installed copy. Allow them once; Arrowslit never asks in the background.") {
                        AccessStatusRow(
                            title: "Calendar",
                            symbol: "calendar",
                            detail: calendarDetail,
                            tint: calendarTint,
                            actionTitle: calendarActionTitle,
                            action: calendarAction
                        )
                        Divider().overlay(ArrowTheme.hairline)
                        AccessStatusRow(
                            title: "Reminders",
                            symbol: "checklist",
                            detail: remindersDetail,
                            tint: remindersTint,
                            actionTitle: remindersActionTitle,
                            action: remindersAction
                        )
                        Divider().overlay(ArrowTheme.hairline)
                        AccessStatusRow(
                            title: "Camera",
                            symbol: "person.crop.square",
                            detail: cameraDetail,
                            tint: cameraTint,
                            actionTitle: cameraActionTitle,
                            action: cameraAction
                        )
                    }

                    SettingsSection(title: "ABOUT", note: "A narrow aperture. A wider day.") {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Arrowslit 0.1.0")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(ArrowTheme.bone)
                                Text("Local-only. No account, no analytics, no network.")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(ArrowTheme.muted)
                                Text("GPL-3.0 · © 2026 Jay Gopal and contributors")
                                    .font(.system(size: 10))
                                    .foregroundStyle(ArrowTheme.faint)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(24)
            }
            .nookScrollBounce()
        }
        .frame(width: 540, height: 620)
        .background(ArrowTheme.ink)
        .onAppear { syncLogin() }
    }

    private var calendarDetail: String {
        switch state.calendar.access {
        case .granted: "Allowed — your next event will appear in the notch"
        case .notAsked: "Not connected"
        case .denied: "Permission denied — open Privacy Settings"
        case .limited: "Limited access — open Privacy Settings"
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
        case .granted: "Allowed — today's to-dos appear in the notch"
        case .notAsked: "Not connected"
        case .denied: "Permission denied — open Privacy Settings"
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
        case .granted: "Allowed — local preview only"
        case .notAsked: "Not connected"
        case .denied: "Permission denied — open Privacy Settings"
        case .noCamera: "No camera found"
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
            loginError = "Could not change login item: \(error.localizedDescription)"
            syncLogin()
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let note: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(ArrowTheme.amber)
                Text(note)
                    .font(.system(size: 10.5))
                    .foregroundStyle(ArrowTheme.faint)
            }
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ArrowTheme.panel)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ArrowTheme.hairline, lineWidth: 0.5)
            }
        }
    }
}

private struct AccessStatusRow: View {
    let title: String
    let symbol: String
    let detail: String
    let tint: Color
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(ArrowTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(NookPressStyle())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ArrowTheme.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Capsule().fill(ArrowTheme.amber))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(ArrowTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(ArrowTheme.amber)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
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
            HStack(spacing: 6) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isOn ? ArrowTheme.amber : ArrowTheme.faint)
                    .frame(width: 16)
                Text(tab.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isOn ? ArrowTheme.bone : ArrowTheme.muted)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isOn ? ArrowTheme.amber : ArrowTheme.faint)
            }
            .padding(.horizontal, 9)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isOn ? (isHovering ? 0.1 : 0.07) : (isHovering ? 0.06 : 0.03)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle())
        .onHover { isHovering = $0 }
    }
}
