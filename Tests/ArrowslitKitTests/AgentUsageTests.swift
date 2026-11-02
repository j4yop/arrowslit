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

    @Test func providersHaveStableNamesAndTints() {
        #expect(AgentProvider.allCases.count == 4)
        #expect(AgentProvider.claude.displayName == "Claude")
        #expect(AgentProvider.codex.displayName == "Codex")
        #expect(AgentProvider.opencode.displayName == "OpenCode")
        #expect(AgentProvider.copilot.displayName == "GitHub Copilot")
    }
}
