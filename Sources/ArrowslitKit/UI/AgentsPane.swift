import AppKit
import SwiftUI

/// The AI Agents page, rebuilt on its own card, bar-chart and heatmap
/// components. The reader supplies Claude, Codex, OpenCode and Copilot data
/// from local logs; the layout pairs cards and lets the charts take a full row.
struct AgentsPane: View {
    @Bindable var state: AppState
    @StateObject private var usage = AgentUsageService.shared
    @StateObject private var resets = AgentCodexResetService.shared
    @AppStorage("arrowslit.agents.period") private var periodRaw = AgentPeriod.today.rawValue
    @AppStorage("arrowslit.agents.limitDisplay") private var limitDisplayRaw = NotchAgentLimitDisplay.remaining.rawValue
    @Environment(\.panelScale) private var scale

    private var period: AgentPeriod { AgentPeriod(rawValue: periodRaw) ?? .today }
    private var limitDisplay: NotchAgentLimitDisplay {
        NotchAgentLimitDisplay(rawValue: limitDisplayRaw) ?? .remaining
    }

    private var providers: [AgentProvider] {
        AgentProvider.allCases.filter { provider in
            usage.snapshot.seen.contains(provider)
                || usage.snapshot.limits[provider] != nil
                || usage.snapshot.live.contains { $0.provider == provider }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if !usage.snapshot.loaded && providers.isEmpty {
                    VStack(spacing: 9) {
                        ProgressView().controlSize(.small)
                        Text("Reading local agent logs…")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if providers.isEmpty {
                    AgentsEmptyState(
                        symbol: "sparkles",
                        title: "No agent usage yet",
                        detail: "Claude Code, Codex, OpenCode and GitHub Copilot appear here after they work on this Mac."
                    )
                } else {
                    desk(size: geometry.size)
                }
            }
        }
        .onAppear {
            usage.syncWithPreferences()
            usage.pageDidAppear()
            resets.refreshIfStale()
        }
        .onDisappear { usage.pageDidDisappear() }
    }

    private func desk(size: CGSize) -> some View {
        let tiles = NotchAgentSupport.tiles(
            cards: NotchAgentSupport.cards(),
            providers: providers
        )
        let rows = NotchAgentSupport.rows(tiles, width: size.width)
        return TimelineView(.periodic(from: .now, by: 15)) { context in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: NotchAgentSupport.spacing) {
                    ForEach(rows, id: \.first?.id) { row in
                        HStack(spacing: NotchAgentSupport.spacing) {
                            ForEach(row) { tile in
                                card(tile, now: context.date)
                            }
                        }
                        .frame(height: NotchAgentSupport.height(of: row))
                    }
                }
                .padding(.bottom, 2)
            }
            .scrollIndicators(.automatic)
            .nookScrollBounce()
        }
    }

    @ViewBuilder
    private func card(_ tile: NotchAgentTile, now: Date) -> some View {
        switch tile.card {
        case .limits:
            if let provider = tile.provider {
                AgentLimitsCard(
                    provider: provider,
                    snapshot: usage.snapshot,
                    now: now,
                    display: limitDisplay
                )
            }
        case .spend:
            AgentSpendCard(snapshot: usage.snapshot, providers: providers, period: period)
        case .live:
            AgentLiveCard(snapshot: usage.snapshot, providers: providers)
        case .trend:
            AgentTrendCard(snapshot: usage.snapshot, providers: providers, period: period)
        case .models:
            AgentShareCard(
                title: "Models",
                symbol: NotchAgentCard.models.symbol,
                shares: usage.snapshot.usage(period).models,
                byCost: usage.snapshot.usage(period).fullyPriced
            )
        case .projects:
            AgentShareCard(
                title: "Projects",
                symbol: NotchAgentCard.projects.symbol,
                shares: usage.snapshot.usage(period).projects,
                byCost: usage.snapshot.usage(period).fullyPriced
            )
        case .activity:
            AgentActivityCard(snapshot: usage.snapshot)
        case .resets:
            AgentResetsCard(now: now)
        }
    }
}

// MARK: - Limits

private struct AgentLimitsCard: View {
    let provider: AgentProvider
    let snapshot: AgentUsageSnapshot
    let now: Date
    let display: NotchAgentLimitDisplay
    @Environment(\.locale) private var locale

