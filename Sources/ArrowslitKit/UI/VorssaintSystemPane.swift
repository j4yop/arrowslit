import SwiftUI

/// Vorssaint's System page: a three-column card grid with large readings and
/// a thin white meter, scrolled inside the island's compact content budget.
struct VorssaintSystemPane: View {
    @Bindable var state: AppState

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var stats: StatsService { state.stats }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 10) {
                card(symbol: "cpu", title: "CPU",
                     value: stats.hasReading ? StatsMath.percent(stats.cpu) : "–",
                     share: stats.hasReading ? stats.cpu : nil)
                card(symbol: "display", title: "GPU",
                     value: stats.gpu.map(StatsMath.percent) ?? "–",
                     share: stats.gpu)
                card(symbol: "memorychip", title: "Memory",
                     value: stats.memoryTotal > 0 ? StatsMath.percent(stats.memoryShare) : "–",
                     share: stats.memoryTotal > 0 ? stats.memoryShare : nil)
                batteryCard
                networkCard
                card(symbol: "internaldrive", title: "Available",
                     value: stats.diskTotal > 0 ? StatsMath.bytes(stats.diskFree) : "–",
                     detail: stats.diskTotal > 0 ? "free of \(StatsMath.bytes(stats.diskTotal))" : nil,
                     share: stats.diskTotal > 0 ? 1 - stats.diskShare : nil)
                powerCard
            }
            .padding(.bottom, 2)
        }
        .onAppear { stats.start() }
    }

    private func card(symbol: String, title: String, value: String,
                      detail: String? = nil, share: Double?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.48))

            Spacer(minLength: 2)

            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let detail {
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.34))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 1)
            }

            Spacer(minLength: 4)

            VorssaintFlatMeter(share: share)
                .frame(height: 4)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 82, maxHeight: 82, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.085))
        )
        .accessibilityElement(children: .combine)
    }

    private var batteryCard: some View {
        let level = Double(state.system.batteryLevel) / 100
        return card(
            symbol: "battery.75",
            title: "Battery",
            value: "\(state.system.batteryLevel)%",
            detail: state.system.isCharging ? "Charging" : (state.system.isOnAC ? "On power" : "On battery"),
            share: level
        )
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "network")
                    .font(.system(size: 10, weight: .medium))
                Text("Network")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.48))

            Spacer(minLength: 2)

            rate("arrow.down", stats.hasReading ? StatsMath.rate(stats.networkIn) : "–")
            rate("arrow.up", stats.hasReading ? StatsMath.rate(stats.networkOut) : "–")

            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 82, maxHeight: 82, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.085))
        )
        .accessibilityElement(children: .combine)
    }

    private func rate(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.vertical, 1)
    }

    private var powerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "powerplug")
                    .font(.system(size: 10, weight: .medium))
                Text("Power")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.48))

            Spacer(minLength: 2)

            Text(state.system.isOnAC ? "AC" : "Battery")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(state.system.isCharging ? "Charging now" : (state.system.isOnAC ? "Connected" : "Not connected"))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.34))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 82, maxHeight: 82, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.085))
        )
        .accessibilityElement(children: .combine)
    }
}

struct VorssaintFlatMeter: View {
    let share: Double?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16))
                if let share {
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: max(geometry.size.height, geometry.size.width * CGFloat(min(max(share, 0), 1))))
                }
            }
        }
        .animation(.smooth(duration: 0.5), value: share)
        .accessibilityHidden(true)
    }
}
