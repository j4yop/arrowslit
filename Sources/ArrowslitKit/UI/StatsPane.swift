import Foundation
import SwiftUI

struct StatsPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneHeader("Stats")
            StatsGrid(state: state)
        }
    }
}

/// Memory, CPU, disk and network, side by side, matching the Activity Monitor-style tiles.
struct StatsGrid: View {
    @Bindable var state: AppState

    var body: some View {
        let stats = state.stats
        HStack(spacing: 10) {
            StatsTile(
                symbol: "memorychip",
                title: "Memory",
                value: stats.memoryTotal > 0 ? StatsMath.percent(stats.memoryShare) : "–",
                detail: stats.memoryTotal > 0
                    ? "\(StatsMath.bytes(stats.memoryUsed)) of \(StatsMath.bytes(stats.memoryTotal))"
                    : "",
                share: stats.memoryTotal > 0 ? stats.memoryShare : nil,
                level: stats.pressure
            )
            StatsTile(
                symbol: "cpu",
                title: "CPU",
                value: stats.hasReading ? StatsMath.percent(stats.cpu) : "–",
                detail: "\(ProcessInfo.processInfo.activeProcessorCount) cores",
                share: stats.hasReading ? stats.cpu : nil,
                level: StatsMath.level(stats.cpu)
            )
            StatsTile(
                symbol: "internaldrive",
                title: "Disk",
                value: stats.diskTotal > 0 ? StatsMath.bytes(stats.diskFree) : "–",
                detail: stats.diskTotal > 0 ? "free of \(StatsMath.bytes(stats.diskTotal))" : "",
                share: stats.diskTotal > 0 ? stats.diskShare : nil,
                level: StatsMath.level(stats.diskShare)
            )
            NetworkTile(stats: stats)
        }
        .onAppear { stats.start() }
        .onDisappear { stats.stop() }
    }
}

private struct StatsTile: View {
    let symbol: String
    let title: String
    let value: String
    let detail: String
    let share: Double?
    var level: UsageLevel?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(ArrowTheme.muted)
                .labelStyle(.titleAndIcon)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ArrowTheme.bone)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(ArrowTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            StatsBar(share: share, level: level)
                .frame(height: 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .accessibilityElement(children: .combine)
    }
}

private struct NetworkTile: View {
    let stats: StatsService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Network", systemImage: "network")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(ArrowTheme.muted)
            Spacer(minLength: 4)
            rate("arrow.down", stats.hasReading ? StatsMath.rate(stats.networkIn) : "–", tint: Color(red: 0.35, green: 0.68, blue: 1))
            rate("arrow.up", stats.hasReading ? StatsMath.rate(stats.networkOut) : "–", tint: ArrowTheme.amber)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .accessibilityElement(children: .combine)
    }

    private func rate(_ symbol: String, _ text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ArrowTheme.bone)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 2)
    }
}

struct StatsBar: View {
    let share: Double?
    var level: UsageLevel?

    private var color: Color {
        switch level ?? StatsMath.level(share ?? 0) {
        case .normal: ArrowTheme.green
        case .busy: ArrowTheme.amber
        case .high: ArrowTheme.red
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                if let share {
                    Capsule()
                        .fill(color)
                        .frame(width: max(geometry.size.height, geometry.size.width * CGFloat(share)))
                }
            }
        }
        .animation(.smooth(duration: 0.5), value: share)
        .accessibilityHidden(true)
    }
}
