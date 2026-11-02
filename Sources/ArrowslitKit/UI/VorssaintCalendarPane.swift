import AppKit
import SwiftUI

/// Vorssaint's Calendar page: a week strip with event dots, the month as a
/// grid behind the calendar button, and a scrolling agenda underneath.
struct VorssaintCalendarPane: View {
    @Bindable var state: AppState
    @State private var selected = Date()
    @State private var showsMonth = false

    private var calendar: CalendarService { state.calendar }

    var body: some View {
        Group {
            switch calendar.access {
            case .notAsked:
                permission("See your week and what's coming up.", button: "Connect Calendar") {
                    calendar.requestAccess()
                }
            case .denied:
                permission("Calendar access is off for Arrowslit.", button: "Open System Settings") {
                    calendar.openPrivacySettings()
                }
            case .limited:
                permission("Arrowslit can add events but can't see them yet.", button: "Allow Full Access") {
                    calendar.openPrivacySettings()
                }
            case .granted:
                TimelineView(.everyMinute) { context in
                    VStack(spacing: 8) {
                        if showsMonth {
                            monthView(at: context.date)
                        } else {
                            weekView(at: context.date)
                        }
                        agenda(at: context.date)
                    }
                }
            }
        }
        .onAppear { selected = Date() }
    }

    // MARK: Week

    private func weekView(at now: Date) -> some View {
        HStack(spacing: 6) {
            Button {
                shiftWeek(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 22, height: 34)
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.92))

            HStack(spacing: 0) {
                ForEach(weekDays(around: selected), id: \.self) { day in
                    dayCell(day, at: now)
                        .frame(maxWidth: .infinity)
                }
            }

            Button {
                shiftWeek(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 22, height: 34)
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.92))

