import SwiftUI

/// Four small capsules that rise and fall with the music. Paused bars settle
/// to a low resting height instead of disappearing.
struct MusicBars: View {
    var isPlaying: Bool
    var color: Color = ArrowTheme.amber
    var height: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(0..<4, id: \.self) { index in
                    let phase = time * (2.4 + Double(index) * 0.45) + Double(index) * 1.3
                    let level = isPlaying
                        ? 0.22 + 0.78 * abs(sin(phase))
                        : 0.20 + 0.05 * Double(index % 2)
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: max(2.5, height * level))
                }
            }
            .frame(height: height, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}
