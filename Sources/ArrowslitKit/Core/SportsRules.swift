import Foundation

// MARK: - Formatting

public enum SportsFormat {
    public static func overs(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }

    public static func runRate(_ value: Double?) -> String? {
        guard let value else { return nil }
        return String(format: "%.2f", value)
    }

    public static func kickoff(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow \(date.formatted(date: .omitted, time: .shortened))"
        }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }

    public static func dayLabel(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    public static func status(_ match: SportsMatch, now: Date = Date()) -> String {
        switch match.state {
        case .live:
            if !match.statusText.isEmpty, match.statusText != "live", match.statusText != "in_progress" {
                return match.statusText
            }
            return "LIVE"
        case .breakTime:
            return match.statusText.isEmpty ? "BREAK" : match.statusText.uppercased()
        case .scheduled:
            return kickoff(match.start, now: now)
        case .finished:
            return match.sport == .football ? "FT" : "Final"
        case .postponed:
            return "Postponed"
        case .cancelled:
            return "Cancelled"
        case .suspended:
            return "Suspended"
        }
    }

    public static func shortStatus(_ match: SportsMatch, now: Date = Date()) -> String {
        switch match.state {
        case .live: "LIVE"
        case .breakTime: "BREAK"
        case .scheduled: kickoff(match.start, now: now)
        case .finished: match.sport == .football ? "FT" : "Final"
        case .postponed: "PST"
        case .cancelled: "CANC"
        case .suspended: "SUSP"
        }
    }

    public static func relativeStart(_ match: SportsMatch, now: Date = Date()) -> String {
        let minutes = Int(match.start.timeIntervalSince(now) / 60)
        if match.state.isLive { return status(match, now: now) }
        if match.state.isFinished { return status(match, now: now) }
        if minutes < 0 { return "Started" }
        if minutes < 60 { return "in \(minutes)m" }
        if minutes < 24 * 60 { return "in \(minutes / 60)h" }
        return dayLabel(match.start, now: now)
    }

    public static func cricketDetailLine(_ state: SportsCricketState?) -> String? {
        guard let state, let score = state.scoreLine else { return nil }
        var parts = [score]
        if let runRate = runRate(state.runRate) {
            parts.append("RR \(runRate)")
        }
        if let target = state.target, let required = runRate(state.requiredRate) {
            parts.append("Need \(max(0, target - (state.runs ?? 0))) at \(required)")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Ranking

public enum SportsRanking {
    public static func rank(
        _ matches: [SportsMatch],
        followedTeamIDs: Set<String>,
        followedCompetitionIDs: Set<String>,
        pinnedID: String?,
        now: Date = Date()
    ) -> [SportsMatch] {
        matches.sorted { lhs, rhs in
            let left = score(
                lhs,
                followedTeamIDs: followedTeamIDs,
                followedCompetitionIDs: followedCompetitionIDs,
                pinnedID: pinnedID,
                now: now
            )
            let right = score(
                rhs,
                followedTeamIDs: followedTeamIDs,
                followedCompetitionIDs: followedCompetitionIDs,
                pinnedID: pinnedID,
                now: now
            )
            if left != right { return left > right }
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.id < rhs.id
        }
    }

    private static func score(
        _ match: SportsMatch,
        followedTeamIDs: Set<String>,
        followedCompetitionIDs: Set<String>,
        pinnedID: String?,
        now: Date
    ) -> Int {
        var value = 0
        if match.id == pinnedID { value += 10_000 }
        if match.state.isLive { value += 2_000 }
        if followedTeamIDs.contains(match.home.id) || followedTeamIDs.contains(match.away.id) {
            value += 1_000
        }
        if followedCompetitionIDs.contains(match.competition.id) { value += 400 }
        if match.competition.isFeatured { value += 200 }
        if match.state == .scheduled {
            let minutes = max(0, Int(match.start.timeIntervalSince(now) / 60))
            value += max(0, 180 - min(180, minutes / 60))
        }
        if match.state.isFinished { value += 20 }
        value += max(0, 40 - match.competition.priority)
        return value
    }

    public static func filtered(
        _ matches: [SportsMatch],
        sport: Sport,
        competitionID: String?
    ) -> [SportsMatch] {
        matches.filter { match in
            guard match.sport == sport else { return false }
            guard let competitionID else { return true }
            return match.competition.id == competitionID
        }
    }

    public static func liveCount(_ matches: [SportsMatch], sport: Sport) -> Int {
        matches.filter { $0.sport == sport && $0.isLive }.count
    }
}

// MARK: - Quota

public struct SportsQuota: Equatable, Sendable {
    public var limit: Int
    public var remaining: Int?
    public var resetAt: Date?
    public var retryAfter: TimeInterval?

    public init(limit: Int = 250, remaining: Int? = nil, resetAt: Date? = nil, retryAfter: TimeInterval? = nil) {
        self.limit = limit
        self.remaining = remaining
        self.resetAt = resetAt
        self.retryAfter = retryAfter
    }

    public var isKnown: Bool { remaining != nil }
    public var isExhausted: Bool { (remaining ?? 1) <= 0 }
    public var isLow: Bool { (remaining ?? 100) <= 40 }

    public mutating func merge(headers: [String: String]) {
        let normalized = Dictionary(
            headers.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        if let value = normalized["x-ratelimit-limit"].flatMap(Int.init) {
            limit = value
        }
        if let value = normalized["x-ratelimit-remaining"].flatMap(Int.init) {
            remaining = max(0, value)
        }
        if let value = normalized["x-ratelimit-reset"].flatMap(Double.init) {
            resetAt = Date(timeIntervalSince1970: value)
        }
        if let value = normalized["retry-after"].flatMap(Double.init) {
            retryAfter = value
        }
    }

    public mutating func recordFailure(retryAfter: TimeInterval?) {
        remaining = 0
        if let retryAfter { self.retryAfter = retryAfter }
    }

    public var summary: String {
        guard let remaining else { return "BigBallsData Free" }
        return "\(remaining) of \(limit) requests left today"
    }
}
