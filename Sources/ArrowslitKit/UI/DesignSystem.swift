import SwiftUI

/// Motion tokens for the nook. Apple's defaults: critically damped springs
/// unless a gesture carried momentum. The notch opens on a pointer hover, so
/// its open/close springs must not bounce.
enum NookMotion {
    static let press = Animation.easeOut(duration: 0.12)
    static let hover = Animation.easeOut(duration: 0.14)
    static let quick = Animation.easeOut(duration: 0.18)
    static let open = Animation.spring(response: 0.34, dampingFraction: 1.0)
    static let close = Animation.spring(response: 0.26, dampingFraction: 1.0)
    static let content = Animation.spring(response: 0.3, dampingFraction: 1.0)
    static let drop = Animation.spring(response: 0.28, dampingFraction: 1.0)

    static func reducing(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : animation
    }
}

/// Every pressable surface in the nook gets the same physical press: a 3%
/// scale and a small opacity dip on mouse-down, released quickly. Reduce
/// Motion keeps the opacity feedback but drops the scale.
struct NookPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        NookPressBody(configuration: configuration, pressedScale: pressedScale)
    }

    private struct NookPressBody: View {
        let configuration: ButtonStyleConfiguration
        let pressedScale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? pressedScale : 1))
                .opacity(configuration.isPressed ? 0.86 : 1)
                .animation(
                    NookMotion.reducing(NookMotion.press, reduceMotion: reduceMotion),
                    value: configuration.isPressed
                )
                .contentShape(Rectangle())
        }
    }
}

extension View {
    /// A soft scroll-edge fade instead of a hard divider. Used on horizontal
    /// shelves where cards meet the edge of the nook.
    func nookScrollEdgeFade() -> some View {
        mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.035),
                    .init(color: .black, location: 0.965),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    func nookScrollBounce() -> some View {
        scrollBounceBehavior(.basedOnSize)
    }
}
