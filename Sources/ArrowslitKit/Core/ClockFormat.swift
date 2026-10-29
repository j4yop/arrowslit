import Foundation

public enum ClockFormat {
    /// "4:59", "1:02:03". `roundingUp` is used by countdowns so they never show 0:00 early.
    public static func clock(_ seconds: TimeInterval, roundingUp: Bool = false, tenths: Bool = false) -> String {
        guard seconds.isFinite else { return "0:00" }
        let value = min(max(0, seconds), 359_999)
        let whole = roundingUp ? Int(value.rounded(.up)) : Int(value.rounded(.down))
        let hours = whole / 3600
        let minutes = (whole % 3600) / 60
        let secs = whole % 60
        let base: String
        if hours > 0 {
            base = String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            base = String(format: "%d:%02d", minutes, secs)
        }
        guard tenths else { return base }
        let fraction = Int((value * 10).rounded(.down)) % 10
        return base + ".\(fraction)"
    }

    /// Short local time for the compact strip, e.g. "9:41".
    public static func wallClock(_ date: Date = Date()) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "1m", "25m", "1h 30m" for preset buttons.
    public static func presetLabel(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    /// "Just now", "2m ago", "3h ago".
    public static func age(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 45 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86_400))d ago"
    }
}
