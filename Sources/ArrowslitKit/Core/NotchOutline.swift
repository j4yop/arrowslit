import CoreGraphics

/// The optional outline AI Agents draws on the island. It is a 2-point stroke
/// clipped to the inside of the silhouette, with a 1-point gap along the top
/// edge because the island hangs from the top of the display. The same radii
/// as the drawn surfaces keep it on the panel at every presentation.
public enum NotchOutline {
    public static let key = "notchOutlineEnabled"
    public static let lineWidth: CGFloat = 2
    public static let topGap: CGFloat = 1
    public static let opacity: Double = 0.65
    public static let increasedContrastOpacity: Double = 0.85

    /// The bottom radius of the surface this presentation draws, or nil when
    /// nothing is visible.
    public static func radius(for presentation: NotchPresentation) -> CGFloat? {
        switch presentation {
        case .hidden(let peek):
            return peek ? 11 : nil
        case .idle, .compact, .hud:
            return 12
        case .alert:
            return 16
        case .expanded, .clockRunning:
            return 30
        }
    }

    public static func flare(for presentation: NotchPresentation) -> CGFloat {
        switch presentation {
        case .hidden:
            return 5
        case .idle, .compact, .hud, .alert:
            return 6
        case .expanded, .clockRunning:
            return 10
        }
    }
}
