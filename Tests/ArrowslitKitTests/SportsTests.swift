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
        competition: competition,
        home: home,
        away: away,
        start: start,
        state: state,
        homeScore: state.isLive ? 1 : nil,
        awayScore: state.isLive ? 0 : nil
    )
}

@Suite("Football catalog")
struct SportsCatalogTests {
    @Test func mapsProviderNamesToCanonicalCompetitions() {
        #expect(SportsCatalog.competition(for: "Premier League")?.id == "football/epl")
        #expect(SportsCatalog.competition(for: "La Liga")?.id == "football/laliga")
        #expect(SportsCatalog.competition(for: "UEFA Champions League")?.id == "football/ucl")
        #expect(SportsCatalog.competition(for: "Serie A")?.id == "football/seriea")
    }

    @Test func catalogContainsFootballOnly() {
        #expect(!SportsCatalog.all.isEmpty)
        #expect(SportsCatalog.all.allSatisfy { $0.id.hasPrefix("football/") })
        #expect(SportsCatalog.featuredIDs == ["football/epl", "football/laliga", "football/ucl"])
    }

    @Test func fallbackKeepsUnknownCompetitionsVisible() {
        let competition = SportsCatalog.fallback(for: "A New Cup")
        #expect(competition.id == "football/a-new-cup")
        #expect(competition.name == "A New Cup")
        #expect(!competition.isFeatured)
    }
}

@Suite("Football ranking")
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

    @Test func filtersByCompetition() {
        let football = sportsMatch(id: "f", competition: epl, home: arsenal, away: chelsea, state: .live)
        let other = sportsMatch(id: "o", competition: laliga, home: real, away: barca, state: .live)
        #expect(SportsRanking.filtered([football, other], competitionID: nil).map(\.id) == ["f", "o"])
        #expect(SportsRanking.filtered([football, other], competitionID: "football/epl").map(\.id) == ["f"])
    }
}

@Suite("Football formatting")
struct SportsFormattingTests {
    @Test func formatsKickoffAndStatus() {
        let epl = SportsCatalog.competition(id: "football/epl")!
        let match = SportsMatch(
            id: "m", competition: epl,
            home: SportsTeam(id: "a", name: "Arsenal"),
            away: SportsTeam(id: "b", name: "Chelsea"),
            start: sportsBase, state: .finished
        )
        #expect(SportsFormat.status(match, now: sportsBase) == "FT")
        #expect(SportsFormat.relativeStart(match, now: sportsBase) == "FT")
        #expect(SportsFormat.kickoff(sportsBase, now: sportsBase) == sportsBase.formatted(date: .omitted, time: .shortened))
    }

