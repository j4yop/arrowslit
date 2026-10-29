import SwiftUI

public enum ArrowTheme {
    public static let ink = Color(red: 0.055, green: 0.050, blue: 0.045)
    public static let panel = Color(red: 0.086, green: 0.078, blue: 0.070)
    public static let raised = Color(red: 0.125, green: 0.112, blue: 0.098)
    public static let amber = Color(red: 0.910, green: 0.640, blue: 0.240)
    public static let amberSoft = Color(red: 0.910, green: 0.640, blue: 0.240).opacity(0.16)
    public static let bone = Color(red: 0.960, green: 0.925, blue: 0.860)
    public static let muted = Color.white.opacity(0.52)
    public static let faint = Color.white.opacity(0.28)
    public static let hairline = Color.white.opacity(0.085)
    public static let green = Color(red: 0.420, green: 0.780, blue: 0.580)
    public static let red = Color(red: 0.910, green: 0.400, blue: 0.360)

    public static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
    public static let label = Font.system(size: 10, weight: .semibold)
    public static let body = Font.system(size: 13, weight: .regular)
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
