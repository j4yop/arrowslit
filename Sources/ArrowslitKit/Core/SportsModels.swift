import Foundation

// MARK: - Competition

public struct SportsCompetition: Identifiable, Hashable, Sendable {
    public let id: String
    /// The provider's league code.
    public let key: String
    public let name: String
    public let shortName: String
    public let priority: Int
    public let isFeatured: Bool

    public init(
        id: String,
        key: String,
        name: String,
        shortName: String,
        priority: Int,
        isFeatured: Bool
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.shortName = shortName
        self.priority = priority
        self.isFeatured = isFeatured
    }
}

public enum SportsCatalog {
    public static let football: [SportsCompetition] = [
        SportsCompetition(
            id: "football/epl", key: "epl",
            name: "Premier League", shortName: "EPL", priority: 0, isFeatured: true
        ),
        SportsCompetition(
            id: "football/laliga", key: "laliga",
            name: "La Liga", shortName: "La Liga", priority: 1, isFeatured: true
        ),
        SportsCompetition(
            id: "football/ucl", key: "ucl",
            name: "UEFA Champions League", shortName: "UCL", priority: 2, isFeatured: true
        ),
        SportsCompetition(
            id: "football/seriea", key: "seriea",
            name: "Serie A", shortName: "Serie A", priority: 3, isFeatured: false
        ),
        SportsCompetition(
            id: "football/bundesliga", key: "bundesliga",
            name: "Bundesliga", shortName: "Bundesliga", priority: 4, isFeatured: false
        ),
        SportsCompetition(
            id: "football/ligue1", key: "ligue1",
            name: "Ligue 1", shortName: "Ligue 1", priority: 5, isFeatured: false
        ),
    ]

    public static let all: [SportsCompetition] = football

    public static var featuredIDs: [String] {
        all.filter(\.isFeatured).map(\.id)
    }

    public static func competition(id: String) -> SportsCompetition? {
        all.first { $0.id == id }
    }

    public static func competition(for leagueName: String) -> SportsCompetition? {
        let value = normalized(leagueName)
        if value.contains("premier league") || value == "epl" {
            return competition(id: "football/epl")
        }
        if value.contains("la liga") || value == "laliga" {
            return competition(id: "football/laliga")
        }
        if value.contains("champions league") || value == "ucl" {
            return competition(id: "football/ucl")
        }
        if value.contains("serie a") {
            return competition(id: "football/seriea")
        }
        if value.contains("bundesliga") {
            return competition(id: "football/bundesliga")
        }
        if value.contains("ligue 1") {
            return competition(id: "football/ligue1")
        }
        return nil
    }

    public static func fallback(for leagueName: String) -> SportsCompetition {
        let slug = normalized(leagueName).replacingOccurrences(of: " ", with: "-")
        return SportsCompetition(
            id: "football/\(slug.isEmpty ? "other" : slug)",
            key: leagueName,
            name: leagueName,
            shortName: leagueName,
            priority: 90,
            isFeatured: false
        )
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "uefa", with: "")
            .replacingOccurrences(of: "–", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

// MARK: - Team

public struct SportsTeam: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let shortName: String
    public let colorHex: String?

    public init(id: String, name: String, shortName: String? = nil, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.shortName = shortName?.isEmpty == false ? shortName! : SportsTeam.abbreviation(for: name)
        self.colorHex = colorHex
    }

    public static func abbreviation(for name: String) -> String {
        let words = name
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .filter { $0.count > 1 }
        if words.count >= 2 {
            let initials = words.prefix(3).compactMap(\.first)
            let value = String(initials).uppercased()
            if value.count >= 2 { return value }
        }
        return String(name.prefix(3)).uppercased()
    }
}

// MARK: - Match

public enum SportsMatchState: String, Codable, Sendable {
    case scheduled
    case live
    case halfTime
    case finished
    case postponed
    case cancelled
    case suspended

    public var isLive: Bool {
        self == .live || self == .halfTime
    }

    public var isFinished: Bool {
        self == .finished
    }

