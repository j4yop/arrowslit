import AppKit
import SwiftUI

/// A DynamicLedge-style surface behind the notch content. Black stays plain black; Glass
/// fades from black around the camera into frosted glass along the bottom edge.
struct NotchSurfaceBackground: View {
    let appearance: NotchAppearance
    let radius: CGFloat
    let flare: CGFloat
    let notchBand: CGFloat

    var body: some View {
        if appearance.theme == .glass {
            GlassSurface(
                shape: IslandShape(bottomRadius: radius, flare: flare),
                tint: appearance.glassTint,
                notchBand: notchBand
            )
        } else {
            ArrowTheme.ink
        }
    }
}

/// Smoked glass: near-black for most of the height so the camera and text read cleanly, then a
/// soft fade into a lighter frosted lip whose edge catches the light.
struct GlassSurface: View {
    let shape: IslandShape
    let tint: Double
    let notchBand: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let height = max(geometry.size.height, 1)
            let amount = min(max((height - max(notchBand, 32) - 14) / 44, 0), 1)
            ZStack {
                if amount > 0.001 {
                    BackdropBlur()
                        .opacity(amount)
                    smoke(height: height, amount: amount)
                    rim(height: height, amount: amount)
                }
                if amount < 0.999 {
                    shape.fill(Color.black.opacity(1 - amount))
                }
            }
            .clipShape(shape)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var bottomShade: Double { 0.08 + 0.5 * tint }

    private func smoke(height: CGFloat, amount: Double) -> some View {
        let band = min(1, notchBand / height)
        let start = max(band, 0.62)
        var stops: [Gradient.Stop] = [
            .init(color: .black, location: 0),
            .init(color: .black, location: band),
            .init(color: .black.opacity(0.93), location: min(1, band + 0.08)),
            .init(color: .black.opacity(0.93), location: start)
        ]
        for step in 1...6 {
            let t = Double(step) / 6
            let eased = t * t * (3 - 2 * t)
            stops.append(.init(
                color: .black.opacity(0.93 - (0.93 - bottomShade) * eased),
                location: start + (1 - start) * t
            ))
        }
        return ZStack {
            LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0), location: 0.82),
                    .init(color: .white.opacity(0.16), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .opacity(amount)
    }

    private func rim(height: CGFloat, amount: Double) -> some View {
        let band = min(1, (notchBand + 8) / height)
        return LinearGradient(
            stops: [
                .init(color: .white.opacity(0), location: 0),
                .init(color: .white.opacity(0), location: band),
                .init(color: .white.opacity(0.08), location: max(band, 0.62)),
                .init(color: .white.opacity(0.5), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .mask(shape.stroke(lineWidth: 1))
        .opacity(amount)
    }
}

/// Blurs whatever is behind the window. The panel never becomes key, so the effect stays active.
private struct BackdropBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
