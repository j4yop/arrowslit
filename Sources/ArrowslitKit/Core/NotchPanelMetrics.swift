import CoreGraphics

/// The one place that decides how large the notch panel is for each presentation.
public enum NotchPanelMetrics {
    public static let compactHeight: CGFloat = 32
    public static let expandedSize = CGSize(width: 560, height: 178)
    public static let playerSize = CGSize(width: 390, height: 218)
    public static let alertSize = CGSize(width: 560, height: 86)

    public static func size(for presentation: NotchPresentation, geometry: ScreenGeometry) -> CGSize {
        switch presentation {
        case .compact:
            CGSize(width: geometry.compactWidth, height: compactHeight)
        case .expanded(.nowPlaying):
            playerSize
        case .expanded:
            expandedSize
        case .alert:
            alertSize
        }
    }
}
