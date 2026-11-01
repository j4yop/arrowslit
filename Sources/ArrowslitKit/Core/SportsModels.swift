import Foundation

// MARK: - Sport

public enum Sport: String, Codable, CaseIterable, Identifiable, Sendable {
    case football
    case cricket

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .football: "Football"
        case .cricket: "Cricket"
        }
    }

    public var symbol: String {
        switch self {
        case .football: "soccerball"
        case .cricket: "figure.cricket"
        }
    }
}

// MARK: - Competition

public struct SportsCompetition: Identifiable, Hashable, Sendable {
    public let id: String
    /// The provider's league code (football) or series substring (cricket).
    public let key: String
    public let sport: Sport
    public let name: String
    public let shortName: String
    public let priority: Int
    public let isFeatured: Bool

    public init(
        id: String,
        key: String,
        sport: Sport,
        name: String,
        shortName: String,
        priority: Int,
        isFeatured: Bool
    ) {
        self.id = id
        self.key = key
        self.sport = sport
        self.name = name
        self.shortName = shortName
        self.priority = priority
        self.isFeatured = isFeatured
    }
}

public enum SportsCatalog {
    public static let football: [SportsCompetition] = [
        SportsCompetition(
            id: "football/epl", key: "epl", sport: .football,
            name: "Premier League", shortName: "EPL", priority: 0, isFeatured: true
        ),
        SportsCompetition(
            id: "football/laliga", key: "laliga", sport: .football,
            name: "La Liga", shortName: "La Liga", priority: 1, isFeatured: true
        ),
        SportsCompetition(
            id: "football/ucl", key: "ucl", sport: .football,
            name: "UEFA Champions League", shortName: "UCL", priority: 2, isFeatured: true
        ),
        SportsCompetition(
            id: "football/seriea", key: "seriea", sport: .football,
            name: "Serie A", shortName: "Serie A", priority: 3, isFeatured: false
        ),
        SportsCompetition(
            id: "football/bundesliga", key: "bundesliga", sport: .football,
            name: "Bundesliga", shortName: "Bundesliga", priority: 4, isFeatured: false
        ),
        SportsCompetition(
            id: "football/ligue1", key: "ligue1", sport: .football,
            name: "Ligue 1", shortName: "Ligue 1", priority: 5, isFeatured: false
        ),
    ]

    public static let cricket: [SportsCompetition] = [
        SportsCompetition(
            id: "cricket/ipl", key: "IPL", sport: .cricket,
            name: "Indian Premier League", shortName: "IPL", priority: 10, isFeatured: true
        ),
        SportsCompetition(
            id: "cricket/t20i", key: "T20I Cricket", sport: .cricket,
            name: "T20 Internationals", shortName: "T20I", priority: 11, isFeatured: true
        ),
        SportsCompetition(
            id: "cricket/odi", key: "ODI Cricket", sport: .cricket,
            name: "One Day Internationals", shortName: "ODI", priority: 12, isFeatured: true
        ),
        SportsCompetition(
            id: "cricket/test", key: "Test Cricket", sport: .cricket,
            name: "Test Series", shortName: "Test", priority: 13, isFeatured: true
        ),
        SportsCompetition(
            id: "cricket/bbl", key: "Big Bash League", sport: .cricket,
            name: "Big Bash League", shortName: "BBL", priority: 14, isFeatured: false
        ),
        SportsCompetition(
            id: "cricket/psl", key: "Pakistan Super League", sport: .cricket,
            name: "Pakistan Super League", shortName: "PSL", priority: 15, isFeatured: false
        ),
    ]

    public static let all: [SportsCompetition] = football + cricket

    public static var featuredIDs: [String] {
        all.filter(\.isFeatured).map(\.id)
    }

    public static func competitions(for sport: Sport) -> [SportsCompetition] {
        all.filter { $0.sport == sport }
    }

    public static func competition(id: String) -> SportsCompetition? {
        all.first { $0.id == id }
    }

    public static func competition(
        for leagueName: String,
        sport: Sport,
        teamNames: [String] = []
    ) -> SportsCompetition? {
        let value = normalized(leagueName)
        if sport == .cricket {
            let teams = normalized(teamNames.joined(separator: " "))
            if containsAny(teams, [
                "mumbai indians", "chennai super kings", "royal challengers",
                "kolkata knight riders", "sunrisers hyderabad", "rajasthan royals",
                "delhi capitals", "punjab kings", "gujarat titans", "lucknow super giants",
            ]) {
                return competition(id: "cricket/ipl")
            }
            if containsAny(teams, [
                "sydney sixers", "perth scorchers", "melbourne stars", "melbourne renegades",
                "brisbane heat", "adelaide strikers", "hobart hurricanes", "sydney thunder",
            ]) {
                return competition(id: "cricket/bbl")
            }
            if containsAny(teams, [
                "karachi kings", "lahore qalandars", "peshawar zalmi",
                "quetta gladiators", "islamabad united", "multan sultans",
            ]) {
                return competition(id: "cricket/psl")
            }
        }
        switch sport {
        case .football:
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
        case .cricket:
            if value.contains("indian premier league") || value == "ipl" {
                return competition(id: "cricket/ipl")
            }
            if value.contains("t20i") || value == "t20" {
                return competition(id: "cricket/t20i")
            }
            if value.contains("odi") || value.contains("one day international") {
                return competition(id: "cricket/odi")
            }
            if value.contains("test") {
                return competition(id: "cricket/test")
            }
            if value.contains("big bash") {
                return competition(id: "cricket/bbl")
            }
            if value.contains("pakistan super league") || value == "psl" {
                return competition(id: "cricket/psl")
            }
        }
        return nil
    }