    private var windows: [AgentLimitWindow] {
        let all = (snapshot.limits[provider]?.windows ?? []).map { AgentLimitSupport.current($0, at: now) }
        let session = all.first { $0.kind == .session }
        let longer = all.filter { $0.kind != .session }.max { $0.usedPercent < $1.usedPercent }
        return [session, longer].compactMap { $0 }
    }

    private var working: Bool {
        !snapshot.working(provider).isEmpty
    }

    var body: some View {
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: 6) {
                NotchAgentCardHeader(title: provider.displayName, symbol: provider.symbol,
                                     tint: provider.tint, provider: provider) {
                    HStack(spacing: 4) {
                        if let plan = snapshot.plans[provider] {
                            AgentChip(text: plan.name, tint: provider.tint)
                        }
                        if working { NotchAgentPulse(tint: provider.tint, size: 5) }
                    }
                }

                if !windows.isEmpty {
                    VStack(spacing: 5) {
                        ForEach(windows) { window in
                            row(window)
                        }
                    }
                } else if provider == .opencode, let today = snapshot.usage(.today).byProvider[.opencode] {
                    openCodeReading(today)
                } else if provider == .claude, let block = snapshot.claudeBlock {
                    estimate(block)
                } else {
                    Text("Waiting for a plan limit")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ window: AgentLimitWindow) -> some View {
        let pace = AgentLimitSupport.pace(for: window, now: now)
        let tint = agentLimitTint(provider, usedFraction: window.usedFraction)
        let remaining = display == .remaining
        let fraction = remaining ? window.remainingFraction : window.usedFraction
        let reset = AgentLimitSupport.displayedReset(window, now: now).map {
            (window.estimatedResetsAt == nil ? "" : "≈ ") + countdown(to: $0)
        }
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(label(window))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                if let reset {
                    Label(reset, systemImage: "arrow.clockwise")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
                Text(NotchAgentSupport.limitShare(window, display: display))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint == provider.tint ? .white : tint)
                    .contentTransition(.numericText())
                    .fixedSize()
            }
            NotchAgentMeter(value: fraction,
                            pace: pace.map { remaining ? 1 - $0.elapsed : $0.elapsed },
                            tint: tint, height: 4)
        }
        .help(help(window))
    }

    private func openCodeReading(_ totals: AgentTotals) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text("Today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 2)
                Text(totals.unpriced > 0 ? "—" : AgentFormat.cost(totals.cost))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            HStack(spacing: 4) {
                Text(AgentFormat.tokens(totals.tokens.total))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.42))
                if let rate = totals.tokens.cacheHitRate, rate > 0 {
                    Text("· " + AgentFormat.percent(rate) + " from cache")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
    }

    private func estimate(_ block: AgentBlock) -> some View {
        let length = block.end.timeIntervalSince(block.start)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text("Session")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Label(countdown(to: block.end), systemImage: "arrow.clockwise")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.42))
                Spacer(minLength: 2)
                Text(AgentFormat.cost(block.totals.cost))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            NotchAgentMeter(value: length > 0 ? now.timeIntervalSince(block.start) / length : 0,
                            tint: provider.tint, height: 4, dimmed: true)
        }
        .help("Estimated from local activity")
    }

    private func label(_ window: AgentLimitWindow) -> String {
        switch window.kind {
        case .session: return "Session"
        case .weekly: return window.scope.map { "Weekly · \($0)" } ?? "Weekly"
        case .other:
            guard let minutes = window.minutes else { return window.scope ?? "Limit" }
            return AgentFormat.duration(TimeInterval(minutes) * 60, locale: locale, units: 1)
        }
    }

    private func countdown(to date: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        return AgentFormat.duration(max(60, seconds), locale: locale, units: seconds >= 3600 ? 2 : 1)
    }

    private func help(_ window: AgentLimitWindow) -> String {
        var parts = [label(window), AgentFormat.percent(window.usedFraction) + " used",
                     AgentFormat.percent(window.remainingFraction) + " left"]
        if let resets = AgentLimitSupport.displayedReset(window, now: now) {
            parts.append(resets.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened)))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Spending

private struct AgentSpendCard: View {
    let snapshot: AgentUsageSnapshot
    let providers: [AgentProvider]
    let period: AgentPeriod

