import Foundation
import Testing
@testable import ArrowslitKit

private let sportsBase = Date(timeIntervalSince1970: 1_800_000_000)

private func sportsMatch(
    id: String,
    competition: SportsCompetition,
    home: SportsTeam,
    away: SportsTeam,
    state: SportsMatchState,
    start: Date = sportsBase
) -> SportsMatch {
    SportsMatch(
        id: id,
        sport: competition.sport,
        competition: competition,
        home: home,
        away: away,
        start: start,
        state: state,
        homeScore: state.isLive ? 1 : nil,
        awayScore: state.isLive ? 0 : nil
    )
}

@Suite("Sports catalog")
struct SportsCatalogTests {
    @Test func mapsProviderNamesToCanonicalCompetitions() {
        #expect(SportsCatalog.competition(for: "Premier League", sport: .football)?.id == "football/epl")
        #expect(SportsCatalog.competition(for: "La Liga", sport: .football)?.id == "football/laliga")
        #expect(SportsCatalog.competition(for: "UEFA Champions League", sport: .football)?.id == "football/ucl")
        #expect(SportsCatalog.competition(for: "IPL", sport: .cricket)?.id == "cricket/ipl")
        #expect(SportsCatalog.competition(for: "T20I Cricket", sport: .cricket)?.id == "cricket/t20i")
        #expect(SportsCatalog.competition(for: "ODI Cricket", sport: .cricket)?.id == "cricket/odi")
        #expect(SportsCatalog.competition(for: "Test Cricket", sport: .cricket)?.id == "cricket/test")
    }

    @Test func fallbackKeepsUnknownCompetitionsVisible() {
        let competition = SportsCatalog.fallback(for: "A New Cup", sport: .football)
        #expect(competition.id == "football/a-new-cup")
        #expect(competition.name == "A New Cup")
        #expect(!competition.isFeatured)
    }
}

@Suite("Sports ranking")
struct SportsRankingTests {
    private let epl = SportsCatalog.competition(id: "football/epl")!
    private let laliga = SportsCatalog.competition(id: "football/laliga")!
    private let arsenal = SportsTeam(id: "arsenal", name: "Arsenal")
    private let chelsea = SportsTeam(id: "chelsea", name: "Chelsea")
    private let real = SportsTeam(id: "real", name: "Real Madrid")
    private let barca = SportsTeam(id: "barca", name: "Barcelona")

    @Test func pinnedComesBeforeLiveAndFollowing() {
        let pinned = sportsMatch(id: "pinned", competition: laliga, home: real, away: barca, state: .scheduled)
        let followed = sportsMatch(id: "followed", competition: laliga, home: real, away: barca, state: .live)
        let other = sportsMatch(id: "other", competition: epl, home: arsenal, away: chelsea, state: .live)

        let ranked = SportsRanking.rank(
            [other, followed, pinned],
            followedTeamIDs: ["real"],
            followedCompetitionIDs: ["football/laliga"],
            pinnedID: "pinned",
            now: sportsBase
        )
        #expect(ranked.map(\.id) == ["pinned", "followed", "other"])
    }

    @Test func filtersBySportAndCompetition() {
        let football = sportsMatch(id: "f", competition: epl, home: arsenal, away: chelsea, state: .live)
        let cricket = sportsMatch(
            id: "c",
            competition: SportsCatalog.competition(id: "cricket/ipl")!,
            home: SportsTeam(id: "mi", name: "Mumbai Indians"),
            away: SportsTeam(id: "csk", name: "Chennai Super Kings"),
            state: .live
        )
        #expect(SportsRanking.filtered([football, cricket], sport: .football, competitionID: nil).map(\.id) == ["f"])
        #expect(SportsRanking.filtered([football, cricket], sport: .cricket, competitionID: "cricket/ipl").map(\.id) == ["c"])
    }
}

