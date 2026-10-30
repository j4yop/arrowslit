import AppKit
import SwiftUI

/// A short heads-up above the notch. The first wired alert is the calendar reminder; the other
/// cases are ready for the next activity layer.
struct NotchAlertView: View {
    @Bindable var state: AppState
    let alert: NotchAlert

    var body: some View {
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
