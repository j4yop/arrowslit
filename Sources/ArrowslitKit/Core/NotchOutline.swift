import CoreGraphics

/// The optional outline Vorssaint draws on the island. It is a 2-point stroke
/// clipped to the inside of the silhouette, with a 1-point gap along the top
/// edge because the island hangs from the top of the display. The same radii
/// as the drawn surfaces keep it on the panel at every presentation.
public enum NotchOutline {
    public static let key = "notchOutlineEnabled"
    public static let lineWidth: CGFloat = 2
    public static let topGap: CGFloat = 1
    public static let opacity: Double = 0.65
    public static let increasedContrastOpacity: Double = 0.85

    /// The bottom radius of the surface this presentation draws. At rest the
    /// outline belongs to the physical notch, not the wider hidden window.
    public static func radius(for presentation: NotchPresentation) -> CGFloat? {
        switch presentation {
        case .hidden(let peek):
            return peek ? 11 : 12
        case .idle, .compact, .hud:
            return 12
        case .alert:
            return 16
        case .expanded, .clockRunning:
            return 30
        }
    }

    /// Vorssaint keeps the outline on the resting and opened island, and
    /// drops it while a live activity, HUD or notification is using the
    /// compact strip. The setting still switches all of it.
    public static func isVisible(for presentation: NotchPresentation) -> Bool {
        switch presentation {
        case .hidden, .idle, .expanded:
            return true
        case .compact, .hud, .alert, .clockRunning:
            return false
        }
    }

    public static func flare(for presentation: NotchPresentation) -> CGFloat {
        switch presentation {
        case .hidden(let peek):
            return peek ? 5 : 0
        case .idle, .compact, .hud, .alert:
            return 6
        case .expanded, .clockRunning:
            return 10
        }
    }
}
