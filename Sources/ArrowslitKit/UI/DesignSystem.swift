import SwiftUI

/// Motion tokens for the nook. Apple's defaults: critically damped springs
/// unless a gesture carried momentum. The notch opens on a pointer hover, so
/// its open/close springs must not bounce.
@MainActor
enum NookMotion {
    static var liquidAnimations = true

    static let press = Animation.spring(duration: 0.2, bounce: 0.4)
    static let hover = Animation.easeOut(duration: 0.15)
    static let quick = Animation.easeOut(duration: 0.18)
    static let open = Animation.spring(response: 0.48, dampingFraction: 0.8)
    static let close = Animation.smooth(duration: 0.42)
    static let content = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let drop = Animation.spring(response: 0.38, dampingFraction: 0.86)

    /// `nil` means no implicit animation at all when the user turns Liquid animations off.
    static func reducing(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        guard liquidAnimations else { return nil }
        return reduceMotion ? .easeOut(duration: 0.15) : animation
    }
}

/// Every pressable surface in the nook gets a physical press: a 10%
/// scale and a deeper opacity dip on mouse-down, released with a small spring.
/// Reduce Motion keeps the opacity feedback but drops the scale.
struct NookPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.9

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
                .opacity(configuration.isPressed ? 0.7 : 1)
                .animation(
                    NookMotion.reducing(NookMotion.press, reduceMotion: reduceMotion),
                    value: configuration.isPressed
                )
                .contentShape(Rectangle())
        }
    }
}

/// Shared haptic feedback. Arrowslit uses the alignment haptic for holds, edits and
/// one-shot switches; Arrowslit keeps the same feel and respects the user's toggle.
@MainActor
enum NookHaptics {
    static func perform(enabled: Bool) {
        guard enabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

/// A click that behaves like a launcher tile: a short hold runs `onHold`,
/// while a normal click runs `onClick`. A plain Button also fires after a long hold, which
/// would open a feature while the user is trying to edit the shortcuts.
struct ClickNotHold: ViewModifier {
    var onHold: (() -> Void)?
    let onClick: () -> Void

    func body(content: Content) -> some View {
        content
            .gesture(
                LongPressGesture(minimumDuration: 0.4)
                    .exclusively(before: TapGesture())
                    .onEnded { result in
                        switch result {
                        case .first: onHold?()
                        case .second: onClick()
                        }
                    }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onClick() }
    }
}

extension View {
    /// Expands the hit area around a small control without changing its layout.
    func nookHitSlop(_ inset: CGFloat = 4) -> some View {
        contentShape(Rectangle().inset(by: -inset))
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
