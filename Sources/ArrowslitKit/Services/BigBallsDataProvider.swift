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
        case .decoding(let reason):
            "BigBallsData returned data Arrowslit could not read. \(reason.prefix(180))"
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

    public func liveMatches(allowCricketFallback: Bool = true) async throws -> SportsProviderPayload {
        let query = [
            URLQueryItem(name: "status", value: "live"),
            URLQueryItem(name: "limit", value: "200"),
        ]
        var payload = try await getMatches(path: "/v1/matches", query: query)

        // The all-sports form is documented to include every sport. If cricket is
        // followed and the response carried none, make one explicit cricket call.
        // The caller only allows this once per session, so a quiet cricket day
        // cannot double every poll.
        if allowCricketFallback,
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
        let response: ([BBSFootballEvent], SportsQuota) = try await get(
            path: "/v1/matches/\(matchID)/events"
        )
        let rows = response.0
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
        let response: (BBSCricketStateEnvelope, SportsQuota) = try await get(
            path: "/v1/cricket/matches/\(matchID)/state"
        )
        guard let state = response.0.state else { return (nil, response.1) }
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
        let response: (BBSUser, SportsQuota) = try await get(path: "/v1/user/me")
        let user = response.0
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
        let response: (BBSMatchList, SportsQuota) = try await get(path: path, query: query)
        return SportsProviderPayload(matches: Self.map(response.0.matches, now: Date()), quota: response.1)
    }

    /// Decodes a `/v1/matches` or `/v1/cricket/matches` envelope. Exposed for
    /// tests so the wire format can be exercised without a live key.
    public static func decodeMatches(from data: Data, now: Date = Date()) throws -> [SportsMatch] {
        let envelope = try decoder().decode(BBSEnvelope<BBSMatchList>.self, from: data)
        guard let rows = envelope.data?.matches else { throw SportsProviderError.invalidResponse }
        return map(rows, now: now)
    }

    private static func map(_ rows: [BBSMatch], now: Date) -> [SportsMatch] {
        rows.compactMap { row -> SportsMatch? in
            guard let sportName = row.sport,
                  let sport = Sport(rawValue: sportName),
                  sport == .football || sport == .cricket,
                  let home = row.home,
                  let away = row.away,
                  let homeName = home.name ?? home.shortName,
                  let awayName = away.name ?? away.shortName else {
                return nil
            }
            let league = row.league ?? "Sports"
            let start = row.kickoffUTC?.value
            let state = row.status.flatMap(SportsMatchState.init(providerStatus:)) ?? .live
            let competition = SportsCatalog.competition(
                for: league,
                sport: sport,
                teamNames: [homeName, awayName]
            ) ?? SportsCatalog.fallback(for: league, sport: sport)
            return SportsMatch(
                id: row.id ?? fallbackID(
                    sport: sport,
                    league: league,
                    home: homeName,
                    away: awayName,
                    start: start
                ),
                sport: sport,
                competition: competition,
                home: SportsTeam(
                    id: home.id ?? fallbackTeamID(homeName),
                    name: homeName,
                    shortName: home.shortName,
                    colorHex: nil
                ),
                away: SportsTeam(
                    id: away.id ?? fallbackTeamID(awayName),
                    name: awayName,
                    shortName: away.shortName,
                    colorHex: nil
                ),
                start: start ?? now,
                state: state,
                homeScore: row.score?.home.value,
                awayScore: row.score?.away.value,
                statusText: row.status ?? "live",
                round: row.round,
                venue: row.venue,
                lastUpdated: now
            )
        }
    }

    private static func fallbackID(
        sport: Sport,
        league: String,
        home: String,
        away: String,
        start: Date?
    ) -> String {
        let startKey = start.map { String(Int($0.timeIntervalSince1970)) } ?? "unknown"
        return "bbs-\(stableHash("\(sport.rawValue)|\(league)|\(home)|\(away)|\(startKey)"))"
    }

    private static func fallbackTeamID(_ name: String) -> String {
        "team-\(stableHash(name))"
    }

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in value.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
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

    fileprivate static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: value) { return date }

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}

