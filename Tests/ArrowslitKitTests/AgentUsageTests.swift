import Foundation
import Testing
@testable import ArrowslitKit

@Suite("Agent usage summary")
struct AgentUsageTests {
    @Test func addsTokensAndCostsForTheSelectedPeriod() {
        let now = Date()
        let record = AgentUsageRecord(
            provider: .claude,
            date: now,
            model: "claude-sonnet-4-5",
            project: "arrowslit",
            session: "session-1",
            requests: 2,
            tokens: AgentTokens(input: 1000, cacheWrite: 200, cacheRead: 300, output: 500, reasoning: 50),
            cost: 0.012,
            savings: 0.003
        )
        let snapshot = AgentUsageSummary.snapshot(
            records: [record],
            limits: [:],
            live: [],
            plans: [:],
            providers: [.claude],
            now: now
        )
        let usage = snapshot.usage(.today)
        #expect(usage.total.tokens.total == 2000)
        #expect(usage.total.tokens.prompt == 1500)
        #expect(usage.total.requests == 2)
        #expect(abs(usage.total.cost - 0.012) < 0.0001)
        #expect(usage.models.first?.name.contains("Sonnet") == true)
        #expect(usage.projects.first?.name == "arrowslit")
    }

    @Test func waitingOpenCodeSessionStaysInTheSnapshot() {
        let waiting = AgentLiveSession(
            id: "opencode-session",
            provider: .opencode,
            started: Date().addingTimeInterval(-600),
            lastActivity: Date(),
            model: "claude-sonnet-4",
            project: "arrowslit",
            tokens: AgentTokens(input: 10, output: 5),
            cost: 0
        )
        let snapshot = AgentUsageSummary.snapshot(
            records: [],
            limits: [:],
            live: [],
            waiting: [waiting],
            plans: [:],
            providers: [.opencode],
            now: Date()
        )
        #expect(snapshot.live.isEmpty)
        #expect(snapshot.waiting == [waiting])
        #expect(snapshot.seen.contains(.opencode))
    }

    @Test func musicOutranksLiveAgentsInTheCompactStrip() {
        #expect(NotchActivity.nowPlaying.priority < NotchActivity.agents.priority)
        #expect(NotchActivity.nowPlaying.priority < NotchActivity.sports.priority)
        #expect(PresentationResolver.ordered([.nowPlaying, .agents], preferred: nil) == [.nowPlaying, .agents])
        #expect(PresentationResolver.ordered([.sports, .agents], preferred: nil) == [.agents, .sports])
    }

    @Test func agentPagePairsCardsAndChartsTakeFullRows() {
        let providers: [AgentProvider] = [.codex, .opencode]
        let tiles = NotchAgentSupport.tiles(cards: NotchAgentSupport.cards(), providers: providers)
        #expect(tiles.filter { $0.card == .limits }.count == 2)
        #expect(tiles.contains { $0.card == .trend })
        #expect(tiles.contains { $0.card == .activity })
        #expect(tiles.contains { $0.card == .resets })

        let rows = NotchAgentSupport.rows(tiles, width: 532)
        #expect(rows.contains { row in row.count == 1 && row[0].card == .trend })
        #expect(rows.contains { row in row.count == 1 && row[0].card == .activity })
        #expect(NotchAgentSupport.height(of: rows.first { $0.contains { $0.card == .trend } }!) == 118)
        #expect(NotchAgentSupport.height(of: rows.first { $0.contains { $0.card == .spend } }!) == 96)
        #expect(NotchAgentSupport.contentHeight(rows) > 0)
    }

    @Test func providersHaveStableNamesAndTints() {
        #expect(AgentProvider.allCases.count == 4)
        #expect(AgentProvider.claude.displayName == "Claude")
        #expect(AgentProvider.codex.displayName == "Codex")
        #expect(AgentProvider.opencode.displayName == "OpenCode")
        #expect(AgentProvider.copilot.displayName == "GitHub Copilot")
    }
}
