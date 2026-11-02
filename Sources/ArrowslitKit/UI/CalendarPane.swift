import AppKit
import SwiftUI

/// Calendar panel: this month on the left, what's coming up on the right. Click a date to see
/// that day's events, and an event to open it in Calendar.
struct CalendarPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneHeader("Calendar")
            CalendarPanelBody(state: state)
        }
    }
}

struct CalendarPanelBody: View {
    @Bindable var state: AppState
    @State private var selected: Date?
    private var calendar: CalendarService { state.calendar }
    private let red = ArrowTheme.red
    @Environment(\.panelScale) private var scale

    var body: some View {
        switch calendar.access {
        case .notAsked:
            ConnectPrompt(
                text: "See your month and what's coming up.",
                button: "Connect Calendar",
                tint: red
            ) {
                calendar.requestAccess()
            }
        case .denied:
            ConnectPrompt(
                text: "Calendar access is off for Arrowslit.",
                button: "Turn On in Settings",
                tint: .white
            ) {
                calendar.openPrivacySettings()
            }
        case .limited:
            ConnectPrompt(
                text: "Arrowslit can add events but can't see them yet.",
                button: "Allow Full Access",
                tint: .white
            ) {
                calendar.openPrivacySettings()
            }
        case .granted:
            TimelineView(.everyMinute) { context in
                HStack(alignment: .top, spacing: 0) {
                    MonthGrid(
                        today: context.date,
                        selected: selected,
                        busyDays: busyDays(calendar.events)
                    ) { day in
                        withAnimation(.snappy(duration: 0.25)) {
                            let cal = Calendar.current
                            let isCurrent = selected.map { cal.isDate($0, inSameDayAs: day) } ?? false
                            selected = isCurrent || cal.isDate(day, inSameDayAs: context.date) ? nil : day
                        }
                    }
                    .frame(width: 168 * scale, alignment: .leading)

                    Rectangle()
                        .fill(ArrowTheme.hairline)
                        .frame(width: 1)
                        .padding(.horizontal, 16 * scale)
                        .padding(.vertical, 2 * scale)

                    Group {
                        if let selected {
                            DayList(state: state, day: selected, now: context.date)
                        } else {
                            UpNext(state: state, now: context.date)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private func busyDays(_ events: [CalendarEvent]) -> Set<Int> {
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: Date()) else { return [] }
        return Set(events.compactMap { event in
            month.contains(event.start) ? calendar.component(.day, from: event.start) : nil
        })
    }
}

private struct DayList: View {
    @Bindable var state: AppState
    let day: Date
    let now: Date
    @Environment(\.panelScale) private var scale

    var body: some View {
        let events = CalendarRules.events(on: day, in: state.calendar.events, at: now)
        let shown = events.prefix(3)
        VStack(alignment: .leading, spacing: 6 * scale) {
            Text(day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)).uppercased())
                .font(.system(size: 9.5 * scale, weight: .semibold))
                .kerning(0.4)
                .foregroundStyle(ArrowTheme.muted)
            if events.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16 * scale))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(ArrowTheme.muted)
                    Text("No events")
                        .font(.system(size: 12 * scale, weight: .medium))
                        .foregroundStyle(ArrowTheme.muted)
                }
                .padding(.top, 8 * scale)
            } else {
                ForEach(shown) { event in
                    EventRow(event: event, now: now) {
                        state.calendar.open(event)
                    }
                }
                if events.count > shown.count {
                    Text("+\(events.count - shown.count) more")
                        .font(.system(size: 10 * scale, weight: .medium))
                        .foregroundStyle(ArrowTheme.muted)
                }
            }
        }
        .id(day)
        .transition(.opacity)
    }
}

private struct UpNext: View {
    @Bindable var state: AppState
    let now: Date
    @Environment(\.panelScale) private var scale

    var body: some View {
        let upcoming = CalendarRules.upcoming(in: state.calendar.events, at: now, limit: 3)
        VStack(alignment: .leading, spacing: 4 * scale) {
            Text(upcoming.first.map { CalendarRules.dayLabel(for: $0, at: now) }?.uppercased() ?? "UP NEXT")
                .font(.system(size: 9.5 * scale, weight: .semibold))
                .kerning(0.4)
                .foregroundStyle(ArrowTheme.muted)
            if upcoming.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 16 * scale))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(ArrowTheme.muted)
                    Text("Nothing on your calendar this week")
                        .font(.system(size: 12 * scale, weight: .medium))
                        .foregroundStyle(ArrowTheme.muted)
                }
                .padding(.top, 8 * scale)
            } else {
                ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, event in
                    if index > 0, CalendarRules.dayLabel(for: event, at: now) != CalendarRules.dayLabel(for: upcoming[index - 1], at: now) {
                        Text(CalendarRules.dayLabel(for: event, at: now).uppercased())
                            .font(.system(size: 9.5 * scale, weight: .semibold))
                            .kerning(0.4)
                            .foregroundStyle(ArrowTheme.muted)
                            .padding(.top, 1)
                    }
                    EventRow(event: event, now: now) {
                        state.calendar.open(event)
                    }
                }
            }
        }
    }
}

