import SwiftUI

/// Football in the 560×178 nook: a competition strip, a sideways shelf of
/// match cards, and an inline key-events view. One sport, one hierarchy.
struct SportsPane: View {
    @Bindable var state: AppState
    @State private var competitionID: String?
    @State private var selectedMatchID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var service: SportsService { state.sports }

    private var competitions: [SportsCompetition] {
        SportsCatalog.all.filter { service.followedCompetitionIDs.contains($0.id) }
    }

    private var visibleMatches: [SportsMatch] {
        let filtered = SportsRanking.filtered(service.matches, competitionID: competitionID)
        let current = filtered.filter { $0.isLive || $0.state == .scheduled }
        return current.isEmpty ? filtered : current
    }

    private var selectedMatch: SportsMatch? {
        guard let selectedMatchID else { return nil }
        return service.matches.first { $0.id == selectedMatchID }
    }

    var body: some View {
        VStack(spacing: 7) {
            header

            if let match = selectedMatch {
                SportsMatchDetailView(state: state, match: match) {
                    withAnimation(NookMotion.reducing(NookMotion.quick, reduceMotion: reduceMotion)) {
                        selectedMatchID = nil
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else if let message = service.errorMessage, service.matches.isEmpty {
                errorState(message)
            } else if service.isLoading && visibleMatches.isEmpty {
                loadingState
            } else if visibleMatches.isEmpty {
                emptyState
            } else {
                shelf
            }
        }
        .onAppear { service.openPane() }
        .onDisappear { service.closePane() }
        .animation(NookMotion.reducing(NookMotion.quick, reduceMotion: reduceMotion), value: service.matches)
        .animation(NookMotion.reducing(NookMotion.quick, reduceMotion: reduceMotion), value: selectedMatchID)
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "soccerball")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ArrowTheme.amber)
                Text("Football")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
            }
            .frame(width: 62, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    competitionChip(nil, title: "All")
                    ForEach(competitions) { competition in
                        competitionChip(competition.id, title: competition.shortName)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if service.isDemo {
                Text("PREVIEW")
                    .font(.system(size: 7.5, weight: .bold))
                    .kerning(0.45)
                    .foregroundStyle(ArrowTheme.amber)
                    .padding(.horizontal, 5)
                    .frame(height: 17)
                    .background(Capsule().fill(ArrowTheme.amber.opacity(0.12)))
                    .help("Sample matches. Connect BigBallsData in Settings for live scores.")
            } else if service.liveCount > 0 {
                HStack(spacing: 3) {
                    Circle()
                        .fill(ArrowTheme.green)
                        .frame(width: 4, height: 4)
                    Text("\(service.liveCount) live")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(ArrowTheme.green)
                }
                .help("\(service.liveCount) live matches")
            } else {
                Text("\(service.quota.limit)/day")
                    .font(.system(size: 8.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(service.quota.isExhausted ? ArrowTheme.red : ArrowTheme.faint)
                    .help(service.quota.summary)
            }

            Button {
                service.refresh(force: true)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ArrowTheme.muted)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .rotationEffect(.degrees(service.isLoading ? 180 : 0))
                    .animation(.easeInOut(duration: 0.45), value: service.isLoading)
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.92))
            .help("Refresh scores")
            .accessibilityLabel("Refresh scores")
        }
        .frame(height: 22)
    }

    private func competitionChip(_ id: String?, title: String) -> some View {
        Button {
            withAnimation(NookMotion.reducing(NookMotion.quick, reduceMotion: reduceMotion)) {
                competitionID = id
            }
        } label: {
            Text(title)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(competitionID == id ? ArrowTheme.bone : ArrowTheme.muted)
                .padding(.horizontal, 6)
                .frame(height: 19)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(competitionID == id ? Color.white.opacity(0.14) : Color.clear)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(competitionID == id ? Color.clear : ArrowTheme.hairline, lineWidth: 0.5)
                }
        }
        .buttonStyle(NookPressStyle(pressedScale: 0.95))
    }

