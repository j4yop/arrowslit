import SwiftUI

public enum ArrowTheme {
    public static let ink = Color.black
    public static let panel = Color(red: 0.035, green: 0.035, blue: 0.035)
    public static let raised = Color(red: 0.085, green: 0.085, blue: 0.085)
    public static let amber = Color(red: 1.0, green: 0.624, blue: 0.039)
    public static let amberSoft = Color(red: 1.0, green: 0.624, blue: 0.039).opacity(0.16)
    public static let bone = Color.white
    public static let muted = Color.white.opacity(0.62)
    public static let faint = Color.white.opacity(0.48)
    public static let hairline = Color.white.opacity(0.09)
    public static let green = Color(red: 0.420, green: 0.780, blue: 0.580)
    public static let red = Color(red: 0.910, green: 0.400, blue: 0.360)

    public static let title = Font.system(size: 13, weight: .semibold)
    public static let label = Font.system(size: 11, weight: .medium)
    public static let body = Font.system(size: 12, weight: .regular)
    public static let detail = Font.system(size: 11, weight: .regular)
    public static let caption = Font.system(size: 10, weight: .regular)
}

/// A notch-fused rectangle: flat top, softly rounded bottom.
public struct SlitShape: Shape {
    public var radius: CGFloat

    public init(radius: CGFloat) {
        self.radius = radius
    }

    public func path(in rect: CGRect) -> Path {
        Path(
            roundedRect: rect,
            cornerRadii: RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: 0
            ),
            style: .continuous
        )
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