private struct EventRow: View {
    let event: CalendarEvent
    let now: Date
    let open: () -> Void
    @State private var isHovering = false
    @Environment(\.panelScale) private var scale

    var body: some View {
        let happening = event.isHappening(at: now)
        Button(action: open) {
            HStack(spacing: 9 * scale) {
                RoundedRectangle(cornerRadius: 1.5 * scale, style: .continuous)
                    .fill(ArrowTheme.red)
                    .frame(width: 3 * scale, height: 24 * scale)
                VStack(alignment: .leading, spacing: 1 * scale) {
                    Text(event.title)
                        .font(.system(size: 12.5 * scale, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(1)
                    Text(CalendarRules.timeRange(for: event, at: now))
                        .font(.system(size: 10.5 * scale, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(happening ? ArrowTheme.green : ArrowTheme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6 * scale)
            .padding(.vertical, 1 * scale)
            .background(
                RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.08 : 0))
            )
            .padding(.horizontal, -6 * scale)
            .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle())
        .onHover { isHovering = $0 }
        .help("Open in Calendar")
        .accessibilityLabel("\(event.title), \(CalendarRules.timeRange(for: event, at: now))")
    }
}

private struct MonthGrid: View {
    let today: Date
    let selected: Date?
    let busyDays: Set<Int>
    let pick: (Date) -> Void
    @Environment(\.panelScale) private var scale

    var body: some View {
        let month = MonthLayout(containing: today)
        let columns = Array(repeating: GridItem(.fixed(22 * scale), spacing: 1 * scale), count: 7)
        VStack(alignment: .leading, spacing: 3 * scale) {
            Text(today.formatted(.dateTime.month(.wide)).uppercased())
                .font(.system(size: 10 * scale, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(ArrowTheme.red)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(month.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 8 * scale, weight: .semibold))
                        .foregroundStyle(ArrowTheme.muted)
                        .frame(height: 11 * scale)
                }
                ForEach(month.cells.indices.map { $0 + 100 }, id: \.self) { index in
                    let day = month.cells[index - 100]
                    let date = day.flatMap(dayDate)
                    DayCell(
                        day: day,
                        date: date,
                        isToday: day == month.today,
                        isSelected: isSelected(date),
                        isBusy: day.map(busyDays.contains) ?? false,
                        pick: pick
                    )
                }
            }
        }
    }

    private func isSelected(_ date: Date?) -> Bool {
        guard let date, let selected else { return false }
        return Calendar.current.isDate(date, inSameDayAs: selected)
    }

    private func dayDate(_ day: Int) -> Date? {
        let calendar = Calendar.current
        var parts = calendar.dateComponents([.year, .month], from: today)
        parts.day = day
        return calendar.date(from: parts)
    }
}

private struct DayCell: View {
    let day: Int?
    let date: Date?
    let isToday: Bool
    let isSelected: Bool
    let isBusy: Bool
    let pick: (Date) -> Void
    @State private var isHovering = false
    @Environment(\.panelScale) private var scale

    var body: some View {
        if let date {
            Button { pick(date) } label: { face }
                .buttonStyle(NookPressStyle())
                .onHover { isHovering = $0 }
                .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            face
        }
    }

    private var face: some View {
        ZStack {
            if isToday {
                Circle().fill(ArrowTheme.red).frame(width: 15 * scale, height: 15 * scale)
            } else if isSelected {
                Circle().fill(Color.white.opacity(0.22)).frame(width: 15 * scale, height: 15 * scale)
            } else if isHovering {
                Circle().fill(Color.white.opacity(0.1)).frame(width: 15 * scale, height: 15 * scale)
            }
            Text(day.map(String.init) ?? "")
                .font(.system(size: 9 * scale, weight: isToday || isSelected ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(isToday || isSelected ? 1 : 0.85))
            if isBusy, !isToday, !isSelected {
                Circle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 2.5 * scale, height: 2.5 * scale)
                    .offset(y: 7 * scale)
            }
        }
        .frame(width: 22 * scale, height: 13 * scale)
        .contentShape(Rectangle())
    }
}

private struct ConnectPrompt: View {
    let text: String
    let button: String
    let tint: Color
    let action: () -> Void
    @Environment(\.panelScale) private var scale

    var body: some View {
        VStack(spacing: 12 * scale) {
            Image(systemName: "calendar")
                .font(.system(size: 24 * scale, weight: .regular))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11.5 * scale))
                .foregroundStyle(ArrowTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360 * scale)
            Button(button, action: action)
                .buttonStyle(NookPressStyle())
                .font(.system(size: 11 * scale, weight: .semibold))
                .foregroundStyle(ArrowTheme.ink)
                .padding(.horizontal, 15 * scale)
                .frame(height: 32 * scale)
                .background(
                    RoundedRectangle(cornerRadius: 7 * scale, style: .continuous)
                        .fill(ArrowTheme.amber)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
