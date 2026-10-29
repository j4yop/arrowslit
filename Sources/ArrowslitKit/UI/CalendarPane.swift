import SwiftUI

struct CalendarPane: View {
    @Bindable var state: AppState
    private var calendar: CalendarService { state.calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CALENDAR")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(ArrowTheme.faint)
                    Text("Just the next thing, so it stays out of the way.")
                        .font(.system(size: 11))
                        .foregroundStyle(ArrowTheme.muted)
                }
                Spacer()
                if calendar.access == .granted {
                    Text("CONNECTED")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(ArrowTheme.green)
                }
            }

            switch calendar.access {
            case .notAsked:
                prompt(
                    "Arrowslit can show your next event here. It never uploads your calendar.",
                    button: "Connect Calendar"
                ) { calendar.requestAccess() }
            case .denied, .limited:
                prompt(
                    "Calendar access is off. Turn it on in Privacy & Security to see the next event.",
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
        Button {
            calendar.open(event)
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(ArrowTheme.amber)
                    .frame(width: 3, height: 64)
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(1)
                    Text(timeLabel(event))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(event.isHappening(at: Date()) ? ArrowTheme.green : ArrowTheme.muted)
                    Text(event.start.formatted(date: .complete, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundStyle(ArrowTheme.faint)
                }
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ArrowTheme.faint)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle())
        .help("Open in Calendar")
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(ArrowTheme.faint)
            Text("Nothing on the calendar this week.")
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
                .background(Capsule().fill(ArrowTheme.amber))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func timeLabel(_ event: CalendarEvent) -> String {
        if event.isAllDay { return "All day" }
        let end = event.end.formatted(date: .omitted, time: .shortened)
        if event.isHappening(at: Date()) { return "Now · until \(end)" }
        let start = event.start.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}