    private var shelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 7) {
                ForEach(visibleMatches) { match in
                    SportsMatchCard(state: state, match: match) {
                        withAnimation(NookMotion.reducing(NookMotion.quick, reduceMotion: reduceMotion)) {
                            selectedMatchID = match.id
                        }
                    }
                    .frame(width: 166, height: 92)
                }
            }
            .padding(.horizontal, 1)
        }
        .frame(height: 92)
        .nookScrollEdgeFade()
    }

    private var loadingState: some View {
        HStack(spacing: 7) {
            ProgressView().controlSize(.small)
            Text("Loading matches…")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(ArrowTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: service.hasAPIKey ? "moon.stars" : "soccerball")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(ArrowTheme.faint)
            Text(service.hasAPIKey ? "No live matches in your competitions" : "Connect BigBallsData to go live")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArrowTheme.bone)
            Text(service.hasAPIKey ? "The next fixtures will appear here." : "Preview matches are showing above. Add a free key in Settings.")
                .font(.system(size: 9.5))
                .foregroundStyle(ArrowTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(ArrowTheme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sports is offline")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                Text(message)
                    .font(.system(size: 9.5))
                    .foregroundStyle(ArrowTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Button("Settings") {
                state.collapse()
                state.onOpenSettings?()
            }
            .buttonStyle(NookPressStyle())
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(ArrowTheme.ink)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(Capsule().fill(ArrowTheme.amber))
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }
}

// MARK: - Card

private struct SportsMatchCard: View {
    @Bindable var state: AppState
    let match: SportsMatch
    let open: () -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var service: SportsService { state.sports }
    private var accent: Color { match.isLive ? ArrowTheme.green : ArrowTheme.amber }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(match.competition.shortName.uppercased())
                        .font(.system(size: 7.5, weight: .bold))
                        .kerning(0.35)
                        .foregroundStyle(ArrowTheme.muted)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    if match.isLive {
                        HStack(spacing: 3) {
                            Circle().fill(accent).frame(width: 4, height: 4)
                            Text(SportsFormat.shortStatus(match))
                                .font(.system(size: 7.5, weight: .bold))
                                .foregroundStyle(accent)
                                .lineLimit(1)
                        }
                    } else if match.state == .finished {
                        Text("FT")
                            .font(.system(size: 7.5, weight: .semibold))
                            .foregroundStyle(ArrowTheme.faint)
                    }
                }

                teamRow(match.home, score: match.homeScore)
                teamRow(match.away, score: match.awayScore)

                HStack(spacing: 4) {
                    Text(SportsFormat.relativeStart(match))
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(match.isLive ? accent : ArrowTheme.faint)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if service.isPinned(match) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(ArrowTheme.amber)
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovering ? 0.09 : 0.065),
                                Color.white.opacity(0.025),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent.opacity(match.isLive ? 0.9 : 0.35))
                    .frame(width: 2.5)
                    .padding(.vertical, 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isHovering ? accent.opacity(0.35) : ArrowTheme.hairline, lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(NookPressStyle(pressedScale: 0.975))
        .onHover { hovered in
            withAnimation(NookMotion.reducing(NookMotion.hover, reduceMotion: reduceMotion)) {
                isHovering = hovered
            }
        }
        .help("\(match.home.name) vs \(match.away.name)")
        .accessibilityLabel(accessibilityLabel)
    }

    private func teamRow(_ team: SportsTeam, score: Int?) -> some View {
        HStack(spacing: 6) {
            SportsMonogram(team: team, size: 16)
            Text(team.shortName)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(ArrowTheme.bone)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 3)
            Text(score.map(String.init) ?? "–")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ArrowTheme.bone)
        }
    }

    private var accessibilityLabel: String {
        let status = match.isLive ? "live" : SportsFormat.shortStatus(match)
        return "\(match.home.name) \(match.homeScore ?? 0), \(match.away.name) \(match.awayScore ?? 0), \(status)"
    }
}

// MARK: - Detail

private struct SportsMatchDetailView: View {
    @Bindable var state: AppState
    let match: SportsMatch
    let close: () -> Void

    private var service: SportsService { state.sports }
    private var events: [SportsFootballEvent]? { service.details[match.id] }
    private var isLoading: Bool { service.detailLoading.contains(match.id) }
    private var error: String? { service.detailErrors[match.id] }

    var body: some View {
        HStack(spacing: 9) {
            scoreboard
                .frame(width: 188, alignment: .leading)

            Rectangle()
                .fill(ArrowTheme.hairline)
                .frame(width: 0.5)
                .padding(.vertical, 2)

            detailColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 92)
        .onAppear { service.loadDetail(for: match) }
    }

