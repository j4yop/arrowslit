import SwiftUI

/// The Notch Shell notch outline: a flat top fused to the screen edge, concave shoulders,
/// and a rounded bottom. When `flare` is zero it is a plain rounded rectangle.
public struct IslandShape: Shape {
    public var topRadius: CGFloat
    public var bottomRadius: CGFloat
    public var flare: CGFloat

    public init(topRadius: CGFloat = 0, bottomRadius: CGFloat = 18, flare: CGFloat = 0) {
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
        self.flare = flare
    }

    public func path(in rect: CGRect) -> Path {
        guard rect.width > 0.5, rect.height > 0.5 else { return Path() }
        let flare = min(max(flare, 0), rect.width / 4, rect.height / 2)

        guard flare > 0.01 else {
            let top = min(max(topRadius, 0), rect.width / 2, rect.height / 2)
            let bottom = min(max(bottomRadius, 0), rect.width / 2, rect.height / 2)
            return Path(
                roundedRect: rect,
                cornerRadii: RectangleCornerRadii(
                    topLeading: top,
                    bottomLeading: bottom,
                    bottomTrailing: bottom,
                    topTrailing: top
                ),
                style: .continuous
            )
        }

        let left = rect.minX + flare
        let right = rect.maxX - flare
        let bottom = min(max(bottomRadius, 0), (right - left) / 2, rect.height - flare)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: left, y: rect.minY),
            tangent2End: CGPoint(x: left, y: rect.maxY),
            radius: flare
        )
        path.addArc(
            tangent1End: CGPoint(x: left, y: rect.maxY),
            tangent2End: CGPoint(x: right, y: rect.maxY),
            radius: bottom
        )
        path.addArc(
            tangent1End: CGPoint(x: right, y: rect.maxY),
            tangent2End: CGPoint(x: right, y: rect.minY),
            radius: bottom
        )
        path.addArc(
            tangent1End: CGPoint(x: right, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY),
            radius: flare
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