    public init?(providerStatus: String) {
        switch providerStatus.lowercased() {
        case "scheduled", "ns", "not_started": self = .scheduled
        case "live", "in_progress", "inprogress", "1h", "2h", "et", "p": self = .live
        case "ht", "halftime", "half_time": self = .halfTime
        case "finished", "ft", "final", "result": self = .finished
        case "postponed", "pst": self = .postponed
        case "cancelled", "canceled", "canc": self = .cancelled
        case "suspended": self = .suspended
        default: return nil
        }
    }
}

public struct SportsFootballEvent: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case goal
        case yellowCard
        case redCard
        case substitution
        case other
    }

    public let id: String
    public let minute: Int?
    public let extraMinute: Int?
    public let kind: Kind
    public let player: String?
    public let team: String?
    public let detail: String?

    public init(
        id: String,
        minute: Int?,
        extraMinute: Int? = nil,
        kind: Kind,
        player: String? = nil,
        team: String? = nil,
        detail: String? = nil
    ) {
        self.id = id
        self.minute = minute
        self.extraMinute = extraMinute
        self.kind = kind
        self.player = player
        self.team = team
        self.detail = detail
    }

    public var clock: String? {
        guard let minute else { return nil }
        if let extraMinute, extraMinute > 0 { return "\(minute)+\(extraMinute)'" }
        return "\(minute)'"
    }
}

public struct SportsGoalEvent: Equatable, Sendable {
    public let matchID: String
    public let teamName: String
    public let teamShortName: String
    public let homeShortName: String
    public let awayShortName: String
    public let homeScore: Int
    public let awayScore: Int
    public let minute: String?

    public init(
        matchID: String,
        teamName: String,
        teamShortName: String,
        homeShortName: String,
        awayShortName: String,
        homeScore: Int,
        awayScore: Int,
        minute: String?
    ) {
        self.matchID = matchID
        self.teamName = teamName
        self.teamShortName = teamShortName
        self.homeShortName = homeShortName
        self.awayShortName = awayShortName
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.minute = minute
    }

    public var scoreLine: String {
        "\(homeShortName) \(homeScore)–\(awayScore) \(awayShortName)"
    }
}

public struct SportsMatch: Identifiable, Hashable, Sendable {
    public let id: String
    public let competition: SportsCompetition
    public let home: SportsTeam
    public let away: SportsTeam
    public let start: Date
    public let state: SportsMatchState
    public let homeScore: Int?
    public let awayScore: Int?
    public let statusText: String
    public let round: String?
    public let venue: String?
    public let lastUpdated: Date
    public let isDemo: Bool

    public init(
        id: String,
        competition: SportsCompetition,
        home: SportsTeam,
        away: SportsTeam,
        start: Date,
        state: SportsMatchState,
        homeScore: Int? = nil,
        awayScore: Int? = nil,
        statusText: String = "",
        round: String? = nil,
        venue: String? = nil,
        lastUpdated: Date = Date(),
        isDemo: Bool = false
    ) {
        self.id = id
        self.competition = competition
        self.home = home
        self.away = away
        self.start = start
        self.state = state
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.statusText = statusText
        self.round = round
        self.venue = venue
        self.lastUpdated = lastUpdated
        self.isDemo = isDemo
    }

    public var isLive: Bool { state.isLive }

    public var scoreLine: String {
        let home = homeScore.map(String.init) ?? "–"
        let away = awayScore.map(String.init) ?? "–"
        return "\(home)–\(away)"
    }

    public var searchedText: String {
        "\(competition.name) \(home.name) \(away.name) \(home.shortName) \(away.shortName)"
    }
}

// MARK: - Demo data

