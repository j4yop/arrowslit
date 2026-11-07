import Foundation
import Observation

/// Live football for the nook. Demo data until a BigBallsData key is
/// connected; then one football live request per refresh.
@MainActor
@Observable
public final class SportsService {
    public private(set) var matches: [SportsMatch] = []
    public private(set) var details: [String: [SportsFootballEvent]] = [:]
    public private(set) var detailLoading: Set<String> = []
    public private(set) var detailErrors: [String: String] = [:]
    public private(set) var isLoading = false
    public private(set) var isDemo = true
    public private(set) var lastUpdated: Date?
    public private(set) var errorMessage: String?
    public private(set) var quota = SportsQuota()
    public private(set) var account: SportsAccount?
    public private(set) var coverageNote: String?

    @ObservationIgnored public var onGoal: ((SportsGoalEvent) -> Void)?
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private var apiKey: String?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var detailTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var isPaneVisible = false
    @ObservationIgnored private var lastFixturesLoad: Date?
    @ObservationIgnored private var lastScores: [String: MatchScoreSnapshot] = [:]

    private static let keychainAccount = "bigballsdata"

    public init(settings: SettingsStore, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
        // Reading the Keychain can wait for an ACL prompt. It must never hold
        // up launch: the island has no window yet for macOS to show it over.
        loadStoredKey()
    }

    private func loadStoredKey() {
        let account = Self.keychainAccount
        Task { [weak self] in
            let key = await Task.detached(priority: .utility) {
                SportsKeychain.read(account: account)
            }.value
            guard let self else { return }
            self.apiKey = key
            if key == nil {
                self.loadDemo()
            } else {
                self.startAppAlerts()
                if self.settings.isTabEnabled(.sports) { self.refresh() }
            }
        }
    }

    // MARK: - Public state

    public var hasAPIKey: Bool { apiKey != nil }

    public var keyHint: String? {
        guard let apiKey, !apiKey.isEmpty else { return nil }
        let suffix = apiKey.suffix(4)
        return "Saved key · ending \(suffix)"
    }

    public var isEnabled: Bool { settings.isTabEnabled(.sports) }

    public var followedCompetitionIDs: Set<String> {
        let configured = settings.sportsCompetitionIDs.filter { SportsCatalog.competition(id: $0) != nil }
        return Set(configured.isEmpty ? SportsCatalog.featuredIDs : configured)
    }

    public var compactMatch: SportsMatch? {
        guard settings.isTabEnabled(.sports),
              settings.sportsShowInNotch,
              !isDemo else { return nil }
        if let pinnedID = settings.sportsPinnedMatchID,
           let pinned = matches.first(where: { $0.id == pinnedID && $0.isLive }) {
            return pinned
        }
        return matches.first(where: { $0.isLive })
    }

    /// The match the notch represents: pinned first, then a followed team,
    /// then the first live match when the notch score is enabled.
    public var alertMatch: SportsMatch? {
        guard !isDemo else { return nil }
        if let pinnedID = settings.sportsPinnedMatchID,
           let pinned = matches.first(where: { $0.id == pinnedID && $0.isLive }) {
            return pinned
        }
        let followedTeams = Set(settings.sportsFollowedTeams)
        if let followed = matches.first(where: {
            $0.isLive && (followedTeams.contains($0.home.id) || followedTeams.contains($0.away.id))
        }) {
            return followed
        }
        return matches.first(where: \.isLive)
    }

    public var liveCount: Int {
        matches.filter(\.isLive).count
    }

    public var availableMatches: [SportsMatch] {
        matches
    }

    public func isFollowing(_ team: SportsTeam) -> Bool {
        settings.sportsFollowedTeams.contains(team.id)
    }

    public func isPinned(_ match: SportsMatch) -> Bool {
        settings.sportsPinnedMatchID == match.id
    }

    // MARK: - Lifecycle

    public func openPane() {
        isPaneVisible = true
        guard settings.isTabEnabled(.sports) else { return }
        if matches.isEmpty || lastUpdated == nil || Date().timeIntervalSince(lastUpdated ?? .distantPast) > 60 {
            refresh()
        }
        startPolling()
    }

    public func closePane() {
        isPaneVisible = false
        startPolling()
    }

    public func stop() {
        isPaneVisible = false
        stopPolling()
        refreshTask?.cancel()
        refreshTask = nil
        for task in detailTasks.values { task.cancel() }
        detailTasks.removeAll()
        isLoading = false
    }

    // MARK: - Keys

