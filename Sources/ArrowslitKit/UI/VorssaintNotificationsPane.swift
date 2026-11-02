import AppKit
import SwiftUI

struct VorssaintNotificationsPane: View {
    @Bindable var state: AppState
    @StateObject private var system = NotchNotificationService.shared

    private var total: Int { system.items.count + state.alertHistory.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneHeader("Notifications") {
                HStack(spacing: 7) {
                    Circle()
                        .fill(system.monitoring ? ArrowTheme.green : ArrowTheme.muted)
                        .frame(width: 5, height: 5)
                    Text(system.monitoring ? "Mirroring" : "Paused")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(system.monitoring ? ArrowTheme.green : .white.opacity(0.4))
                    Text("\(total)")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.4))
                    if total > 0 {
                        Button("Clear") {
                            system.clearAll()
                            state.clearAlertHistory()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(ArrowTheme.amber)
                    }
                }
            }

            if !system.items.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(system.items.prefix(20)) { item in
                            systemRow(item)
                        }
                    }
                }
            } else if !state.alertHistory.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(state.alertHistory.prefix(20)) { item in
                            alertRow(item)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    VorssaintPageEmpty(
                        symbol: "bell",
                        title: system.monitoring ? "No new notifications" : "Notifications are paused",
                        detail: system.monitoring
                            ? "New banners appear here and in the closed notch."
                            : "Allow Accessibility in System Settings, then open this page again."
                    )
                    if !system.monitoring {
                        Button("Open Accessibility Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(ArrowTheme.amber)
                    }
                }
            }
        }
        .padding(.top, 2)
        .onAppear { system.syncWithPreferences() }
    }

    private func systemRow(_ item: NotchSystemNotification) -> some View {
        HStack(spacing: 9) {
            Group {
                if let icon = system.icon(for: item.content.app) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArrowTheme.blue)
                }
            }
            .frame(width: 24, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.content.compactTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Text(item.content.compactDetail.isEmpty ? item.content.app : item.content.compactDetail)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(item.received, style: .relative)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
            Button {
                system.dismiss(item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onTapGesture {
            system.open(item.id) { _ in }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.content.app). \(item.content.compactTitle). \(item.content.compactDetail)")
    }

    private func alertRow(_ item: AlertHistoryItem) -> some View {
        HStack(spacing: 9) {
            Image(systemName: item.alert.vorssaintSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(item.alert.vorssaintTint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(item.alert.vorssaintTint.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.alert.vorssaintTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Text(item.alert.vorssaintDetail)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(item.date, style: .relative)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
    }
}

extension NotchAlert {
    var vorssaintTitle: String {
        switch self {
        case .upcomingEvent(let title, _, _, _): title
        case .timerFinished: "Timer finished"
        case .charging(let level, let charging): charging ? "Charging · \(level)%" : "Connected · \(level)%"
        case .lowBattery(let level): "Low battery · \(level)%"
        case .headphones(let name): "Connected · \(name)"
        case .download(let name): "Download · \(name)"
        case .update(let version): "Update \(version) available"
        case .welcome(let name): "Welcome, \(name)"
        case .sportsGoal(let goal): "\(goal.teamShortName) scored"
        case .shortcut(let name, let succeeded): succeeded ? "\(name) finished" : "\(name) failed"
        case .agentRequest(let request): "\(request.kind.displayName) · \(request.title)"
        case .level(let kind, let value, let muted): "\(kind == .volume ? "Volume" : "Brightness") · \(muted ? "Muted" : "\(Int((value * 100).rounded()))%")"
        case .systemNotification(let app, let title, _): title.isEmpty ? app : title
        }
    }

    var vorssaintDetail: String {
        switch self {
        case .upcomingEvent(_, let startsAt, _, _):
            startsAt.formatted(date: .omitted, time: .shortened)
        case .timerFinished: "Your countdown reached zero"
        case .charging(_, let charging): charging ? "Power connected" : "Power adapter connected"
        case .lowBattery: "Plug in when you can"
        case .headphones: "Audio output changed"
        case .download: "Finished downloading"
        case .update: "Open Settings › About to install"
        case .welcome: "Arrowslit is ready in the notch"
        case .sportsGoal(let goal): "\(goal.homeShortName) \(goal.homeScore) – \(goal.awayScore) \(goal.awayShortName)"
        case .shortcut: "Shortcut result"
        case .agentRequest(let request): "\(request.project) · \(request.detail)"
        case .level: "System level changed"
        case .systemNotification(let app, _, let detail): detail.isEmpty ? app : detail
        }
    }

    var vorssaintSymbol: String {
        switch self {
        case .upcomingEvent: "calendar"
        case .timerFinished: "timer"
        case .charging, .lowBattery: "bolt.fill"
        case .headphones: "headphones"
        case .download: "arrow.down.circle"
        case .update: "arrow.down.app"
        case .welcome: "hand.wave"
        case .sportsGoal: "soccerball"
        case .shortcut: "command"
        case .agentRequest: "sparkles"
        case .level(let kind, _, _): kind == .volume ? "speaker.wave.2" : "sun.max"
        case .systemNotification: "bell.fill"
        }
    }

    var vorssaintTint: Color {
        switch self {
        case .timerFinished: ArrowTheme.amber
        case .charging: ArrowTheme.green
        case .lowBattery: ArrowTheme.red
        case .update: ArrowTheme.blue
        case .sportsGoal: ArrowTheme.green
        case .agentRequest: Color(red: 0.78, green: 0.66, blue: 1)
        case .level(let kind, _, _): kind == .volume ? ArrowTheme.blue : ArrowTheme.yellow
        case .systemNotification: ArrowTheme.blue
        default: .white.opacity(0.8)
        }
    }
}
