import AppKit
import SwiftUI

/// A short heads-up above the notch. The first wired alert is the calendar reminder; the other
/// cases are ready for the next activity layer.
struct NotchAlertView: View {
    @Bindable var state: AppState
    let alert: NotchAlert

    var body: some View {
        if case .sportsGoal(let goal) = alert {
            SportsGoalAlertView(state: state, goal: goal)
        } else {
            standardAlert
        }
    }

    private var standardAlert: some View {
        HStack(spacing: 14) {
            Image(systemName: presentation.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(presentation.tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                    .lineLimit(1)
                Text(presentation.detail)
                    .font(ArrowTheme.detail)
                    .foregroundStyle(ArrowTheme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            if case .upcomingEvent(_, _, let joinURL, let provider) = alert, let joinURL {
                Button(joinTitle(provider)) {
                    state.dismissAlert()
                    NSWorkspace.shared.open(joinURL)
                }
                .buttonStyle(NookPressStyle())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArrowTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(ArrowTheme.amber)
                )
            }

            if case .upcomingEvent = alert {
                Button("Calendar") {
                    state.dismissAlert()
                    state.expand(.calendar)
                }
                .buttonStyle(NookPressStyle())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ArrowTheme.bone)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(ArrowTheme.hairline, lineWidth: 0.5)
                }
            }

            if case .update = alert {
                Button("Download & Open") {
                    state.dismissAlert()
                    if let release = state.updater.availableRelease {
                        state.updater.downloadAndOpen(release)
                    } else {
                        state.onOpenSettings?()
                    }
                }
                .buttonStyle(NookPressStyle())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArrowTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(ArrowTheme.amber)
                )
                .help("Download and open the update")
            }

            Button {
                state.dismissAlert()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ArrowTheme.muted)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(NookPressStyle())
            .help("Dismiss")
            .accessibilityLabel("Dismiss alert")
        }
        .padding(.horizontal, 18)
        .frame(width: NotchPanelMetrics.alertSize.width, height: NotchPanelMetrics.alertSize.height)
        .background(ArrowTheme.ink)
        .clipShape(SlitShape(radius: 18))
        .overlay {
            SlitShape(radius: 18)
                .stroke(ArrowTheme.hairline, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
    }

    private var presentation: Presentation {
        switch alert {
        case .upcomingEvent(let title, let startsAt, _, let provider):
            let timing = CalendarRules.alertDetail(startsAt: startsAt, at: Date())
            let detail = provider.map { "\($0.displayName) · \(timing)" } ?? timing
            return Presentation(symbol: "calendar", title: title, detail: detail, tint: ArrowTheme.amber)
        case .timerFinished:
            return Presentation(symbol: "timer", title: "Timer done", detail: "Ready when you are.", tint: ArrowTheme.amber)
        case .charging(let level, let isCharging):
            return Presentation(
                symbol: "bolt.fill",
                title: "Charging",
                detail: isCharging ? "\(level)% · On power" : "\(level)% · Connected",
                tint: ArrowTheme.green
            )
        case .lowBattery(let level):
            return Presentation(symbol: "battery.25", title: "Low Battery", detail: "\(level)% left", tint: ArrowTheme.red)
        case .headphones(let name):
            return Presentation(symbol: "headphones", title: "Connected", detail: name, tint: ArrowTheme.green)
        case .download(let name):
            return Presentation(symbol: "arrow.down.circle", title: "Download finished", detail: name, tint: ArrowTheme.green)
        case .update(let version):
            return Presentation(symbol: "arrow.down.circle", title: "Update available", detail: "Version \(version)", tint: ArrowTheme.amber)
        case .welcome(let name):
            return Presentation(symbol: "hand.wave", title: "Hi \(name)", detail: "Arrowslit is running in the notch.", tint: ArrowTheme.amber)
        case .sportsGoal(let goal):
            return Presentation(
                symbol: "soccerball",
                title: "GOAL",
                detail: "\(goal.teamName) · \(goal.scoreLine)",
                tint: ArrowTheme.green
            )
        case .level(let kind, let value, let muted):
            let label = kind == .volume ? "Volume" : "Brightness"
            let detail = muted ? "Muted" : "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
            return Presentation(symbol: kind == .volume ? "speaker.wave.2" : "sun.max", title: label, detail: detail, tint: ArrowTheme.bone)
        }
    }

    private func joinTitle(_ provider: MeetingLinks.Provider?) -> String {
        guard let provider else { return "Join" }
        return "Join \(provider.displayName)"
    }

    private struct Presentation {
        var symbol: String
        var title: String
        var detail: String
        var tint: Color
    }
}


/// A goal gets a little more room than the other alerts: a ball, the scoring
/// team, the new score and a one-shot ring. The haptic fires from AppState.receive.
private struct SportsGoalAlertView: View {
    @Bindable var state: AppState
    let goal: SportsGoalEvent
    @State private var entered = false
    @State private var ring = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(ArrowTheme.green.opacity(0.35), lineWidth: 1)
                    .frame(width: 38, height: 38)
                    .scaleEffect(ring ? 1.45 : 0.85)
                    .opacity(ring ? 0 : 0.7)
                Circle()
                    .fill(ArrowTheme.green.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: "soccerball")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(ArrowTheme.green)
                    .rotationEffect(.degrees(entered ? 0 : -20))
                    .scaleEffect(entered ? 1 : 0.6)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("GOAL")
                    .font(.system(size: 9, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(ArrowTheme.green)
                Text(goal.teamName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(goal.scoreLine)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ArrowTheme.bone)
                    if let minute = goal.minute {
                        Text("· \(minute)")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(ArrowTheme.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            Button("Sports") {
                state.dismissAlert()
                state.expand(.sports)
            }
            .buttonStyle(NookPressStyle())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ArrowTheme.ink)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(ArrowTheme.green)
            )

            Button {
                state.dismissAlert()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ArrowTheme.muted)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(NookPressStyle())
            .help("Dismiss")
            .accessibilityLabel("Dismiss goal alert")
        }
        .padding(.horizontal, 18)
        .frame(width: NotchPanelMetrics.alertSize.width, height: NotchPanelMetrics.alertSize.height)
        .background(ArrowTheme.ink)
        .clipShape(SlitShape(radius: 18))
        .overlay {
            SlitShape(radius: 18)
                .stroke(ArrowTheme.green.opacity(0.25), lineWidth: 0.5)
        }
        .onAppear {
            guard !reduceMotion else {
                entered = true
                return
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                entered = true
            }
            withAnimation(.easeOut(duration: 0.65).delay(0.08)) {
                ring = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Goal. \(goal.teamName). \(goal.scoreLine).")
    }
}
