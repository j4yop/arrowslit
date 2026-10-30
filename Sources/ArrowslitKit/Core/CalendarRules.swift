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
