import SwiftUI

struct CalendarPane: View {
    @Bindable var state: AppState
    private var calendar: CalendarService { state.calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneHeader("Calendar")

            switch calendar.access {
            case .notAsked:
                prompt(
                    "Show your next event here. Calendar data stays on this Mac.",
                    button: "Connect Calendar"
                ) { calendar.requestAccess() }
            case .denied, .limited:
                prompt(
                    "Calendar access is off. Turn it on in Privacy & Security.",
                    button: "Open Privacy Settings"
                ) { calendar.openPrivacySettings() }
            case .granted:
                if let event = calendar.nextEvent {
                    eventCard(event)
                } else {
                    empty
                }
            }
        }
    }

    private func eventCard(_ event: CalendarEvent) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ArrowTheme.amber)
                .frame(width: 3, height: 64)

            Button {
                calendar.open(event)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(1)
                    Text(CalendarRules.timeRange(for: event, at: Date()))
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(event.isHappening(at: Date()) ? ArrowTheme.green : ArrowTheme.muted)
                    Text(event.start.formatted(date: .complete, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundStyle(ArrowTheme.faint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(NookPressStyle())
            .help("Open in Calendar")

            if event.joinURL != nil {
                Button(joinTitle(event)) {
                    calendar.join(event)
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
                .help("Join the meeting")
            } else {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ArrowTheme.faint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ArrowTheme.panel)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ArrowTheme.hairline, lineWidth: 0.5)
        }
    }

    private func joinTitle(_ event: CalendarEvent) -> String {
        guard let provider = event.joinProvider else { return "Join" }
        return "Join \(provider.displayName)"
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(ArrowTheme.faint)
            Text("No events this week.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ArrowTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func prompt(_ message: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(ArrowTheme.amber)
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(ArrowTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(button, action: action)
                .buttonStyle(NookPressStyle())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArrowTheme.ink)
                .padding(.horizontal, 15)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(ArrowTheme.amber)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
