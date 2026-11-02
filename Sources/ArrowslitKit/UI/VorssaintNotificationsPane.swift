import SwiftUI

struct VorssaintNotificationsPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneHeader("Notifications") {
                HStack(spacing: 7) {
                    Text("\(state.alertHistory.count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.45))
                    if !state.alertHistory.isEmpty {
                        Button("Clear") { state.clearAlertHistory() }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ArrowTheme.amber)
                    }
                }
            }

            if state.alertHistory.isEmpty {
                VorssaintPageEmpty(
                    symbol: "bell",
                    title: "No recent notices",
                    detail: "Calendar, timers, downloads, power and agent requests appear here as they arrive."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(state.alertHistory.prefix(20)) { item in
                            row(item)
                        }
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private func row(_ item: AlertHistoryItem) -> some View {
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
        default: .white.opacity(0.8)
        }
    }
}
