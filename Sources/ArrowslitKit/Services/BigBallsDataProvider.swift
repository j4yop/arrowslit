import Foundation

// MARK: - Provider value types

public struct SportsProviderPayload: Sendable {
    public var matches: [SportsMatch]
    public var quota: SportsQuota

    public init(matches: [SportsMatch], quota: SportsQuota) {
        self.matches = matches
        self.quota = quota
    }
}

public struct SportsAccount: Sendable {
    public var plan: String
    public var perMinute: Int?
    public var perDay: Int?

    public init(plan: String, perMinute: Int?, perDay: Int?) {
        self.plan = plan
        self.perMinute = perMinute
        self.perDay = perDay
    }
}

public enum SportsProviderError: LocalizedError {
    case missingKey
    case unauthorized
    case forbidden
    case rateLimited(retryAfter: TimeInterval?, quota: SportsQuota)
    case http(Int, String?)
    case invalidResponse
    case decoding(String)
    case network(String)
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .missingKey:
            "Add your BigBallsData API key in Settings."
        case .unauthorized:
            "BigBallsData did not accept that key. Replace it in Settings."
        case .forbidden:
            "This BigBallsData plan does not include that endpoint."
        case .rateLimited(_, let quota):
            if let reset = quota.resetAt {
                "BigBallsData's free daily limit is used up. It resets \(reset.formatted(date: .abbreviated, time: .shortened))."
            } else {
                "BigBallsData's free daily limit is used up. Try again after midnight UTC."
            }
        case .http(let status, let message):
            message ?? "BigBallsData returned HTTP \(status)."
        case .invalidResponse:
            "BigBallsData returned an unreadable response."
        case .decoding:
            "BigBallsData returned data Arrowslit could not read."
        case .network:
            "Couldn't reach BigBallsData. Check your connection and try again."
        case .message(let message):
            message
        }
    }
}

// MARK: - Provider

/// BigBallsData's free tier. One key, one all-sports live request per refresh.
public struct BigBallsDataProvider: Sendable {
    public let apiKey: String
    public let session: URLSession

    private static let baseURL = URL(string: "https://api.bigballsdata.com")!

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func liveMatches(includeCricket: Bool = true) async throws -> SportsProviderPayload {
        var query = [
            URLQueryItem(name: "status", value: "live"),
            URLQueryItem(name: "limit", value: "200"),
        ]
        // The all-sports form is one request. If a caller only follows football,
        // skip the cricket fallback entirely.
        if !includeCricket {
            query.insert(URLQueryItem(name: "sport", value: "football"), at: 0)
        }
        var payload = try await getMatches(path: "/v1/matches", query: query)

        // The all-sports form is documented to include every sport. If cricket is
        // followed and the response carried none, make one explicit cricket call.
        // This costs one extra request, not one per match, and only when needed.
        if includeCricket,
           !payload.matches.contains(where: { $0.sport == .cricket }),
           payload.quota.remaining.map({ $0 > 20 }) ?? true {
            if let cricket = try? await getMatches(
                path: "/v1/cricket/matches",
                query: [
                    URLQueryItem(name: "status", value: "live"),
                    URLQueryItem(name: "limit", value: "200"),
                ]
            ) {
                payload.matches += cricket.matches
                payload.quota = cricket.quota
            }
        }
        return payload
    }

