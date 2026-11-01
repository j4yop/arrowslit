import Foundation

/// Pure calendar rules: which event is next, when to give a heads-up, and how to label it.
public enum CalendarRules {
    /// How long before an event starts the notch gives a heads-up.
    public static let reminderLead: TimeInterval = 5 * 60

    /// The event happening now, or else the next one to start. All-day events are not alerts.
    public static func nextEvent(in events: [CalendarEvent], at date: Date) -> CalendarEvent? {
        events
            .filter { !$0.isAllDay && $0.end > date }
            .sorted { $0.start < $1.start }
            .first
    }

    /// The next moment a heads-up is due, and for which event. Skips events already reminded.
    public static func nextReminder(
        in events: [CalendarEvent],
        after date: Date,
        reminded: Set<String>
    ) -> (event: CalendarEvent, at: Date)? {
        events
            .filter { !$0.isAllDay && !reminded.contains($0.id) && $0.start > date }
            .map { event in
                (event: event, at: max(date, event.start.addingTimeInterval(-reminderLead)))
            }
            .min { $0.at < $1.at }
    }

    /// "now", "in 12 min", "in 1 hr", or a clock time for later.
    public static func relativeLabel(
        for event: CalendarEvent,
        at date: Date,
        calendar: Calendar = .current
    ) -> String {
        if event.isHappening(at: date) { return "now" }
        let minutes = minutesUntil(event.start, at: date)
        if minutes < 60 { return "in \(max(minutes, 1)) min" }
        if minutes < 120 { return "in 1 hr" }
        let time = event.start.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(event.start, inSameDayAs: date) { return time }
        return event.start.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    /// The short line shown in a calendar alert.
    public static func alertDetail(for event: CalendarEvent, at date: Date) -> String {
        alertDetail(startsAt: event.start, at: date)
    }

    public static func alertDetail(startsAt: Date, at date: Date) -> String {
        if startsAt.timeIntervalSince(date) < 60 { return "Starting now" }
        return "Starts in \(minutesUntil(startsAt, at: date)) min"
    }

    /// "10:30 – 11:00 AM", "Now · until 11:00 AM" or "All day".
    public static func timeRange(for event: CalendarEvent, at date: Date) -> String {
        if event.isAllDay { return "All day" }
        let end = event.end.formatted(date: .omitted, time: .shortened)
        if event.isHappening(at: date) { return "Now · until \(end)" }
        let start = event.start.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    private static func minutesUntil(_ date: Date, at now: Date) -> Int {
        max(0, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
    }
}

/// The days of one month laid out in weeks, starting on the user's first weekday.
public struct MonthLayout: Equatable {
    public var cells: [Int?]
    public var today: Int
    public var weekdaySymbols: [String]

    public init(containing date: Date, calendar: Calendar = .current) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let days = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        let weekday = calendar.component(.weekday, from: start)
        let lead = (weekday - calendar.firstWeekday + 7) % 7
        cells = Array(repeating: nil, count: lead) + (1...days).map { Optional($0) }
        today = calendar.component(.day, from: date)
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        weekdaySymbols = Array(symbols[first...] + symbols[..<first])
    }
}

extension CalendarRules {
    /// The events on one day, all-day ones first. On today, the ones already over are left out.
    public static func events(
        on day: Date,
        in events: [CalendarEvent],
        at date: Date,
        calendar: Calendar = .current
    ) -> [CalendarEvent] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return events
            .filter { $0.start < end && $0.end > start }
            .filter { !calendar.isDate(day, inSameDayAs: date) || $0.end > date }
            .sorted { $0.isAllDay != $1.isAllDay ? $0.isAllDay : $0.start < $1.start }
    }

    /// The next few events, grouped in calendar order.
    public static func upcoming(in events: [CalendarEvent], at date: Date, limit: Int) -> [CalendarEvent] {
        let calendar = Calendar.current
        return Array(
            events
                .filter { $0.end > date }
                .sorted {
                    let dayA = calendar.startOfDay(for: max($0.start, date))
                    let dayB = calendar.startOfDay(for: max($1.start, date))
                    if dayA != dayB { return dayA < dayB }
                    if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
                    return $0.start < $1.start
                }
                .prefix(limit)
        )
    }

    /// The days the Calendar panel reads: the whole month plus the coming week.
    public static func loadRange(at date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: date)
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? today
        let monthEnd = calendar.dateInterval(of: .month, for: date)?.end ?? today
        let weekStart = calendar.date(byAdding: .day, value: -2, to: today) ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 8, to: today) ?? today
        return (min(monthStart, weekStart), max(monthEnd, weekEnd))
    }

    /// "Today", "Tomorrow", or the weekday and date for later in the week.
    public static func dayLabel(for event: CalendarEvent, at date: Date, calendar: Calendar = .current) -> String {
        let day = max(event.start, date)
        if calendar.isDate(day, inSameDayAs: date) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date),
           calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}