    var body: some View {
        let usage = snapshot.usage(period)
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: 5) {
                NotchAgentCardHeader(title: "Spending", symbol: NotchAgentCard.spend.symbol)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text((usage.fullyPriced ? "" : "≥ ") + AgentFormat.cost(usage.total.cost))
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("API value")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.42))
                    Spacer(minLength: 0)
                }
                split(usage)
                Text(footer(usage))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .help("Saved " + AgentFormat.cost(usage.total.savings))
            }
        }
    }

    @ViewBuilder
    private func split(_ usage: AgentPeriodUsage) -> some View {
        let byCost = usage.fullyPriced
        let parts = providers.map { usage.byProvider[$0]?.weight(byCost: byCost) ?? 0 }
        let total = parts.reduce(0, +)
        let shown = parts.filter { $0 > 0 }.count
        GeometryReader { proxy in
            let gap: CGFloat = 2
            let room = max(0, proxy.size.width - gap * CGFloat(max(0, shown - 1)) - 4 * CGFloat(shown))
            HStack(spacing: gap) {
                if total <= 0 {
                    Capsule().fill(.white.opacity(0.13))
                } else {
                    ForEach(providers.indices, id: \.self) { index in
                        if parts[index] > 0 {
                            Capsule(style: .continuous)
                                .fill(providers[index].tint.opacity(0.9))
                                .frame(width: 4 + room * parts[index] / total)
                        }
                    }
                }
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private func footer(_ usage: AgentPeriodUsage) -> String {
        var parts = [AgentFormat.tokens(usage.total.tokens.total) + " tokens"]
        if let rate = usage.total.tokens.cacheHitRate, rate > 0 {
            parts.append(AgentFormat.percent(rate) + " from cache")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Now

private struct AgentLiveCard: View {
    let snapshot: AgentUsageSnapshot
    let providers: [AgentProvider]
    @Environment(\.locale) private var locale

    var body: some View {
        let live = snapshot.live.filter { providers.contains($0.provider) }
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: 7) {
                NotchAgentCardHeader(title: "Now", symbol: NotchAgentCard.live.symbol,
                                     tint: live.first?.provider.tint ?? .secondary) {
                    HStack(spacing: 4) {
                        if live.count > 2 { AgentChip(text: "+\(live.count - 2)") }
                        if let first = live.first { NotchAgentPulse(tint: first.provider.tint, size: 5) }
                    }
                }
                if live.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(providers) { idleRow($0) }
                    }
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(live.prefix(2)) { row($0, now: context.date) }
                        }
                    }
                }
            }
        }
    }

    private func row(_ session: AgentLiveSession, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                NotchAgentGlyph(provider: session.provider, size: 9)
                Text(session.project.isEmpty ? session.provider.displayName : session.project)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                Text(AgentFormat.clock(now.timeIntervalSince(session.started)))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(session.provider.tint)
            }
            Text([AgentPricing.displayName(session.model),
                  session.tokens.output > 0 ? AgentFormat.tokens(session.tokens.output) + " written" : "",
                  session.cost > 0 ? AgentFormat.cost(session.cost) : ""]
                .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
        }
    }

    private func idleRow(_ provider: AgentProvider) -> some View {
        HStack(spacing: 5) {
            NotchAgentGlyph(provider: provider, size: 9, working: false)
            Text(provider.displayName).font(.system(size: 10.5, weight: .medium))
            Spacer(minLength: 4)
            Text(snapshot.lastActivity[provider].map {
                $0.formatted(.relative(presentation: .named, unitsStyle: .abbreviated).locale(locale))
            } ?? "Idle")
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
        }
    }
}

// MARK: - Trend

private struct AgentTrendCard: View {
    let snapshot: AgentUsageSnapshot
    let providers: [AgentProvider]
    let period: AgentPeriod
    @State private var hovered: Date?
    @Environment(\.locale) private var locale

    private var buckets: [AgentBucket] {
        period == .today ? snapshot.hours : Array(snapshot.days.suffix(period.days))
    }

