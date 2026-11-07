import AppKit
import SwiftUI

/// A short heads-up above the notch. The first wired alert is the calendar reminder; the other
/// cases are ready for the next activity layer.
struct NotchAlertView: View {
    @Bindable var state: AppState
    let alert: NotchAlert
    @Environment(\.panelGeometry) private var geometry

    var body: some View {
        if case .agentRequest(let request) = alert {
            AgentRequestView(state: state, request: request)
        } else {
            let size = state.panelSize(for: .alert(alert), geometry: geometry)
            LiveNoticeView(
                state: state,
                alert: alert,
                width: size.width,
                height: size.height,
                notchWidth: ParityLayout.notch(in: geometry).width
            )
            .frame(width: size.width, height: size.height)
            .background(NotchSurfaceBackground(
                appearance: state.settings.appearance,
                radius: 12,
                flare: 6,
                notchBand: geometry.notch?.height ?? 0
            ))
            .clipShape(SlitShape(radius: 12, flare: 6))
            .overlay {
                if !state.settings.appearance.pitchBlack {
                    SlitShape(radius: 12, flare: 6)
                        .stroke(ArrowTheme.hairline, lineWidth: 0.5)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: act)
            .help(help)
            .accessibilityElement(children: .combine)
            .accessibilityLabel([LiveNoticeMetrics.noticeTitle(alert, timerWasFocus: state.timer.lastWasFocus),
                                 LiveNoticeMetrics.noticeDetail(alert, timerWasFocus: state.timer.lastWasFocus)]
                .filter { !$0.isEmpty }.joined(separator: ". "))
        }
    }

    private var help: String {
        switch alert {
        case .upcomingEvent(_, _, let joinURL, _): joinURL == nil ? "Open Calendar" : "Join the meeting"
        case .download: "Show in Finder"
        case .update: "Install the update"
        case .track: "Open the player"
        case .timerFinished: "Open the timer"
        case .sportsGoal: "Open Sports"
        case .agentEvent: "Open AI Agents"
        default: "Dismiss"
        }
    }

    private func act() {
        switch alert {
        case .upcomingEvent(_, _, let joinURL, _):
            state.dismissAlert()
            if let joinURL { NSWorkspace.shared.open(joinURL) } else { state.expand(.calendar) }
        case .download:
            state.dismissAlert()
            if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                NSWorkspace.shared.open(downloads)
            }
        case .update:
            state.dismissAlert()
            if let release = state.updater.availableRelease {
                state.updater.downloadAndOpen(release)
            } else {
                state.onOpenSettings?()
            }
        case .track:
            state.dismissAlert()
            state.expand(.nowPlaying)
        case .timerFinished:
            state.dismissAlert()
            state.expand(.timer)
        case .sportsGoal:
            state.dismissAlert()
            state.expand(.sports)
        case .agentEvent:
            state.dismissAlert()
            state.expand(.agents)
        default:
            state.dismissAlert()
        }
    }
}
