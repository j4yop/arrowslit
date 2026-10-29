import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    private let featureTabs: [WorkbenchTab] = [
        .nowPlaying, .timer, .stopwatch, .calendar,
        .clipboard, .keepAwake, .mirror, .notes, .stats
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SlitMark(height: 26)
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
        }
        .frame(width: 540, height: 620)
        .background(ArrowTheme.ink)
        .onAppear { syncLogin() }
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
                    .fill(Color.white.opacity(isOn ? 0.07 : 0.03))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