    var body: some View {
        let byCost = snapshot.usage(period).fullyPriced
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: 6) {
                NotchAgentCardHeader(title: "Trend", symbol: NotchAgentCard.trend.symbol) {
                    Text(caption(byCost: byCost))
                        .font(.system(size: 9.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
                NotchAgentBars(buckets: buckets, providers: providers, byCost: byCost, hovered: $hovered)
                axis
            }
        }
    }

    private func caption(byCost: Bool) -> String {
        if let hovered, let bucket = buckets.first(where: { $0.start == hovered }) {
            let tokens = byCost ? " · " + value(bucket.total, byCost: false) : ""
            return label(bucket.start, long: true) + " · " + value(bucket.total, byCost: byCost) + tokens
        }
        return labelPeriod + " · " + value(snapshot.usage(period).total, byCost: byCost)
    }

    private var labelPeriod: String {
        switch period {
        case .today: "Today"
        case .week: "7 days"
        case .month: "30 days"
        }
    }

    private func value(_ totals: AgentTotals, byCost: Bool) -> String {
        byCost ? AgentFormat.cost(totals.cost) : AgentFormat.tokens(totals.tokens.total) + " tokens"
    }

    private func label(_ date: Date, long: Bool) -> String {
        if period == .today { return date.formatted(.dateTime.hour().locale(locale)) }
        if period == .week, !long { return date.formatted(.dateTime.weekday(.narrow).locale(locale)) }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    private var axis: some View {
        let marks: [Int] = period == .week ? Array(buckets.indices)
            : buckets.isEmpty ? [] : [0, buckets.count / 2, buckets.count - 1]
        return HStack(spacing: 0) {
            if period == .week {
                ForEach(marks, id: \.self) { index in
                    Text(label(buckets[index].start, long: false)).frame(maxWidth: .infinity)
                }
            } else {
                ForEach(Array(marks.enumerated()), id: \.offset) { position, index in
                    if position > 0 { Spacer(minLength: 4) }
                    Text(label(buckets[index].start, long: false))
                }
            }
        }
        .font(.system(size: 8.5, weight: .medium))
        .foregroundStyle(.white.opacity(0.3))
        .lineLimit(1)
        .frame(height: 10)
    }
}

// MARK: - Models and projects

private struct AgentShareCard: View {
    let title: String
    let symbol: String
    let shares: [AgentShare]
    let byCost: Bool

    var body: some View {
        let shown = Array(shares.prefix(3))
        let peak = max(shown.map { $0.totals.weight(byCost: byCost) }.max() ?? 0, .leastNonzeroMagnitude)
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: 6) {
                NotchAgentCardHeader(title: title, symbol: symbol)
                if shown.isEmpty {
                    Text("Nothing in this period")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.42))
                } else {
                    VStack(spacing: 5) {
                        ForEach(shown) { share in row(share, peak: peak) }
                    }
                }
            }
        }
    }

    private func row(_ share: AgentShare, peak: Double) -> some View {
        let weight = share.totals.weight(byCost: byCost)
        let tint = share.provider?.tint ?? .white
        return HStack(spacing: 6) {
            Text(share.name)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Capsule(style: .continuous)
                .fill(tint.opacity(0.85))
                .frame(width: max(3, 44 * weight / peak), height: 4)
                .frame(width: 44, alignment: .leading)
            Text(byCost ? AgentFormat.cost(share.totals.cost) : AgentFormat.tokens(share.totals.tokens.total))
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.42))
                .frame(minWidth: 40, alignment: .trailing)
        }
        .frame(height: 14)
    }
}

// MARK: - Activity

private struct AgentActivityCard: View {
    let snapshot: AgentUsageSnapshot
    @State private var hovered: Date?
    @Environment(\.locale) private var locale

    private var streak: Int {
        var count = 0
        for day in snapshot.days.reversed() {
            if day.total.requests > 0 { count += 1 }
            else if count > 0 || day.id != snapshot.days.last?.id { break }
        }
        return count
    }

