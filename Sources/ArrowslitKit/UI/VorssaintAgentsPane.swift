import SwiftUI

struct VorssaintAgentsPane: View {
    @Bindable var state: AppState
    @StateObject private var usage = AgentUsageService.shared
    @StateObject private var resets = AgentCodexResetService.shared
    @AppStorage("arrowslit.agents.period") private var periodRaw = AgentPeriod.today.rawValue
    @State private var limitDisplay: LimitDisplay = .remaining
    @State private var confirmingReset = false

    private enum LimitDisplay: String, CaseIterable {
        case remaining, used
    }

    private var period: AgentPeriod {
        AgentPeriod(rawValue: periodRaw) ?? .today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneHeader("AI Agents") {
                HStack(spacing: 7) {
                    Picker("Period", selection: Binding(
                        get: { period },
                        set: { periodRaw = $0.rawValue }
                    )) {
                        Text("Today").tag(AgentPeriod.today)
                        Text("7 days").tag(AgentPeriod.week)
                        Text("30 days").tag(AgentPeriod.month)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.mini)
                    Picker("Limits", selection: $limitDisplay) {
                        Text("Left").tag(LimitDisplay.remaining)
                        Text("Used").tag(LimitDisplay.used)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.mini)
                }
            }

            if !usage.snapshot.loaded {
                VStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading local agent logs…")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if usage.snapshot.seen.isEmpty && usage.snapshot.live.isEmpty {
                VorssaintPageEmpty(
                    symbol: "sparkles",
                    title: "No agent usage yet",
                    detail: "Claude Code, Codex, OpenCode and GitHub Copilot usage appears as soon as they work on this Mac."
                )
            } else {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            limitsCards(now: context.date)
                            spendingCard
                            nowCard(now: context.date)
                            trendCard
                            shareCard(title: "Models", symbol: "cpu", shares: usage.snapshot.usage(period).models)
                            shareCard(title: "Projects", symbol: "folder", shares: usage.snapshot.usage(period).projects)
                            activityCard(now: context.date)
                            resetsCard
                        }
                    }
                }
            }
        }
        .padding(.top, 2)
        .onAppear {
            usage.syncWithPreferences()
            usage.pageDidAppear()
            resets.refreshIfStale()
        }
        .onDisappear { usage.pageDidDisappear() }
    }

    // MARK: Limits

    @ViewBuilder
    private func limitsCards(now: Date) -> some View {
        let providers = AgentProvider.allCases.filter {
            usage.snapshot.limits[$0] != nil || usage.snapshot.seen.contains($0)
        }
        if providers.isEmpty {
            agentCard(title: "Limits", symbol: "gauge.with.dots.needle.33percent",
                      tint: .white.opacity(0.5), height: 96) {
                Text("No plan limits yet")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.4))
            }
        } else {
            ForEach(providers) { provider in
                limitCard(provider, now: now)
            }
        }
    }

    private func limitCard(_ provider: AgentProvider, now: Date) -> some View {
        let limits = usage.snapshot.limits[provider]
        let windows = limits?.windows.map { AgentLimitSupport.current($0, at: now) } ?? []
        return agentCard(title: provider.displayName, symbol: provider.symbol,
                         tint: provider.vorssaintTint, height: 96) {
            VStack(alignment: .leading, spacing: 4) {
                if windows.isEmpty {
                    Text(provider == .copilot ? "Limits appear after the next reply" : "Waiting for a plan limit")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    ForEach(windows.prefix(2)) { window in
                        let fraction = limitDisplay == .remaining ? window.remainingFraction : window.usedFraction
                        HStack(spacing: 5) {
                            Text(window.kind == .session ? "Session" : "Week")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                            Spacer(minLength: 4)
                            Text(percent(fraction))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(tint(for: window.usedFraction, provider: provider))
                        }
                        VorssaintMeter(value: fraction, tint: tint(for: window.usedFraction, provider: provider))
                        if let reset = AgentLimitSupport.displayedReset(window, now: now) {
                            Text("resets \(reset.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))")
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                }
            }
        }
    }

    // MARK: Cards

    private var spendingCard: some View {
        let totals = usage.snapshot.usage(period).total
        return agentCard(title: "Spending", symbol: "dollarsign.circle",
                         tint: ArrowTheme.green, height: 96) {
            VStack(alignment: .leading, spacing: 3) {
                Text("$\(totals.cost.formatted(.number.precision(.fractionLength(2))))")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("\(tokens(totals.tokens.total)) tokens · \(totals.requests) requests")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
                Text("API value at list prices")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
    }

    private func nowCard(now: Date) -> some View {
        agentCard(title: "Now", symbol: "waveform.path.ecg",
                  tint: ArrowTheme.blue, height: 96) {
            VStack(alignment: .leading, spacing: 4) {
                if usage.snapshot.live.isEmpty {
                    Text("No session running")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    ForEach(usage.snapshot.live.prefix(2)) { session in
                        HStack(spacing: 5) {
                            Circle().fill(session.provider.vorssaintTint)
                                .frame(width: 5, height: 5)
                            Text(session.project.isEmpty ? session.provider.displayName : session.project)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(duration(now.timeIntervalSince(session.started)))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }
            }
        }
    }

    private var trendCard: some View {
        let days = Array(usage.snapshot.days.suffix(7))
        let maxValue = max(1, days.map { $0.total.tokens.total }.max() ?? 1)
        return agentCard(title: "Trend", symbol: "chart.bar.xaxis",
                         tint: ArrowTheme.amber, height: 118) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(days) { day in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ArrowTheme.amber.opacity(0.75))
                            .frame(height: max(2, 42 * CGFloat(day.total.tokens.total) / CGFloat(maxValue)))
                        Text(day.start.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 7.5))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("\(day.start.formatted(date: .abbreviated, time: .omitted)): \(tokens(day.total.tokens.total)) tokens")
                }
            }
            .frame(height: 54, alignment: .bottom)
        }
    }

    private func shareCard(title: String, symbol: String, shares: [AgentShare]) -> some View {
        let top = Array(shares.prefix(3))
        let total = max(1, top.reduce(0) { $0 + $1.totals.tokens.total })
        return agentCard(title: title, symbol: symbol, tint: .white.opacity(0.65), height: 96) {
            VStack(alignment: .leading, spacing: 4) {
                if top.isEmpty {
                    Text("Nothing in this period")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    ForEach(top) { share in
                        HStack(spacing: 5) {
                            Text(share.name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(percent(Double(share.totals.tokens.total) / Double(total)))
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
    }

    private func activityCard(now: Date) -> some View {
        let days = Array(usage.snapshot.days.suffix(91))
        let maxValue = max(1, days.map { $0.total.tokens.total }.max() ?? 1)
        return agentCard(title: "Activity", symbol: "square.grid.3x3.fill",
                         tint: .white.opacity(0.65), height: 118) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(7), spacing: 2), count: 7), spacing: 2) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(ArrowTheme.amber.opacity(0.12 + 0.75 * Double(day.total.tokens.total) / Double(maxValue)))
                        .frame(width: 7, height: 7)
                        .help("\(day.start.formatted(date: .abbreviated, time: .omitted)): \(tokens(day.total.tokens.total)) tokens")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var resetsCard: some View {
        agentCard(title: "Codex resets", symbol: "arrow.counterclockwise.circle",
                  tint: .white.opacity(0.65), height: 96) {
            VStack(alignment: .leading, spacing: 4) {
                if let summary = resets.summary {
                    Text("\(summary.available) available")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    if let next = summary.nextExpiry {
                        Text("Next expires \(next.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))")
                            .font(.system(size: 8.5))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    if confirmingReset {
                        HStack(spacing: 5) {
                            Button("Cancel") { confirmingReset = false }
                            Button("Reset") {
                                resets.redeem()
                                confirmingReset = false
                            }
                            .foregroundStyle(ArrowTheme.amber)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: .semibold))
                    } else if summary.available > 0 {
                        Button("Use a reset") { confirmingReset = true }
                            .buttonStyle(.plain)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(ArrowTheme.amber)
                    } else {
                        Text("None available")
                            .font(.system(size: 8.5))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                } else {
                    Text(resets.failure == nil ? "Check the account" : "Unavailable")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.4))
                    Button(resets.checking ? "Checking…" : "Check") { resets.refresh() }
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ArrowTheme.amber)
                        .disabled(resets.checking)
                }
            }
        }
    }

    // MARK: Chrome

    private func agentCard<Content: View>(
        title: String,
        symbol: String,
        tint: Color,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    private func tokens(_ value: Int) -> String {
        let number = Double(value)
        if number >= 1_000_000 { return String(format: "%.1fM", number / 1_000_000) }
        if number >= 1_000 { return String(format: "%.1fK", number / 1_000) }
        return "\(value)"
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        if total >= 3600 { return "\(total / 3600)h \((total % 3600) / 60)m" }
        return "\(total / 60)m \(total % 60)s"
    }

    private func tint(for used: Double, provider: AgentProvider) -> Color {
        if used >= 0.95 { return ArrowTheme.red }
        if used >= 0.8 { return ArrowTheme.amber }
        return provider.vorssaintTint
    }
}

private struct VorssaintMeter: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule().fill(tint).frame(width: max(2, geometry.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 4)
    }
}

extension AgentProvider {
    var vorssaintTint: Color {
        switch self {
        case .claude: Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex: Color(red: 0.49, green: 0.60, blue: 1.0)
        case .opencode: Color(red: 0.06, green: 0.73, blue: 0.51)
        case .copilot: Color(red: 0.30, green: 0.78, blue: 0.68)
        }
    }
}