// MARK: - Wire types

private struct BBSEnvelope<T: Decodable>: Decodable {
    var data: T?
    var error: BBSError?
    var meta: BBSMeta?

    enum CodingKeys: String, CodingKey {
        case data, error, meta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try? container.decode(T.self, forKey: .data)
        error = try? container.decode(BBSError.self, forKey: .error)
        meta = try? container.decode(BBSMeta.self, forKey: .meta)
    }
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

private struct BBSMatchList: Decodable {
    var matches: [BBSMatch]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let rows = try? container.decode([BBSMatch].self) {
            matches = rows
            return
        }
        if let object = try? container.decode(Object.self) {
            matches = object.matches ?? object.data ?? object.items ?? object.results ?? []
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected a match array or an object containing one."
        )
    }

    private struct Object: Decodable {
        var matches: [BBSMatch]?
        var data: [BBSMatch]?
        var items: [BBSMatch]?
        var results: [BBSMatch]?
    }
}

private struct BBSMatch: Decodable {
    var id: String?
    var sport: String?
    var league: String?
    var kickoffUTC: BBSDate?
    var status: String?
    var home: BBSSide?
    var away: BBSSide?
    var score: BBSScore?
    var round: String?
    var venue: String?

    enum CodingKeys: String, CodingKey {
        case id, sport, league, status, home, away, score, round, venue
        case kickoffUTC = "kickoff_utc"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(String.self, forKey: .id)
        sport = try? container.decode(String.self, forKey: .sport)
        league = try? container.decode(String.self, forKey: .league)
        kickoffUTC = try? container.decode(BBSDate.self, forKey: .kickoffUTC)
        status = try? container.decode(String.self, forKey: .status)
        home = try? container.decode(BBSSide.self, forKey: .home)
        away = try? container.decode(BBSSide.self, forKey: .away)
        score = try? container.decode(BBSScore.self, forKey: .score)
        round = try? container.decode(String.self, forKey: .round)
        venue = try? container.decode(String.self, forKey: .venue)
    }
}

private struct BBSSide: Decodable {
    var id: String?
    var name: String?
    var shortName: String?
    var logoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case shortName = "short_name"
        case logoURL = "logo_url"
        case teamID = "team_id"
        case teamName = "team_name"
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let value = try? single.decode(String.self) {
            id = nil
            name = value
            shortName = nil
            logoURL = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id))
            ?? (try? container.decode(String.self, forKey: .teamID))
        name = (try? container.decode(String.self, forKey: .name))
            ?? (try? container.decode(String.self, forKey: .teamName))
        shortName = try? container.decode(String.self, forKey: .shortName)
        logoURL = try? container.decode(String.self, forKey: .logoURL)
    }
}

private struct BBSScore: Decodable {
    var home: BBSFlexibleInt
    var away: BBSFlexibleInt

    enum CodingKeys: String, CodingKey {
        case home, away
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        home = (try? container.decode(BBSFlexibleInt.self, forKey: .home)) ?? BBSFlexibleInt(value: nil)
        away = (try? container.decode(BBSFlexibleInt.self, forKey: .away)) ?? BBSFlexibleInt(value: nil)
    }
}

private struct BBSFlexibleInt: Decodable {
    var value: Int?

    init(value: Int?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
            return
        }
        if let int = try? container.decode(Int.self) {
            value = int
            return
        }
        if let double = try? container.decode(Double.self) {
            value = Int(double)
            return
        }
        if let string = try? container.decode(String.self) {
            value = Int(string)
            return
        }
        value = nil
    }
}

private struct BBSDate: Decodable {
    var value: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
            return
        }
        if let string = try? container.decode(String.self) {
            value = BigBallsDataProvider.parseDate(string)
            return
        }
        if let number = try? container.decode(Double.self) {
            let seconds = number > 10_000_000_000 ? number / 1000 : number
            value = Date(timeIntervalSince1970: seconds)
            return
        }
        value = nil
    }
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