    var body: some View {
        let byCost = snapshot.days.allSatisfy { $0.total.unpriced == 0 }
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: 6) {
                NotchAgentCardHeader(title: "Activity", symbol: NotchAgentCard.activity.symbol) {
                    if streak > 1 {
                        Label("\(streak)", systemImage: "flame.fill")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.orange)
                            .help("\(streak) active days in a row")
                    }
                }
                GeometryReader { proxy in
                    let map = NotchAgentHeatmap.width(height: proxy.size.height, days: snapshot.days)
                    HStack(alignment: .top, spacing: 14) {
                        NotchAgentHeatmap(days: snapshot.days, byCost: byCost, hovered: $hovered)
                            .frame(width: map, height: proxy.size.height)
                        figures(byCost: byCost)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
    }

    private func figures(byCost: Bool) -> some View {
        let active = snapshot.days.filter { $0.total.requests > 0 }
        let busiest = active.max { $0.total.weight(byCost: byCost) < $1.total.weight(byCost: byCost) }
        let pointed = hovered.flatMap { date in snapshot.days.first { $0.start == date } }
        return VStack(alignment: .leading, spacing: 2) {
            Text(value(snapshot.days.reduce(into: AgentTotals()) { $0 += $1.total }, byCost: byCost))
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(AgentFormat.span(days: snapshot.days.count, locale: locale))
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
            Spacer(minLength: 4)
            figure("Active days", "\(active.count)")
            if let day = pointed ?? busiest {
                figure(pointed == nil ? "Busiest day" : day.start.formatted(.dateTime.weekday(.wide).locale(locale)),
                       day.start.formatted(.dateTime.day().month(.abbreviated).locale(locale)) + " · " + value(day.total, byCost: byCost))
            }
        }
    }

    private func figure(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.white.opacity(0.42)).lineLimit(1)
            Spacer(minLength: 4)
            Text(value).monospacedDigit().lineLimit(1)
        }
        .font(.system(size: 10, weight: .medium))
        .minimumScaleFactor(0.85)
    }

    private func value(_ totals: AgentTotals, byCost: Bool) -> String {
        byCost ? AgentFormat.cost(totals.cost) : AgentFormat.tokens(totals.tokens.total)
    }
}

// MARK: - Resets

private struct AgentResetsCard: View {
    let now: Date
    @ObservedObject private var resets = AgentCodexResetService.shared
    @State private var confirming = false
    @Environment(\.locale) private var locale

    private let tint = AgentProvider.codex.tint

    private var finished: AgentCodexResetService.Finished? {
        resets.finished.flatMap { now.timeIntervalSince($0.date) < 60 ? $0 : nil }
    }

    var body: some View {
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: 6) {
                NotchAgentCardHeader(title: "Resets", symbol: NotchAgentCard.resets.symbol, tint: tint, provider: .codex) {
                    if let summary = resets.summary, summary.available > 0 {
                        AgentChip(text: summary.available.formatted(.number.locale(locale)), tint: tint)
                    } else if resets.checking {
                        ProgressView().controlSize(.mini)
                    }
                }
                content
            }
        }
        .help("Codex banked resets")
        .onAppear { resets.refreshIfStale() }
        .onChange(of: resets.summary?.available) { _, _ in confirming = false }
    }

    @ViewBuilder private var content: some View {
        if resets.redeeming {
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                line("Resetting…")
            }
        } else if confirming, let summary = resets.summary, summary.available > 0 {
            HStack(spacing: 8) {
                Button("Cancel") { confirming = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Button("Use a reset") {
                    AgentHaptics.tap()
                    resets.redeem()
                    confirming = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(tint)
            }
            .frame(height: 20)
        } else if let summary = resets.summary {
            if summary.available > 0 {
                Text("Next expires " + (summary.nextExpiry.map {
                    $0.formatted(.relative(presentation: .named, unitsStyle: .abbreviated).locale(locale))
                } ?? "later"))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
                Button("Use a reset") {
                    AgentHaptics.tap()
                    confirming = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(tint)
                .frame(height: 20)
            } else {
                line("None available now")
            }
        } else if resets.checking {
            line("Checking the account…")
        } else {
            line("Check the account")
            Button("Check") {
                AgentHaptics.tap()
                resets.refresh()
            }
            .buttonStyle(.plain)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(tint)
            .disabled(resets.checking)
        }
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.45))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Small shared pieces

private struct AgentChip: View {
    let text: String
    var tint: Color = .white

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(tint.opacity(0.9))
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(tint.opacity(0.14), in: Capsule(style: .continuous))
    }
}

@MainActor
private enum AgentHaptics {
    static func tap() {
        let enabled = UserDefaults.standard.object(forKey: "arrowslit.hapticFeedback") as? Bool ?? true
        NookHaptics.perform(enabled: enabled)
    }
}


private struct AgentsEmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white.opacity(0.38))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
