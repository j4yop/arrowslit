import CoreGraphics

/// The one place that decides how large the notch panel is for each presentation.
public enum NotchPanelMetrics {
    public static let compactHeight: CGFloat = 32
    public static let expandedSize = CGSize(width: 560, height: 178)
    public static let homeSize = CGSize(width: 560, height: 204)
    public static let playerSize = CGSize(width: 306, height: 146)
    public static let playerLyricsSize = CGSize(width: 306, height: 172)
    public static let alertSize = CGSize(width: 560, height: 86)

    public static func size(
        for presentation: NotchPresentation,
        geometry: ScreenGeometry,
        lyrics: Bool = false
    ) -> CGSize {
        switch presentation {
        case .compact:
            CGSize(width: geometry.compactWidth, height: compactHeight)
        case .expanded(.nowPlaying):
            lyrics ? playerLyricsSize : playerSize
        case .expanded(.home):
            homeSize
        case .expanded:
            expandedSize
        case .alert:
            alertSize
        }
    }

    /// The music nudge floats just below the camera housing instead of growing out of it.
    public static func playerTopOffset(for geometry: ScreenGeometry) -> CGFloat {
        geometry.housing.height + 6
    }
}
