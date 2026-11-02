import SwiftUI

public enum ArrowTheme {
    public static let ink = Color.black
    public static let panel = Color(red: 0.035, green: 0.035, blue: 0.035)
    public static let raised = Color(red: 0.085, green: 0.085, blue: 0.085)
    public static let amber = Color(red: 1.0, green: 159 / 255, blue: 10 / 255)
    public static let amberSoft = amber.opacity(0.16)
    public static let bone = Color.white
    public static let muted = Color.white.opacity(0.55)
    public static let faint = Color.white.opacity(0.38)
    public static let hairline = Color.white.opacity(0.1)
    public static let green = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
    public static let red = Color(red: 1, green: 69 / 255, blue: 58 / 255)
    public static let blue = Color(red: 10 / 255, green: 132 / 255, blue: 1)
    public static let yellow = Color(red: 1, green: 214 / 255, blue: 10 / 255)

    public static let title = Font.system(size: 13, weight: .semibold)
    public static let label = Font.system(size: 11, weight: .medium)
    public static let body = Font.system(size: 12, weight: .regular)
    public static let settingsBody = Font.system(size: 13, weight: .regular)
    public static let detail = Font.system(size: 11, weight: .regular)
    public static let caption = Font.system(size: 10, weight: .regular)
}

/// A notch-fused rectangle: flat top, softly rounded bottom. Pass a flare to get the
/// DynamicLedge-style concave shoulders; the default keeps the original Arrowslit silhouette.
public struct SlitShape: Shape {
    public var radius: CGFloat
    public var flare: CGFloat
    public var topRadius: CGFloat

    public init(radius: CGFloat, flare: CGFloat = 0, topRadius: CGFloat = 0) {
        self.radius = radius
        self.flare = flare
        self.topRadius = topRadius
    }

    public func path(in rect: CGRect) -> Path {
        IslandShape(topRadius: topRadius, bottomRadius: radius, flare: flare).path(in: rect)
    }
}

/// A small vertical aperture used as the brand mark.
public struct SlitMark: View {
    public var height: CGFloat
    public var color: Color

    public init(height: CGFloat = 18, color: Color = ArrowTheme.amber) {
        self.height = height
        self.color = color
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(color)
                .frame(width: 3, height: height)
            Capsule()
                .fill(color)
                .frame(width: 11, height: 3)
                .offset(y: 1)
        }
        .frame(width: 12, height: height + 2)
        .accessibilityHidden(true)
    }
}

extension ArtworkAccent {
    /// SwiftUI colour for the music bars.
    public var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}