    public func upcoming(for competition: SportsCompetition, limit: Int = 20) async throws -> SportsProviderPayload {
        let query: [URLQueryItem]
        let path: String
        switch competition.sport {
        case .football:
            path = "/v1/matches"
            query = [
                URLQueryItem(name: "sport", value: "football"),
                URLQueryItem(name: "league", value: competition.key),
                URLQueryItem(name: "status", value: "scheduled"),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
        case .cricket:
            path = "/v1/cricket/matches"
            query = [
                URLQueryItem(name: "series", value: competition.key),
                URLQueryItem(name: "status", value: "scheduled"),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
        }
        let payload = try await getMatches(path: path, query: query)
        let now = Date()
        return SportsProviderPayload(
            matches: payload.matches
                .filter { $0.start >= now.addingTimeInterval(-3600) }
                .sorted { $0.start < $1.start },
            quota: payload.quota
        )
    }

    public func events(for matchID: String) async throws -> (events: [SportsFootballEvent], quota: SportsQuota) {
        let response: (BBSEnvelope<[BBSFootballEvent]>, SportsQuota) = try await get(
            path: "/v1/matches/\(matchID)/events"
        )
        guard let rows = response.0.data else { throw SportsProviderError.invalidResponse }
        let events = rows.enumerated().compactMap { index, row -> SportsFootballEvent? in
            let sequence = row.sequenceNumber ?? (index + 1)
            let kind: SportsFootballEvent.Kind
            let type = (row.eventType ?? "").lowercased()
            if row.scoringPlay == true || type.contains("goal") || type.contains("score") {
                kind = .goal
            } else if type.contains("yellow") {
                kind = .yellowCard
            } else if type.contains("red") {
                kind = .redCard
            } else if type.contains("substitution") || type.contains("sub") {
                kind = .substitution
            } else {
                kind = .other
            }
            return SportsFootballEvent(
                id: String(sequence),
                minute: row.elapsed,
                extraMinute: row.elapsedExtra,
                kind: kind,
                player: row.playerName,
                team: row.team,
                detail: row.description ?? row.eventDetail
            )
        }
        .sorted { ($0.minute ?? 0) < ($1.minute ?? 0) }
        return (Array(events.suffix(12)), response.1)
    }

    public func cricketState(for matchID: String) async throws -> (state: SportsCricketState?, quota: SportsQuota) {
        let response: (BBSEnvelope<BBSCricketStateEnvelope>, SportsQuota) = try await get(
            path: "/v1/cricket/matches/\(matchID)/state"
        )
        guard let envelope = response.0.data else { throw SportsProviderError.invalidResponse }
        guard let state = envelope.state else { return (nil, response.1) }
        return (
            SportsCricketState(
                innings: state.inningsNumber,
                battingTeam: state.battingTeam?.name,
                runs: state.runsScored,
                wickets: state.wicketsFallen,
                overs: state.oversBowled,
                runRate: state.currentRunRate,
                target: state.target,
                requiredRate: state.requiredRunRate,
                resultMethod: state.resultMethod,
                recordedAt: state.recordedAt
            ),
            response.1
        )
    }

    public func validate() async throws -> (account: SportsAccount, quota: SportsQuota) {
        let response: (BBSEnvelope<BBSUser>, SportsQuota) = try await get(path: "/v1/user/me")
        guard let user = response.0.data else { throw SportsProviderError.invalidResponse }
        return (
            SportsAccount(
                plan: user.plan ?? "free",
                perMinute: user.limits?.perMinute,
                perDay: user.limits?.perDay
            ),
            response.1
        )
    }

    // MARK: - Requests

    private func getMatches(path: String, query: [URLQueryItem]) async throws -> SportsProviderPayload {
        let response: (BBSEnvelope<[BBSMatch]>, SportsQuota) = try await get(path: path, query: query)
        guard let rows = response.0.data else { throw SportsProviderError.invalidResponse }
        return SportsProviderPayload(matches: Self.map(rows, now: Date()), quota: response.1)
    }

    /// Decodes a `/v1/matches` or `/v1/cricket/matches` envelope. Exposed for
    /// tests so the wire format can be exercised without a live key.
    public static func decodeMatches(from data: Data, now: Date = Date()) throws -> [SportsMatch] {
        let envelope = try decoder().decode(BBSEnvelope<[BBSMatch]>.self, from: data)
        guard let rows = envelope.data else { throw SportsProviderError.invalidResponse }
        return map(rows, now: now)
    }

    private static func map(_ rows: [BBSMatch], now: Date) -> [SportsMatch] {
        rows.compactMap { row -> SportsMatch? in
            guard let sport = Sport(rawValue: row.sport) else { return nil }
            guard sport == .football || sport == .cricket else { return nil }
            guard let state = SportsMatchState(providerStatus: row.status) else { return nil }
            let competition = SportsCatalog.competition(
                for: row.league,
                sport: sport,
                teamNames: [row.home.name, row.away.name]
            ) ?? SportsCatalog.fallback(for: row.league, sport: sport)
            return SportsMatch(
                id: row.id,
                sport: sport,
                competition: competition,
                home: SportsTeam(
                    id: row.home.id,
                    name: row.home.name,
                    shortName: row.home.shortName,
                    colorHex: nil
                ),
                away: SportsTeam(
                    id: row.away.id,
                    name: row.away.name,
                    shortName: row.away.shortName,
                    colorHex: nil
                ),
                start: row.kickoffUTC,
                state: state,
                homeScore: row.score?.home,
                awayScore: row.score?.away,
                statusText: row.status,
                round: row.round,
                venue: row.venue,
                lastUpdated: now
            )
        }
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = parseDate(value) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognised date: \(value)"
            )
        }
        return decoder
    }