public enum SportsDemoData {
    public static func matches(now: Date = Date()) -> [SportsMatch] {
        let epl = SportsCatalog.competition(id: "football/epl")!
        let laliga = SportsCatalog.competition(id: "football/laliga")!
        let ucl = SportsCatalog.competition(id: "football/ucl")!

        let real = SportsTeam(id: "demo-real", name: "Real Madrid", shortName: "RMA", colorHex: "#F4F4F4")
        let barca = SportsTeam(id: "demo-barca", name: "Barcelona", shortName: "BAR", colorHex: "#A50044")
        let arsenal = SportsTeam(id: "demo-arsenal", name: "Arsenal", shortName: "ARS", colorHex: "#EF0107")
        let chelsea = SportsTeam(id: "demo-chelsea", name: "Chelsea", shortName: "CHE", colorHex: "#034694")
        let psg = SportsTeam(id: "demo-psg", name: "Paris Saint-Germain", shortName: "PSG", colorHex: "#004170")
        let bayern = SportsTeam(id: "demo-bayern", name: "Bayern München", shortName: "FCB", colorHex: "#DC052D")
        let liverpool = SportsTeam(id: "demo-liverpool", name: "Liverpool", shortName: "LIV", colorHex: "#C8102E")
        let city = SportsTeam(id: "demo-city", name: "Manchester City", shortName: "MCI", colorHex: "#6CABDD")
        let inter = SportsTeam(id: "demo-inter", name: "Inter", shortName: "INT", colorHex: "#0068A8")
        let milan = SportsTeam(id: "demo-milan", name: "AC Milan", shortName: "MIL", colorHex: "#FB090B")
        let atletico = SportsTeam(id: "demo-atletico", name: "Atlético Madrid", shortName: "ATM", colorHex: "#CB3524")

        return [
            SportsMatch(
                id: "demo-football-1", competition: laliga,
                home: real, away: barca, start: now.addingTimeInterval(-67 * 60),
                state: .live, homeScore: 2, awayScore: 1,
                statusText: "67'", round: "Matchday 12", venue: "Santiago Bernabéu",
                lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-football-2", competition: ucl,
                home: psg, away: bayern, start: now.addingTimeInterval(-54 * 60),
                state: .live, homeScore: 1, awayScore: 1,
                statusText: "54'", round: "League phase", venue: "Parc des Princes",
                lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-football-3", competition: epl,
                home: arsenal, away: chelsea, start: now.addingTimeInterval(-23 * 60),
                state: .live, homeScore: 0, awayScore: 0,
                statusText: "23'", round: "Matchday 12", venue: "Emirates Stadium",
                lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-football-4", competition: epl,
                home: liverpool, away: city, start: now.addingTimeInterval(-72 * 60),
                state: .live, homeScore: 1, awayScore: 0,
                statusText: "72'", round: "Matchday 12", venue: "Anfield",
                lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-football-5", competition: laliga,
                home: atletico, away: real, start: now.addingTimeInterval(3 * 3600),
                state: .scheduled, statusText: "Today", round: "Matchday 13",
                venue: "Metropolitano", lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-football-6", competition: ucl,
                home: inter, away: milan, start: now.addingTimeInterval(26 * 3600),
                state: .scheduled, statusText: "Tomorrow", round: "League phase",
                venue: "San Siro", lastUpdated: now, isDemo: true
            ),
        ]
    }

    public static func details(now: Date = Date()) -> [String: [SportsFootballEvent]] {
        [
            "demo-football-1": [
                SportsFootballEvent(id: "demo-e1", minute: 18, kind: .goal, player: "Vinícius Júnior", team: "Real Madrid", detail: "Right-footed finish"),
                SportsFootballEvent(id: "demo-e2", minute: 34, kind: .yellowCard, player: "Gavi", team: "Barcelona", detail: "Late challenge"),
                SportsFootballEvent(id: "demo-e3", minute: 41, kind: .goal, player: "Robert Lewandowski", team: "Barcelona", detail: "Header from a corner"),
                SportsFootballEvent(id: "demo-e4", minute: 58, kind: .goal, player: "Jude Bellingham", team: "Real Madrid", detail: "Low drive from the edge of the box"),
            ],
            "demo-football-2": [
                SportsFootballEvent(id: "demo-e5", minute: 12, kind: .goal, player: "Ousmane Dembélé", team: "Paris Saint-Germain", detail: "Counter-attack"),
                SportsFootballEvent(id: "demo-e6", minute: 39, kind: .goal, player: "Harry Kane", team: "Bayern München", detail: "Penalty"),
            ],
            "demo-football-3": [],
            "demo-football-4": [
                SportsFootballEvent(id: "demo-e7", minute: 26, kind: .goal, player: "Mohamed Salah", team: "Liverpool", detail: "Near-post finish"),
            ],
        ]
    }
}
