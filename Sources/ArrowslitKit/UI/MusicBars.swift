import AppKit
import QuartzCore
import SwiftUI

/// Four small capsules that rise and fall with the music. The motion runs as Core Animation
/// keyframes, so it lives in the system render server instead of redrawing the app.
struct MusicBars: View {
    var isPlaying: Bool
    var color: Color = ArrowTheme.amber
    var height: CGFloat = 14
    var width: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let width = width ?? max(14, (height * 1.25).rounded())
        MusicBarsRepresentable(
            color: NSColor(color),
            isPlaying: isPlaying,
            animated: !reduceMotion,
            height: height
        )
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

private struct MusicBarsRepresentable: NSViewRepresentable {
    var color: NSColor
    var isPlaying: Bool
    var animated: Bool
    var height: CGFloat

    func makeNSView(context: Context) -> MusicBarsView {
        MusicBarsView()
    }

    func updateNSView(_ view: MusicBarsView, context: Context) {
        view.update(color: color, isPlaying: isPlaying, animated: animated, height: height)
    }

    static func dismantleNSView(_ view: MusicBarsView, coordinator: ()) {
        view.stop()
    }
}

private final class MusicBarsView: NSView {
    private var bars: [CALayer] = []
    private var isPlaying = false
    private var isAnimated = true
    private var barColor = NSColor.white
    private var barHeight: CGFloat = 14

    /// Slightly different loops so the four bars never fall into step.
    private static let levels: [[CGFloat]] = [
        [0.30, 0.85, 0.45, 1.00, 0.38, 0.72, 0.30],
        [0.75, 0.36, 0.95, 0.50, 0.82, 0.28, 0.75],
        [0.45, 0.95, 0.30, 0.65, 0.88, 0.40, 0.45],
        [0.85, 0.40, 0.70, 0.28, 0.80, 1.00, 0.85],
    ]
    private static let resting: CGFloat = 0.26

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer = CALayer()
        for _ in 0..<4 {
            let bar = CALayer()
            bar.cornerRadius = 1.25
            layer?.addSublayer(bar)
            bars.append(bar)
        }
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(color: NSColor, isPlaying: Bool, animated: Bool, height: CGFloat) {
        let colorChanged = barColor != color
        let stateChanged = self.isPlaying != isPlaying || self.isAnimated != animated
        barColor = color
        self.isPlaying = isPlaying
        isAnimated = animated
        barHeight = height

        if colorChanged || stateChanged {
            applyMotion()
        }
    }

    func stop() {
        bars.forEach { $0.removeAllAnimations() }
    }

    override func layout() {
        super.layout()
        applyMotion()
    }

    private func applyMotion() {
        let size = bounds.size
        guard size.width > 0, size.height > 0, !bars.isEmpty else { return }
        let count = CGFloat(bars.count)
        let spacing = max(1.5, size.width * 0.12)
        let width = max(1.5, (size.width - spacing * (count - 1)) / count)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            bar.removeAnimation(forKey: "level")
            bar.backgroundColor = barColor.cgColor
            bar.cornerRadius = width / 2
            bar.position = CGPoint(
                x: CGFloat(index) * (width + spacing) + width / 2,
                y: size.height / 2
            )
            bar.bounds = CGRect(
                x: 0,
                y: 0,
                width: width,
                height: max(width, size.height * Self.resting)
            )

            guard isAnimated, isPlaying else { continue }
            let values = Self.levels[index % Self.levels.count]
            let animation = CAKeyframeAnimation(keyPath: "bounds.size.height")
            animation.values = values.map { max(width, size.height * $0) }
            animation.calculationMode = .cubic
            animation.duration = 1.2 + Double(index) * 0.23
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            bar.add(animation, forKey: "level")
        }
        CATransaction.commit()
    }
}