    private func get<T: Decodable>(
        path: String,
        query: [URLQueryItem] = []
    ) async throws -> (T, SportsQuota) {
        guard let relative = URL(string: path, relativeTo: Self.baseURL),
              var components = URLComponents(url: relative, resolvingAgainstBaseURL: true) else {
            throw SportsProviderError.invalidResponse
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw SportsProviderError.invalidResponse }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Arrowslit", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SportsProviderError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SportsProviderError.invalidResponse
        }
        var quota = SportsQuota()
        quota.merge(headers: http.allHeaderFields.reduce(into: [String: String]()) { result, item in
            if let key = item.key as? String, let value = item.value as? String {
                result[key] = value
            }
        })

        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(BBSErrorEnvelope.self, from: data))?.error?.message
            switch http.statusCode {
            case 401:
                throw SportsProviderError.unauthorized
            case 403:
                throw SportsProviderError.forbidden
            case 429:
                throw SportsProviderError.rateLimited(retryAfter: quota.retryAfter, quota: quota)
            default:
                throw SportsProviderError.http(http.statusCode, message)
            }
        }

        do {
            let envelope = try Self.decoder().decode(BBSEnvelope<T>.self, from: data)
            if let error = envelope.error {
                throw SportsProviderError.message(error.message ?? "BigBallsData returned an error.")
            }
            guard let data = envelope.data else {
                throw SportsProviderError.invalidResponse
            }
            return (data, quota)
        } catch let error as SportsProviderError {
            throw error
        } catch {
            throw SportsProviderError.decoding(error.localizedDescription)
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

// MARK: - Wire types

private struct BBSEnvelope<T: Decodable>: Decodable {
    var data: T?
    var error: BBSError?
    var meta: BBSMeta?
}

private struct BBSErrorEnvelope: Decodable {
    var error: BBSError?
}

private struct BBSError: Decodable {
    var code: String?
    var message: String?
}

private struct BBSMeta: Decodable {
    var source: String?
    var cached: Bool?
    var confidence: Double?
    var requestID: String?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case source, cached, confidence, note
        case requestID = "request_id"
    }
}

private struct BBSMatch: Decodable {
    var id: String
    var sport: String
    var league: String
    var kickoffUTC: Date
    var status: String
    var home: BBSSide
    var away: BBSSide
    var score: BBSScore?
    var round: String?
    var venue: String?

    enum CodingKeys: String, CodingKey {
        case id, sport, league, status, home, away, score, round, venue
        case kickoffUTC = "kickoff_utc"
    }
}

private struct BBSSide: Decodable {
    var id: String
    var name: String
    var shortName: String?
    var logoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case shortName = "short_name"
        case logoURL = "logo_url"
    }
}

private struct BBSScore: Decodable {
    var home: Int?
    var away: Int?
}

private struct BBSFootballEvent: Decodable {
    var sequenceNumber: Int?
    var elapsed: Int?
    var elapsedExtra: Int?
    var team: String?
    var playerName: String?
    var eventType: String?
    var eventDetail: String?
    var description: String?
    var scoringPlay: Bool?

    enum CodingKeys: String, CodingKey {
        case elapsed, team, description
        case sequenceNumber = "sequence_number"
        case elapsedExtra = "elapsed_extra"
        case playerName = "player_name"
        case eventType = "event_type"
        case eventDetail = "event_detail"
        case scoringPlay = "scoring_play"
    }
}

private struct BBSCricketStateEnvelope: Decodable {
    var matchID: String?
    var state: BBSCricketState?

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case state
    }
}

private struct BBSCricketState: Decodable {
    var inningsNumber: Int?
    var battingTeam: BBSTeamRef?
    var oversBowled: Double?
    var runsScored: Int?
    var wicketsFallen: Int?
    var currentRunRate: Double?
    var target: Int?
    var requiredRunRate: Double?
    var resultMethod: String?
    var recordedAt: Date?

    enum CodingKeys: String, CodingKey {
        case target
        case inningsNumber = "innings_number"
        case battingTeam = "batting_team"
        case oversBowled = "overs_bowled"
        case runsScored = "runs_scored"
        case wicketsFallen = "wickets_fallen"
        case currentRunRate = "current_run_rate"
        case requiredRunRate = "required_run_rate"
        case resultMethod = "result_method"
        case recordedAt = "recorded_at"
    }
}

private struct BBSTeamRef: Decodable {
    var id: String?
    var name: String?
}

private struct BBSUser: Decodable {
    var plan: String?
    var limits: BBSLimits?
}

private struct BBSLimits: Decodable {
    var perMinute: Int?
    var perDay: Int?

    enum CodingKeys: String, CodingKey {
        case perMinute = "per_minute"
        case perDay = "per_day"
    }
}
