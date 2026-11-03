import Foundation
import SwiftUI

/// Number formatting for the agent page, taken from AI Agents.
enum AgentFormat {
    static func cost(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String {
        guard value.isFinite else { return "$0" }
        let magnitude = abs(value)
        if magnitude >= 10_000 { return "$" + scaled(magnitude / 1000, locale: locale) + "K" }
        let digits = magnitude >= 100 ? 0 : 2
        return "$" + value.formatted(.number.precision(.fractionLength(digits)).grouping(.automatic).locale(locale))
    }

    static func tokens(_ value: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let magnitude = Double(max(0, value))
        switch magnitude {
        case ..<1000: return Int(magnitude).formatted(.number.locale(locale))
        case ..<1_000_000: return scaled(magnitude / 1000, locale: locale) + "K"
        case ..<1_000_000_000: return scaled(magnitude / 1_000_000, locale: locale) + "M"
        default: return scaled(magnitude / 1_000_000_000, locale: locale) + "B"
        }
    }

    private static func scaled(_ value: Double, locale: Locale) -> String {
        let digits = value < 10 ? 1 : 0
        let divisor = digits == 1 ? 10.0 : 1.0
        let rounded = (value * divisor).rounded(.down) / divisor
        return rounded.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))
    }

    static func percent(_ fraction: Double, locale: Locale = .autoupdatingCurrent) -> String {
        let value = fraction.isFinite ? min(1, max(0, fraction)) : 0
        return value.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    static func duration(_ seconds: TimeInterval, locale: Locale, units: Int = 2,
                         style: DateComponentsFormatter.UnitsStyle = .abbreviated) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = style
        formatter.maximumUnitCount = units
        formatter.allowedUnits = seconds >= 86_400 ? [.day, .hour] : seconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        return formatter.string(from: max(0, seconds.isFinite ? seconds : 0)) ?? ""
    }

    static func span(days: Int, locale: Locale) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        let weeks = days % 7 == 0
        formatter.allowedUnits = weeks ? [.weekOfMonth] : [.day]
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        let count = max(0, days)
        return formatter.string(from: weeks ? DateComponents(weekOfMonth: count / 7) : DateComponents(day: count)) ?? ""
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.isFinite ? seconds : 0))
        if total >= 3600 { return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60) }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func day(_ date: Date, locale: Locale) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        style.timeZone = .gmt
        return date.formatted(style)
    }
}

/// Which share of a limit the cards read.
enum NotchAgentLimitDisplay: String, CaseIterable, Identifiable {
    case remaining, used
    var id: String { rawValue }
    var title: String { self == .remaining ? "Left" : "Used" }
}

enum NotchAgentCard: String, CaseIterable, Identifiable {
    case limits, spend, live, trend, models, projects, activity, resets

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .limits: return "gauge.with.dots.needle.33percent"
        case .spend: return "dollarsign.circle"
        case .live: return "waveform.path.ecg"
        case .trend: return "chart.bar.xaxis"
        case .models: return "cpu"
        case .projects: return "folder"
        case .activity: return "square.grid.3x3.fill"
        case .resets: return "arrow.counterclockwise.circle"
        }
    }

    /// Charts need the island's width; everything else pairs up.
    var fullWidth: Bool { self == .trend || self == .activity }

    /// Cards that cover the period chosen in the island's top row.
    var followsPeriod: Bool { self == .spend || self == .trend || self == .models || self == .projects }
}

struct NotchAgentTile: Identifiable, Equatable {
    let card: NotchAgentCard
    let provider: AgentProvider?
    var accountID: String? = nil
    var namesDefaultAccount = false

    var id: String {
        card.rawValue + (provider.map { "." + $0.rawValue } ?? "") + (accountID.map { "." + $0 } ?? "")
    }
}

extension NotchAgentSupport {
    static let spacing: CGFloat = 10
    static let cardHeight: CGFloat = 96
    static let chartHeight: CGFloat = 118
    static let accountCardHeight: CGFloat = 116
    static let pairWidth: CGFloat = 390

    static func cards() -> [NotchAgentCard] { NotchAgentCard.allCases }

    static func tiles(cards: [NotchAgentCard], providers: [AgentProvider],
                      codexAccounts: [String] = [], claudeAccount: String? = nil) -> [NotchAgentTile] {
        cards.flatMap { card -> [NotchAgentTile] in
            switch card {
            case .limits:
                return providers.filter(\.reportsLimits).flatMap { provider in
                    if provider == .claude, let claudeAccount {
                        return [NotchAgentTile(card: .limits, provider: provider, accountID: claudeAccount)]
                    }
                    guard provider == .codex, !codexAccounts.isEmpty else {
                        return [NotchAgentTile(card: .limits, provider: provider)]
                    }
                    return codexAccounts.map { NotchAgentTile(card: .limits, provider: provider, accountID: $0) }
                }
            case .resets:
                return providers.contains(.codex)
                    ? [NotchAgentTile(card: .resets, provider: .codex, namesDefaultAccount: !codexAccounts.isEmpty)]
                    : []
            default:
                return [NotchAgentTile(card: card, provider: nil)]
            }
        }
    }

    static func rows(_ tiles: [NotchAgentTile], width: CGFloat) -> [[NotchAgentTile]] {
        let pairs = width >= pairWidth
        var rows: [[NotchAgentTile]] = []
        var waiting: NotchAgentTile?
        for tile in tiles {
            if tile.card.fullWidth || !pairs {
                if let waiting { rows.append([waiting]) }
                waiting = nil
                rows.append([tile])
            } else if let partner = waiting {
                rows.append([partner, tile])
                waiting = nil
            } else {
                waiting = tile
            }
        }
        if let waiting { rows.append([waiting]) }
        return rows
    }

    static func height(of row: [NotchAgentTile]) -> CGFloat {
        if row.contains(where: \.card.fullWidth) { return chartHeight }
        return row.contains { $0.accountID != nil || $0.namesDefaultAccount } ? accountCardHeight : cardHeight
    }

    static func contentHeight(_ rows: [[NotchAgentTile]]) -> CGFloat {
        guard !rows.isEmpty else { return 0 }
        return rows.map(height).reduce(0, +) + spacing * CGFloat(rows.count - 1)
    }

    static func limitShare(_ window: AgentLimitWindow, display: NotchAgentLimitDisplay) -> String {
        display == .remaining
            ? AgentFormat.percent(window.remainingFraction) + " left"
            : AgentFormat.percent(window.usedFraction) + " used"
    }
}