    public func saveAPIKey(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try SportsKeychain.save(trimmed, account: Self.keychainAccount)
            apiKey = trimmed
            settings.sportsPreview = false
            errorMessage = nil
            matches = []
            details = [:]
            lastUpdated = nil
            lastFixturesLoad = nil
            lastScores = [:]
            isDemo = false
            refresh(force: true)
            startPolling()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func removeAPIKey() {
        SportsKeychain.delete(account: Self.keychainAccount)
        apiKey = nil
        account = nil
        quota = SportsQuota()
        coverageNote = nil
        settings.sportsPreview = true
        matches = []
        details = [:]
        lastUpdated = nil
        lastFixturesLoad = nil
        lastScores = [:]
        errorMessage = nil
        stopPolling()
        loadDemo()
    }

    public func validateKey() {
        guard let apiKey else {
            errorMessage = "Add a BigBallsData key first."
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let provider = BigBallsDataProvider(apiKey: apiKey, session: session)
                let result = try await provider.validate()
                account = result.account
                quota = result.quota
                errorMessage = nil
            } catch let error as SportsProviderError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Start a light poll when the app launches with a pinned match. The
    /// service only asks for scores; it does not run when the app is quit.
    public func startAppAlerts() {
        guard settings.isTabEnabled(.sports),
              settings.sportsGoalAlerts,
              !settings.sportsPreview,
              apiKey != nil,
              settings.sportsPinnedMatchID != nil || !settings.sportsFollowedTeams.isEmpty else { return }
        if matches.isEmpty { refresh() }
        startPolling()
    }

    public func goalAlertsChanged() {
        startPolling()
    }

    // MARK: - Refresh

    public func refresh(force: Bool = false) {
        guard settings.isTabEnabled(.sports) else { return }
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await performRefresh(force: force)
            refreshTask = nil
        }
    }

    private func performRefresh(force: Bool) async {
        guard settings.isTabEnabled(.sports) else { return }

        if settings.sportsPreview || apiKey == nil {
            loadDemo()
            return
        }
        guard let apiKey else {
            loadDemo()
            return
        }

        isLoading = true
        defer { isLoading = false }

        let provider = BigBallsDataProvider(apiKey: apiKey, session: session)
        let followed = followedCompetitionIDs

        do {
            let live = try await provider.liveMatches()
            quota = live.quota

            var gathered = live.matches.filter { followed.contains($0.competition.id) }

            let needsFixtures = force
                || lastFixturesLoad == nil
                || Date().timeIntervalSince(lastFixturesLoad ?? .distantPast) > 30 * 60
            if needsFixtures {
                gathered += await loadUpcoming(provider: provider, followed: followed)
                lastFixturesLoad = Date()
            }

            matches = SportsRanking.rank(
                deduplicated(gathered),
                followedTeamIDs: Set(settings.sportsFollowedTeams),
                followedCompetitionIDs: followed,
                pinnedID: settings.sportsPinnedMatchID
            )
            let previousScores = lastScores
            lastScores = Dictionary(uniqueKeysWithValues: matches.map { match in
                (match.id, MatchScoreSnapshot(
                    home: match.homeScore,
                    away: match.awayScore
                ))
            })
            if !previousScores.isEmpty {
                detectGoal(previous: previousScores)
            }
            lastUpdated = Date()
            isDemo = false
            errorMessage = nil
            startPolling()
        } catch let error as SportsProviderError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadUpcoming(provider: BigBallsDataProvider, followed: Set<String>) async -> [SportsMatch] {
        let competitions = followed
            .compactMap(SportsCatalog.competition(id:))
            .sorted { $0.priority < $1.priority }
        var result: [SportsMatch] = []
        await withTaskGroup(of: SportsProviderPayload?.self) { group in
            for competition in competitions {
                group.addTask {
                    try? await provider.upcoming(for: competition)
                }
            }
            for await payload in group {
                guard let payload else { continue }
                quota = payload.quota
                result += payload.matches.filter { followed.contains($0.competition.id) }
            }
        }
        return result
    }

    private func detectGoal(previous: [String: MatchScoreSnapshot]) {
        guard settings.sportsGoalAlerts,
              let onGoal,
              let watched = alertMatch,
              watched.isLive,
              let old = previous[watched.id],
              let oldHome = old.home,
              let oldAway = old.away else { return }

        guard let goal = SportsGoalRules.goal(
            match: watched,
            previousHome: oldHome,
            previousAway: oldAway
        ) else { return }
        onGoal(goal)
    }

    private func deduplicated(_ matches: [SportsMatch]) -> [SportsMatch] {
        var seen = Set<String>()
        return matches.filter { seen.insert($0.id).inserted }
    }

    private func handle(_ error: SportsProviderError) {
        switch error {
        case .rateLimited(_, let quota):
            self.quota = quota
            errorMessage = error.errorDescription
        case .sportNotIncluded(let message):
            coverageNote = message
            errorMessage = error.errorDescription
        default:
            errorMessage = error.errorDescription
        }
    }

    private func loadDemo() {
        let followed = followedCompetitionIDs
        let demo = SportsDemoData.matches().filter { followed.contains($0.competition.id) }
        matches = SportsRanking.rank(
            demo,
            followedTeamIDs: Set(settings.sportsFollowedTeams),
            followedCompetitionIDs: followed,
            pinnedID: settings.sportsPinnedMatchID
        )
        details = SportsDemoData.details()
        isDemo = true
        lastUpdated = Date()
        errorMessage = nil
        lastScores = [:]
        stopPolling()
    }

    // MARK: - Polling

    private func startPolling() {
        stopPolling()
        let panelVisible = isPaneVisible
        let alertsActive = settings.sportsGoalAlerts && alertMatch != nil
        guard (panelVisible || alertsActive),
              settings.isTabEnabled(.sports),
              !settings.sportsPreview,
              apiKey != nil,
              !quota.isExhausted else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let seconds = self.isPaneVisible ? self.pollInterval : self.alertPollInterval
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private var pollInterval: TimeInterval {
        let preferred = TimeInterval(max(15, settings.sportsRefreshSeconds))
        if quota.isExhausted {
            if let resetAt = quota.resetAt {
                return max(60, resetAt.timeIntervalSinceNow + 5)
            }
            return 3600
        }
        if quota.isLow { return max(180, preferred) }
        return preferred
    }

    private var alertPollInterval: TimeInterval {
        max(60, TimeInterval(settings.sportsRefreshSeconds))
    }

    // MARK: - Detail

    public func loadDetail(for match: SportsMatch) {
        guard details[match.id] == nil, detailErrors[match.id] == nil, detailTasks[match.id] == nil else { return }
        guard !isDemo, let apiKey else { return }
        detailLoading.insert(match.id)
        detailErrors[match.id] = nil
        let provider = BigBallsDataProvider(apiKey: apiKey, session: session)
        detailTasks[match.id] = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await provider.events(for: match.id)
                quota = result.quota
                details[match.id] = result.events
            } catch let error as SportsProviderError {
                if case .sportNotIncluded(let message) = error {
                    coverageNote = message
                }
                detailErrors[match.id] = error.errorDescription
            } catch {
                detailErrors[match.id] = error.localizedDescription
            }
            detailLoading.remove(match.id)
            detailTasks[match.id] = nil
        }
    }

    // MARK: - Following and pins

    public func toggleFollow(_ team: SportsTeam) {
        var followed = settings.sportsFollowedTeams
        if let index = followed.firstIndex(of: team.id) {
            followed.remove(at: index)
        } else {
            followed.append(team.id)
        }
        settings.sportsFollowedTeams = followed
        matches = SportsRanking.rank(
            matches,
            followedTeamIDs: Set(followed),
            followedCompetitionIDs: followedCompetitionIDs,
            pinnedID: settings.sportsPinnedMatchID
        )
    }

    public func togglePin(_ match: SportsMatch) {
        if settings.sportsPinnedMatchID == match.id {
            settings.sportsPinnedMatchID = nil
        } else {
            settings.sportsPinnedMatchID = match.id
        }
        matches = SportsRanking.rank(
            matches,
            followedTeamIDs: Set(settings.sportsFollowedTeams),
            followedCompetitionIDs: followedCompetitionIDs,
            pinnedID: settings.sportsPinnedMatchID
        )
    }

    public func setCompetition(_ id: String, enabled: Bool) {
        var selected = Set(settings.sportsCompetitionIDs)
        if enabled { selected.insert(id) } else { selected.remove(id) }
        settings.sportsCompetitionIDs = Array(selected).sorted()
        lastFixturesLoad = nil
        refresh(force: true)
    }

    private struct MatchScoreSnapshot {
        var home: Int?
        var away: Int?
    }

    #if DEBUG
    /// Debug-only: show a sample match in the closed notch for screenshots.
    public func showDemoCompact(_ match: SportsMatch?) {
        guard let match else { return }
        if matches.isEmpty { matches = SportsDemoData.matches() }
        details = SportsDemoData.details()
        isDemo = false
        demoCompact = match
        lastUpdated = Date()
    }

    @ObservationIgnored private var demoCompact: SportsMatch?
    #endif

    private var effectiveCompact: SportsMatch? {
        #if DEBUG
        if let demoCompact { return demoCompact }
        #endif
        return compactMatch
    }

    /// The compact strip reads this so a screenshot/demo match can stand in for live data.
    public var notchMatch: SportsMatch? { effectiveCompact }
}