    private var scoreboard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Button(action: close) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ArrowTheme.bone)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(NookPressStyle(pressedScale: 0.92))
                .help("Back to matches")

                Text(match.competition.shortName.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .kerning(0.35)
                    .foregroundStyle(ArrowTheme.muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(SportsFormat.shortStatus(match))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(match.isLive ? ArrowTheme.green : ArrowTheme.faint)
            }

            detailTeamRow(match.home, score: match.homeScore)
            detailTeamRow(match.away, score: match.awayScore)

            HStack(spacing: 5) {
                Text(SportsFormat.status(match))
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(match.isLive ? ArrowTheme.green : ArrowTheme.faint)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    service.togglePin(match)
                } label: {
                    Image(systemName: service.isPinned(match) ? "pin.fill" : "pin")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(service.isPinned(match) ? ArrowTheme.amber : ArrowTheme.muted)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(NookPressStyle(pressedScale: 0.9))
                .nookHitSlop(3)
                .help(service.isPinned(match) ? "Unpin from the notch" : "Pin to the notch")
                .accessibilityLabel(service.isPinned(match) ? "Unpin match from notch" : "Pin match to notch")
            }
        }
    }

    private func detailTeamRow(_ team: SportsTeam, score: Int?) -> some View {
        HStack(spacing: 6) {
            SportsMonogram(team: team, size: 17)
            Text(team.shortName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ArrowTheme.bone)
                .lineLimit(1)
            Button {
                service.toggleFollow(team)
            } label: {
                Image(systemName: service.isFollowing(team) ? "star.fill" : "star")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(service.isFollowing(team) ? ArrowTheme.amber : ArrowTheme.faint)
                    .frame(width: 15, height: 15)
                    .contentShape(Rectangle())
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.88))
            .nookHitSlop(3)
            .help(service.isFollowing(team) ? "Unfollow \(team.name)" : "Follow \(team.name)")
            .accessibilityLabel(service.isFollowing(team) ? "Unfollow \(team.name)" : "Follow \(team.name)")
            Spacer(minLength: 3)
            Text(score.map(String.init) ?? "–")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ArrowTheme.bone)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if isLoading && events == nil {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Loading match detail…")
                    .font(.system(size: 9.5))
                    .foregroundStyle(ArrowTheme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let error, events == nil {
            Text(error)
                .font(.system(size: 9.5))
                .foregroundStyle(ArrowTheme.muted)
                .lineLimit(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let events {
            footballDetail(events)
        } else {
            Text("No key events yet.")
                .font(.system(size: 9.5))
                .foregroundStyle(ArrowTheme.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func footballDetail(_ events: [SportsFootballEvent]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("KEY EVENTS")
                .font(.system(size: 7.5, weight: .bold))
                .kerning(0.45)
                .foregroundStyle(ArrowTheme.faint)
            if events.isEmpty {
                Text("No key events yet.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(ArrowTheme.muted)
            } else {
                ForEach(Array(events.suffix(4).reversed())) { event in
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: symbol(for: event.kind))
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(color(for: event.kind))
                            .frame(width: 12)
                        Text(event.clock ?? "")
                            .font(.system(size: 8.5, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(ArrowTheme.muted)
                            .frame(width: 24, alignment: .leading)
                        Text(event.player ?? event.detail ?? "Event")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(ArrowTheme.bone)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func symbol(for kind: SportsFootballEvent.Kind) -> String {
        switch kind {
        case .goal: "soccerball"
        case .yellowCard, .redCard: "rectangle.portrait.fill"
        case .substitution: "arrow.left.arrow.right"
        case .other: "circle.fill"
        }
    }

    private func color(for kind: SportsFootballEvent.Kind) -> Color {
        switch kind {
        case .goal: ArrowTheme.green
        case .yellowCard: Color.yellow
        case .redCard: ArrowTheme.red
        case .substitution: ArrowTheme.muted
        case .other: ArrowTheme.faint
        }
    }
}

// MARK: - Shared bits

struct SportsMonogram: View {
    let team: SportsTeam
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(sportsHex: team.colorHex) ?? Self.fallbackColor(for: team.name))
                .opacity(0.28)
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            Text(team.shortName.prefix(2).uppercased())
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(ArrowTheme.bone)
                .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    static func fallbackColor(for name: String) -> Color {
        let palette: [Color] = [
            ArrowTheme.blue,
            Color(red: 0.95, green: 0.36, blue: 0.30),
            Color(red: 0.28, green: 0.78, blue: 0.52),
            Color(red: 1.0, green: 0.62, blue: 0.20),
            Color(red: 0.66, green: 0.45, blue: 0.98),
            Color(red: 0.20, green: 0.78, blue: 0.82),
            Color(red: 0.92, green: 0.40, blue: 0.62),
        ]
        let index = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fff_ffff } % palette.count
        return palette[index]
    }
}

extension Color {
    init?(sportsHex: String?) {
        guard let sportsHex else { return nil }
        var value = sportsHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8,
              let number = UInt64(value, radix: 16) else { return nil }
        let red, green, blue, alpha: Double
        if value.count == 8 {
            red = Double((number >> 24) & 0xff) / 255
            green = Double((number >> 16) & 0xff) / 255
            blue = Double((number >> 8) & 0xff) / 255
            alpha = Double(number & 0xff) / 255
        } else {
            red = Double((number >> 16) & 0xff) / 255
            green = Double((number >> 8) & 0xff) / 255
            blue = Double(number & 0xff) / 255
            alpha = 1
        }
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}