            toolIcons(at: now)
        }
        .frame(height: 54)
    }

    private func dayCell(_ day: Date, at now: Date) -> some View {
        let cal = weekCalendar
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        let isToday = cal.isDate(day, inSameDayAs: now)
        let dots = eventColors(on: day)
        return VStack(spacing: 3) {
            Text(weekdayLetter(day))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.34))
            ZStack {
                if isSelected {
                    Circle().fill(VorssaintTheme.pink)
                        .frame(width: 22, height: 22)
                } else if isToday {
                    Circle().fill(.white)
                        .frame(width: 22, height: 22)
                }
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white : (isToday ? .black : .white.opacity(0.9)))
            }
            .frame(height: 22)
            HStack(spacing: 2) {
                ForEach(Array(dots.prefix(3).enumerated()), id: \.offset) { _, tint in
                    Circle().fill(tint).frame(width: 3.5, height: 3.5)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy(duration: 0.2)) { selected = day }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
    }

    private func toolIcons(at now: Date) -> some View {
        HStack(spacing: 3) {
            Button {
                withAnimation(.smooth(duration: 0.22)) { showsMonth.toggle() }
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(showsMonth ? 0.95 : 0.55))
                    .frame(width: 24, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(showsMonth ? Color.white.opacity(0.12) : .clear)
                    )
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.92))
            .help(showsMonth ? "Week" : "Month")

            Button {
                withAnimation(.snappy(duration: 0.2)) { selected = now }
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 24, height: 26)
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.92))
            .help("Today")

            Button {
                NSWorkspace.shared.open(URL(string: "x-apple-calendar://")!)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 24, height: 26)
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.92))
            .help("Open Calendar")
        }
    }

    // MARK: Month

    private func monthView(at now: Date) -> some View {
        let cal = weekCalendar
        let monthStart = cal.dateInterval(of: .month, for: selected)?.start ?? selected
        let days = monthDays(from: monthStart)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return VStack(spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 22, height: 24)
                }
                .buttonStyle(.plain)
                Text(monthStart.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 22, height: 24)
                }
                .buttonStyle(.plain)
                Spacer()
                toolIcons(at: now)
            }
            .frame(height: 26)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.34))
                        .frame(maxWidth: .infinity, minHeight: 12)
                }
                ForEach(days, id: \.self) { day in
                    monthDayCell(day, at: now)
                }
            }
        }
        .frame(height: 148, alignment: .top)
    }

    private func monthDayCell(_ day: Date, at now: Date) -> some View {
        let cal = weekCalendar
        let inMonth = cal.isDate(day, equalTo: selected, toGranularity: .month)
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        let isToday = cal.isDate(day, inSameDayAs: now)
        let dots = eventColors(on: day)
        return VStack(spacing: 1) {
            ZStack {
                if isSelected {
                    Circle().fill(VorssaintTheme.pink).frame(width: 20, height: 20)
                } else if isToday {
                    Circle().fill(.white).frame(width: 20, height: 20)
                }
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white : (isToday ? .black : .white.opacity(inMonth ? 0.86 : 0.28)))
            }
            .frame(height: 18)
            HStack(spacing: 2) {
                ForEach(Array(dots.prefix(3).enumerated()), id: \.offset) { _, tint in
                    Circle().fill(tint).frame(width: 3, height: 3)
                }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy(duration: 0.2)) {
                selected = day
                showsMonth = false
            }
        }
    }

    // MARK: Agenda

    private func agenda(at now: Date) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 7) {
                let days = agendaDays(at: now)
                if days.isEmpty {
                    VorssaintPageEmpty(
                        symbol: "calendar.badge.checkmark",
                        title: "No appointments",
                        detail: "Nothing on your calendar this week."
                    )
                    .frame(height: 108)
                } else {
                    ForEach(days, id: \.self) { day in
                        let events = CalendarRules.events(on: day, in: calendar.events, at: now)
                        if !events.isEmpty {
                            HStack(spacing: 5) {
                                Text(dayLabel(day, at: now))
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(dayLabel(day, at: now) == "Today" ? .white : .white.opacity(0.62))
                                Text(Self.monthDayFormatter.string(from: day))
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.38))
                            }
                            ForEach(events.prefix(4)) { event in
                                eventRow(event, at: now)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)
        }
        .frame(maxHeight: .infinity)
    }

    private func eventRow(_ event: CalendarEvent, at now: Date) -> some View {
        let accent = accent(for: event)
        return Button {
            calendar.open(event)
        } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                    Text(CalendarRules.timeRange(for: event, at: now))
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                    Text("Calendar")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.28))
                        .lineLimit(1)
                }
                .padding(.leading, 9)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(accent.opacity(0.13))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 0.6)
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(NookPressStyle(pressedScale: 0.985))
        .help("Open in Calendar")
    }

    private func agendaDays(at now: Date) -> [Date] {
        let cal = weekCalendar
        let start = cal.startOfDay(for: selected)
        return (0..<4).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayLabel(_ day: Date, at now: Date) -> String {
        if weekCalendar.isDate(day, inSameDayAs: now) { return "Today" }
        return day.formatted(.dateTime.weekday(.abbreviated))
    }

    // MARK: Dates and colour

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var weekCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }

    private func weekDays(around date: Date) -> [Date] {
        let cal = weekCalendar
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func monthDays(from start: Date) -> [Date] {
        let cal = weekCalendar
        guard let interval = cal.dateInterval(of: .month, for: start) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        let gridStart = cal.date(byAdding: .day, value: -leading, to: interval.start) ?? interval.start
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func weekdayLetter(_ day: Date) -> String {
        let symbols = ["S", "M", "T", "W", "T", "F", "S"]
        let weekday = weekCalendar.component(.weekday, from: day)
        return symbols[max(0, min(6, weekday - 1))]
    }

    private func shiftWeek(_ offset: Int) {
        guard let next = weekCalendar.date(byAdding: .weekOfYear, value: offset, to: selected) else { return }
        withAnimation(.snappy(duration: 0.22)) { selected = next }
    }

    private func shiftMonth(_ offset: Int) {
        guard let next = weekCalendar.date(byAdding: .month, value: offset, to: selected) else { return }
        withAnimation(.snappy(duration: 0.22)) { selected = next }
    }

    private func events(on day: Date) -> [CalendarEvent] {
        CalendarRules.events(on: day, in: calendar.events, at: Date())
    }

    private func eventColors(on day: Date) -> [Color] {
        events(on: day).prefix(3).map { accent(for: $0) }
    }

    private func accent(for event: CalendarEvent) -> Color {
        let palette: [Color] = [
            VorssaintTheme.blue, VorssaintTheme.pink, VorssaintTheme.orange,
            VorssaintTheme.green, VorssaintTheme.purple, VorssaintTheme.yellow,
        ]
        var hash = 5381
        for scalar in event.id.unicodeScalars { hash = (hash &* 33) &+ Int(scalar.value) }
        return palette[abs(hash) % palette.count]
    }

    private func permission(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button(button, action: action)
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(VorssaintTheme.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