    @Test func formatsQuota() {
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

    @Test func mapsProviderStatuses() {
        #expect(SportsMatchState(providerStatus: "in_progress") == .live)
        #expect(SportsMatchState(providerStatus: "live") == .live)
        #expect(SportsMatchState(providerStatus: "HT") == .halfTime)
        #expect(SportsMatchState(providerStatus: "FT") == .finished)
        #expect(SportsMatchState(providerStatus: "scheduled") == .scheduled)
        #expect(SportsMatchState(providerStatus: "postponed") == .postponed)
        #expect(SportsMatchState(providerStatus: "something-new") == nil)
    }
}

@Suite("Football demo")
struct SportsDemoTests {
    @Test func demoIncludesLiveAndUpcomingFootball() {
        let matches = SportsDemoData.matches(now: sportsBase)
        #expect(matches.contains { $0.isLive })
        #expect(matches.contains { $0.state == .scheduled })
        #expect(matches.allSatisfy { $0.competition.id.hasPrefix("football/") })
        let details = SportsDemoData.details(now: sportsBase)
        #expect(details["demo-football-1"] != nil)
        #expect(details["demo-football-4"] != nil)
    }
}

@Suite("BigBallsData decoding")
struct BigBallsDataDecodingTests {
    @Test func mapsFootballRowsAndSkipsOtherSports() throws {
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
              "sport": "basketball",
              "league": "NBA",
              "kickoff_utc": "2026-11-01T04:00:00Z",
              "status": "live",
              "home": { "id": "h2", "name": "India" },
              "away": { "id": "a2", "name": "Australia" },
              "score": { "home": 245, "away": 289 }
            }
          ]
        }
        """
        let matches = try BigBallsDataProvider.decodeMatches(from: Data(json.utf8))
        #expect(matches.count == 1)
        #expect(matches[0].competition.id == "football/epl")
        #expect(matches[0].state == .live)
        #expect(matches[0].homeScore == 2)
    }

    @Test func survivesLiveRowsWithoutIDsOrStrictTypes() throws {
        let json = """
        {
          "data": [
            {
              "sport": "football",
              "league": "La Liga",
              "kickoff_utc": "2026-11-01T20:00:00",
              "status": "live",
              "home": { "name": "Real Madrid" },
              "away": { "name": "Barcelona" },
              "score": { "home": "2", "away": 1 }
            }
          ],
          "meta": { "note": "match_id is omitted on live rows" }
        }
        """
        let matches = try BigBallsDataProvider.decodeMatches(from: Data(json.utf8))
        #expect(matches.count == 1)
        #expect(matches[0].id.hasPrefix("bbs-"))
        #expect(matches[0].homeScore == 2)
        #expect(matches[0].awayScore == 1)
        #expect(matches[0].competition.id == "football/laliga")
    }

    @Test func acceptsAMatchesObjectInsteadOfABareArray() throws {
        let json = """
        {
          "data": {
            "matches": [
              {
                "id": "f9",
                "sport": "football",
                "league": "Serie A",
                "kickoff_utc": "2026-11-01T04:00:00Z",
                "status": "live",
                "home": { "id": "h", "name": "Inter" },
                "away": { "id": "a", "name": "Milan" },
                "score": { "home": 1, "away": 0 }
              }
            ]
          }
        }
        """
        let matches = try BigBallsDataProvider.decodeMatches(from: Data(json.utf8))
        #expect(matches.count == 1)
        #expect(matches[0].id == "f9")
        #expect(matches[0].competition.id == "football/seriea")
    }
}

@Suite("BigBallsData transport")
struct BigBallsDataTransportTests {
    @Test func liveMatchesUnwrapsTheEnvelopeOnlyOnce() async throws {
        BBSURLProtocol.handler = { request in
            #expect(request.url?.path == "/v1/matches")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer bbs_live_test")
            let json = """
            {
              "data": [
                {
                  "id": "f1",
                  "sport": "football",
                  "league": "Premier League",
                  "kickoff_utc": "2026-11-01T15:00:00.000Z",
                  "status": "live",
                  "home": { "id": "h", "name": "Arsenal", "short_name": "ARS" },
                  "away": { "id": "a", "name": "Chelsea", "short_name": "CHE" },
                  "score": { "home": 2, "away": 1 }
                }
              ]
            }
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["X-RateLimit-Remaining": "42", "X-RateLimit-Limit": "250"]
            )!
            return (response, Data(json.utf8))
        }
        defer { BBSURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BBSURLProtocol.self]
        let provider = BigBallsDataProvider(
            apiKey: "bbs_live_test",
            session: URLSession(configuration: configuration)
        )
        let payload = try await provider.liveMatches()
        #expect(payload.matches.count == 1)
        #expect(payload.matches[0].competition.id == "football/epl")
        #expect(payload.matches[0].homeScore == 2)
        #expect(payload.quota.remaining == 42)
    }

    @Test func explainsWhenTheKeyCoversAnotherSport() async {
        BBSURLProtocol.handler = { request in
            let json = """
            {
              "error": {
                "code": "sport_not_included",
                "message": "Your plan covers Basketball. This request is for Soccer, which is not included."
              }
            }
            """
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(json.utf8))
        }
        defer { BBSURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BBSURLProtocol.self]
        let provider = BigBallsDataProvider(
            apiKey: "bbs_live_test",
            session: URLSession(configuration: configuration)
        )
        do {
            _ = try await provider.liveMatches()
            Issue.record("Expected a sport coverage error")
        } catch let error as SportsProviderError {
            guard case .sportNotIncluded(let message) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(message.contains("Basketball"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private final class BBSURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@MainActor
@Suite("Sports settings")
struct SportsSettingsTests {
    @Test func sportsStartsInPreviewAndPreferencesPersist() {
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
        settings.sportsCompetitionIDs = ["football/epl", "football/ucl"]
        settings.sportsFollowedTeams = ["arsenal"]
        settings.sportsPinnedMatchID = "match-1"

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.isTabEnabled(.sports))
        #expect(!reloaded.sportsPreview)
        #expect(reloaded.sportsRefreshSeconds == 30)
        #expect(!reloaded.sportsShowInNotch)
        #expect(reloaded.sportsCompetitionIDs == ["football/epl", "football/ucl"])
        #expect(reloaded.sportsFollowedTeams == ["arsenal"])
        #expect(reloaded.sportsPinnedMatchID == "match-1")
    }
}
