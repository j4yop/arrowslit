import Foundation
import SwiftUI

struct StatsPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SYSTEM")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(ArrowTheme.faint)
                    Text("Read locally, every two seconds.")
                        .font(.system(size: 11))
                        .foregroundStyle(ArrowTheme.muted)
                }
                Spacer()
                if !state.stats.hasReading {
                    Text("CALIBRATING")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(ArrowTheme.amber)
                }
            }

            HStack(spacing: 10) {
                StatCard(
                    label: "CPU",
                    value: state.stats.hasReading ? StatsMath.percent(state.stats.cpu) : "—",
                    detail: "\(ProcessInfo.processInfo.activeProcessorCount) cores",
                    share: state.stats.hasReading ? state.stats.cpu : nil,
                    level: StatsMath.level(state.stats.cpu)
                )
                StatCard(
                    label: "MEMORY",
                    value: StatsMath.percent(state.stats.memoryShare),
                    detail: "\(StatsMath.bytes(state.stats.memoryUsed)) of \(StatsMath.bytes(state.stats.memoryTotal))",
                    share: state.stats.memoryShare,
                    level: state.stats.pressure
                )
            }

            Text("Arrowslit reads CPU and memory from the kernel. Nothing leaves this Mac.")
                .font(.system(size: 10))
                .foregroundStyle(ArrowTheme.faint)
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
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(ArrowTheme.faint)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(ArrowTheme.bone)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: 9.5))
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