    /// A stable fallback for a competition we have never seen before.
    public static func fallback(for leagueName: String, sport: Sport) -> SportsCompetition {
        let slug = normalized(leagueName).replacingOccurrences(of: " ", with: "-")
        return SportsCompetition(
            id: "\(sport.rawValue)/\(slug.isEmpty ? "other" : slug)",
            key: leagueName,
            sport: sport,
            name: leagueName,
            shortName: leagueName,
            priority: 90,
            isFeatured: false
        )
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
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

// MARK: - Score and detail

public enum SportsMatchState: String, Codable, Sendable {
    case scheduled
    case live
    case breakTime
    case finished
    case postponed
    case cancelled
    case suspended

    public var isLive: Bool {
        self == .live || self == .breakTime
    }

    public var isFinished: Bool {
        self == .finished
    }

    public init?(providerStatus: String) {
        switch providerStatus.lowercased() {
        case "scheduled", "ns", "not_started": self = .scheduled
        case "live", "in_progress", "inprogress", "1h", "2h", "ht", "et", "p": self = .live
        case "break", "innings_break", "inningsbreak", "stumps": self = .breakTime
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

public struct SportsCricketState: Hashable, Sendable {
    public var innings: Int?
    public var battingTeam: String?
    public var runs: Int?
    public var wickets: Int?
    public var overs: Double?
    public var runRate: Double?
    public var target: Int?
    public var requiredRate: Double?
    public var resultMethod: String?
    public var recordedAt: Date?

    public init(
        innings: Int? = nil,
        battingTeam: String? = nil,
        runs: Int? = nil,
        wickets: Int? = nil,
        overs: Double? = nil,
        runRate: Double? = nil,
        target: Int? = nil,
        requiredRate: Double? = nil,
        resultMethod: String? = nil,
        recordedAt: Date? = nil
    ) {
        self.innings = innings
        self.battingTeam = battingTeam
        self.runs = runs
        self.wickets = wickets
        self.overs = overs
        self.runRate = runRate
        self.target = target
        self.requiredRate = requiredRate
        self.resultMethod = resultMethod
        self.recordedAt = recordedAt
    }

    public var scoreLine: String? {
        guard let runs else { return nil }
        let wicketsText = wickets.map { "/\($0)" } ?? ""
        let oversText = overs.map { " (\(SportsFormat.overs($0)))" } ?? ""
        return "\(runs)\(wicketsText)\(oversText)"
    }
}

public enum SportsMatchDetail: Hashable, Sendable {
    case football([SportsFootballEvent])
    case cricket(SportsCricketState?)
}

// MARK: - Match

public struct SportsMatch: Identifiable, Hashable, Sendable {
    public let id: String
    public let sport: Sport
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
        sport: Sport,
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
        self.sport = sport
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
        switch sport {
        case .football:
            let home = homeScore.map(String.init) ?? "–"
            let away = awayScore.map(String.init) ?? "–"
            return "\(home)–\(away)"
        case .cricket:
            let home = homeScore.map(String.init) ?? "–"
            let away = awayScore.map(String.init) ?? "–"
            return "\(home)–\(away)"
        }
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
        let ipl = SportsCatalog.competition(id: "cricket/ipl")!
        let test = SportsCatalog.competition(id: "cricket/test")!
        let t20i = SportsCatalog.competition(id: "cricket/t20i")!

        let real = SportsTeam(id: "demo-real", name: "Real Madrid", shortName: "RMA", colorHex: "#F4F4F4")
        let barca = SportsTeam(id: "demo-barca", name: "Barcelona", shortName: "BAR", colorHex: "#A50044")
        let arsenal = SportsTeam(id: "demo-arsenal", name: "Arsenal", shortName: "ARS", colorHex: "#EF0107")
        let chelsea = SportsTeam(id: "demo-chelsea", name: "Chelsea", shortName: "CHE", colorHex: "#034694")
        let psg = SportsTeam(id: "demo-psg", name: "Paris Saint-Germain", shortName: "PSG", colorHex: "#004170")
        let bayern = SportsTeam(id: "demo-bayern", name: "Bayern München", shortName: "FCB", colorHex: "#DC052D")
        let liverpool = SportsTeam(id: "demo-liverpool", name: "Liverpool", shortName: "LIV", colorHex: "#C8102E")
        let city = SportsTeam(id: "demo-city", name: "Manchester City", shortName: "MCI", colorHex: "#6CABDD")
        let india = SportsTeam(id: "demo-india", name: "India", shortName: "IND", colorHex: "#1A73E8")
        let australia = SportsTeam(id: "demo-australia", name: "Australia", shortName: "AUS", colorHex: "#FFCD00")
        let mi = SportsTeam(id: "demo-mi", name: "Mumbai Indians", shortName: "MI", colorHex: "#004BA0")
        let csk = SportsTeam(id: "demo-csk", name: "Chennai Super Kings", shortName: "CSK", colorHex: "#F9CD05")
        let england = SportsTeam(id: "demo-england", name: "England", shortName: "ENG", colorHex: "#CE1124")
        let pakistan = SportsTeam(id: "demo-pakistan", name: "Pakistan", shortName: "PAK", colorHex: "#01411C")

        return [
            SportsMatch(
                id: "demo-football-1", sport: .football, competition: laliga,
                home: real, away: barca, start: now.addingTimeInterval(-67 * 60),
                state: .live, homeScore: 2, awayScore: 1,
                statusText: "67'", round: "Matchday 12", venue: "Santiago Bernabéu",
                lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-cricket-1", sport: .cricket, competition: test,
                home: india, away: australia, start: now.addingTimeInterval(-3 * 3600),
                state: .live, homeScore: 245, awayScore: 289,
                statusText: "Day 3 · India trail by 44", round: "3rd Test",
                venue: "Eden Gardens", lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-football-2", sport: .football, competition: ucl,
                home: psg, away: bayern, start: now.addingTimeInterval(-54 * 60),
                state: .live, homeScore: 1, awayScore: 1,
                statusText: "54'", round: "League phase", venue: "Parc des Princes",
                lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-cricket-2", sport: .cricket, competition: ipl,
                home: mi, away: csk, start: now.addingTimeInterval(-17 * 60),
                state: .live, homeScore: 186, awayScore: 189,
                statusText: "17.2 overs", round: "Match 34", venue: "Wankhede Stadium",
                lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-football-3", sport: .football, competition: epl,
                home: arsenal, away: chelsea, start: now.addingTimeInterval(-23 * 60),
                state: .live, homeScore: 0, awayScore: 0,
                statusText: "23'", round: "Matchday 12", venue: "Emirates Stadium",
                lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-football-4", sport: .football, competition: epl,
                home: liverpool, away: city, start: now.addingTimeInterval(3 * 3600),
                state: .scheduled, statusText: "Today", round: "Matchday 12",
                venue: "Anfield", lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-cricket-3", sport: .cricket, competition: t20i,
                home: england, away: pakistan, start: now.addingTimeInterval(5 * 3600),
                state: .scheduled, statusText: "Today", round: "3rd T20I",
                venue: "Old Trafford", lastUpdated: now, isDemo: true
            ),
            SportsMatch(
                id: "demo-football-5", sport: .football, competition: laliga,
                home: barca, away: real, start: now.addingTimeInterval(26 * 3600),
                state: .scheduled, statusText: "Tomorrow", round: "Matchday 13",
                venue: "Spotify Camp Nou", lastUpdated: now, isDemo: true
            ),
        ]
    }

    public static func details(now: Date = Date()) -> [String: SportsMatchDetail] {
        [
            "demo-football-1": .football([
                SportsFootballEvent(id: "demo-e1", minute: 18, kind: .goal, player: "Vinícius Júnior", team: "Real Madrid", detail: "Right-footed finish"),
                SportsFootballEvent(id: "demo-e2", minute: 34, kind: .yellowCard, player: "Gavi", team: "Barcelona", detail: "Late challenge"),
                SportsFootballEvent(id: "demo-e3", minute: 41, kind: .goal, player: "Robert Lewandowski", team: "Barcelona", detail: "Header from a corner"),
                SportsFootballEvent(id: "demo-e4", minute: 58, kind: .goal, player: "Jude Bellingham", team: "Real Madrid", detail: "Low drive from the edge of the box"),
            ]),
            "demo-football-2": .football([
                SportsFootballEvent(id: "demo-e5", minute: 12, kind: .goal, player: "Ousmane Dembélé", team: "Paris Saint-Germain", detail: "Counter-attack"),
                SportsFootballEvent(id: "demo-e6", minute: 39, kind: .goal, player: "Harry Kane", team: "Bayern München", detail: "Penalty"),
            ]),
            "demo-football-3": .football([]),
            "demo-cricket-1": .cricket(SportsCricketState(
                innings: 2, battingTeam: "India", runs: 245, wickets: 6, overs: 82.4,
                runRate: 2.96, target: 290, requiredRate: 0.61,
                recordedAt: now
            )),
            "demo-cricket-2": .cricket(SportsCricketState(
                innings: 2, battingTeam: "Mumbai Indians", runs: 186, wickets: 4, overs: 17.2,
                runRate: 10.73, target: 190, requiredRate: 4.0,
                recordedAt: now
            )),
        ]
    }
}