@Suite("BigBallsData decoding")
struct BigBallsDataDecodingTests {
    @Test func mapsFootballAndCricketRowsAndSkipsOtherSports() throws {
        let json = """
        {
          "data": [
            {
              "id": "f1",
              "sport": "football",
              "league": "Premier League",
              "kickoff_utc": "2026-11-01T15:00:00.000Z",
              "status": "in_progress",
              "home": { "id": "h1", "name": "Arsenal", "short_name": "ARS" },
              "away": { "id": "a1", "name": "Chelsea", "short_name": "CHE" },
              "score": { "home": 2, "away": 1 },
              "round": "Matchday 12"
            },
            {
              "id": "c1",
              "sport": "cricket",
              "league": "Test Cricket",
              "kickoff_utc": "2026-11-01T04:00:00Z",
              "status": "live",
              "home": { "id": "h2", "name": "India", "short_name": "IND" },
              "away": { "id": "a2", "name": "Australia", "short_name": "AUS" },
              "score": { "home": 245, "away": 289 }
            },
            {
              "id": "b1",
              "sport": "basketball",
              "league": "NBA",
              "kickoff_utc": "2026-11-01T00:00:00Z",
              "status": "live",
              "home": { "id": "h3", "name": "Home" },
              "away": { "id": "a3", "name": "Away" }
            }
          ]
        }
        """
        let matches = try BigBallsDataProvider.decodeMatches(from: Data(json.utf8))
        #expect(matches.count == 2)
        #expect(matches[0].competition.id == "football/epl")
        #expect(matches[0].state == .live)
        #expect(matches[0].homeScore == 2)
        #expect(matches[1].competition.id == "cricket/test")
        #expect(matches[1].home.shortName == "IND")
    }
}

@Suite("Sports formatting")
struct SportsFormattingTests {
    @Test func formatsOversAndQuota() {
        #expect(SportsFormat.overs(42.3) == "42.3")
        #expect(SportsFormat.overs(42) == "42")
        #expect(SportsFormat.runRate(7.333) == "7.33")

        var quota = SportsQuota()
        quota.merge(headers: [
            "X-RateLimit-Limit": "250",
            "X-RateLimit-Remaining": "37",
            "X-RateLimit-Reset": "1763510400",
        ])
        #expect(quota.limit == 250)
        #expect(quota.remaining == 37)
        #expect(quota.resetAt != nil)
        #expect(quota.summary == "37 of 250 requests left today")
    }

    @Test func cricketDetailDoesNotRepeatTheScore() {
        let state = SportsCricketState(
            innings: 2, battingTeam: "India", runs: 245, wickets: 6, overs: 82.4,
            runRate: 2.96, target: 290, requiredRate: 0.61
        )
        #expect(SportsFormat.cricketDetailLine(state) == "RR 2.96 · Need 45 at 0.61")
    }

    @Test func compactStatusKeepsTheMatchClock() {
        let live = SportsDemoData.matches(now: sportsBase).first { $0.sport == .football && $0.isLive }!
        #expect(SportsFormat.compactStatus(live) == "67'")
    }

    @Test func mapsProviderStatuses() {
        #expect(SportsMatchState(providerStatus: "in_progress") == .live)
        #expect(SportsMatchState(providerStatus: "live") == .live)
        #expect(SportsMatchState(providerStatus: "FT") == .finished)
        #expect(SportsMatchState(providerStatus: "scheduled") == .scheduled)
        #expect(SportsMatchState(providerStatus: "postponed") == .postponed)
        #expect(SportsMatchState(providerStatus: "something-new") == nil)
    }
}

@Suite("Sports demo")
struct SportsDemoTests {
    @Test func demoIncludesBothSportsAndDetails() {
        let matches = SportsDemoData.matches(now: sportsBase)
        #expect(matches.contains { $0.sport == .football && $0.isLive })
        #expect(matches.contains { $0.sport == .cricket && $0.isLive })
        #expect(matches.contains { $0.state == .scheduled })
        let details = SportsDemoData.details(now: sportsBase)
        #expect(details["demo-football-1"] != nil)
        #expect(details["demo-cricket-1"] != nil)
    }
}

@MainActor
@Suite("Sports settings")
struct SportsSettingsTests {
    @Test func sportsStartsOffAndPreferencesPersist() {
        let name = "ArrowslitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = SettingsStore(defaults: defaults)
        #expect(settings.isTabEnabled(.sports))
        #expect(settings.sportsPreview)
        #expect(settings.sportsRefreshSeconds == 60)
        #expect(settings.sportsCompetitionIDs.contains("football/epl"))

        settings.setTabEnabled(.sports, true)
        settings.sportsPreview = false
        settings.sportsRefreshSeconds = 30
        settings.sportsShowInNotch = false
        settings.sportsCompetitionIDs = ["football/epl", "cricket/ipl"]
        settings.sportsFollowedTeams = ["arsenal"]
        settings.sportsPinnedMatchID = "match-1"

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.isTabEnabled(.sports))
        #expect(!reloaded.sportsPreview)
        #expect(reloaded.sportsRefreshSeconds == 30)
        #expect(!reloaded.sportsShowInNotch)
        #expect(reloaded.sportsCompetitionIDs == ["football/epl", "cricket/ipl"])
        #expect(reloaded.sportsFollowedTeams == ["arsenal"])
        #expect(reloaded.sportsPinnedMatchID == "match-1")
    }
}
