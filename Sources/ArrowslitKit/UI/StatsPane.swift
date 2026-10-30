import Foundation
import SwiftUI

struct StatsPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneHeader("System")

            HStack(spacing: 10) {
                StatCard(
                    label: "CPU",
                    value: state.stats.hasReading ? StatsMath.percent(state.stats.cpu) : "—",
                    detail: "\(ProcessInfo.processInfo.activeProcessorCount) cores",
                    share: state.stats.hasReading ? state.stats.cpu : nil,
                    level: StatsMath.level(state.stats.cpu)
                )
                StatCard(
                    label: "Memory",
                    value: StatsMath.percent(state.stats.memoryShare),
                    detail: "\(StatsMath.bytes(state.stats.memoryUsed)) of \(StatsMath.bytes(state.stats.memoryTotal))",
                    share: state.stats.memoryShare,
                    level: state.stats.pressure
                )
            }
        }
        .onAppear { state.stats.start() }
        .onDisappear { state.stats.stop() }
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    let detail: String
    let share: Double?
    let level: UsageLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(ArrowTheme.label)
                .foregroundStyle(ArrowTheme.muted)
            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(ArrowTheme.bone)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(ArrowTheme.detail)
                .foregroundStyle(ArrowTheme.muted)
                .lineLimit(1)
            Spacer(minLength: 0)
            UsageBar(share: share ?? 0, level: level)
                .frame(height: 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ArrowTheme.panel)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ArrowTheme.hairline, lineWidth: 0.5)
        }
    }
}

private struct UsageBar: View {
    let share: Double
    let level: UsageLevel

    private var color: Color {
        switch level {
        case .normal: ArrowTheme.green
        case .busy: ArrowTheme.amber
        case .high: ArrowTheme.red
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: max(4, geometry.size.width * CGFloat(share)))
            }
        }
    }
}
