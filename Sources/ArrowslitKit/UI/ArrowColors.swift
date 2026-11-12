import AppKit
import SwiftUI

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

extension NSColor {
    static func arrowDynamic(dark: NSColor, light: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in appearance.isDark ? dark : light }
    }

    static let arrowPanelTint = arrowDynamic(
        dark: NSColor(white: 0.02, alpha: 0.84),
        light: NSColor(white: 0.98, alpha: 0.62)
    )
    static let arrowCard = arrowDynamic(
        dark: NSColor(white: 0.10, alpha: 1),
        light: NSColor(white: 0.93, alpha: 0.78)
    )
    static let arrowCardHover = arrowDynamic(
        dark: NSColor(white: 0.14, alpha: 1),
        light: NSColor(white: 1.0, alpha: 0.92)
    )
    static let arrowText = arrowDynamic(
        dark: .white,
        light: NSColor(white: 0.04, alpha: 1)
    )
    static let arrowSecondaryText = arrowDynamic(
        dark: NSColor.white.withAlphaComponent(0.42),
        light: NSColor(white: 0.08, alpha: 0.52)
    )
    static let arrowTertiaryText = arrowDynamic(
        dark: NSColor.white.withAlphaComponent(0.28),
        light: NSColor(white: 0.08, alpha: 0.34)
    )
    static let arrowIcon = arrowDynamic(
        dark: NSColor.white.withAlphaComponent(0.78),
        light: NSColor(white: 0.05, alpha: 0.72)
    )
    static let arrowIconCircle = arrowDynamic(
        dark: NSColor.white.withAlphaComponent(0.09),
        light: NSColor(white: 0.0, alpha: 0.08)
    )
    static let arrowPill = arrowDynamic(
        dark: NSColor.white.withAlphaComponent(0.09),
        light: NSColor(white: 0.0, alpha: 0.06)
    )
    static let arrowStroke = arrowDynamic(
        dark: NSColor.white.withAlphaComponent(0.06),
        light: NSColor(white: 0.0, alpha: 0.08)
    )
    static let arrowShelfCard = arrowDynamic(
        dark: NSColor(white: 0.11, alpha: 1),
        light: NSColor(white: 0.94, alpha: 1)
    )
    static let arrowShelfMuted = arrowDynamic(
        dark: NSColor.white.withAlphaComponent(0.55),
        light: NSColor(white: 0.08, alpha: 0.5)
    )
    static let arrowCheckerLight = arrowDynamic(
        dark: NSColor(white: 0.17, alpha: 1),
        light: NSColor(white: 0.88, alpha: 1)
    )
    static let arrowCheckerDark = arrowDynamic(
        dark: NSColor(white: 0.11, alpha: 1),
        light: NSColor(white: 0.80, alpha: 1)
    )
    static let arrowImageFrame = arrowDynamic(
        dark: .white,
        light: NSColor(white: 0.08, alpha: 0.9)
    )
    static let arrowGlow = arrowDynamic(
        dark: .white,
        light: NSColor(white: 0.0, alpha: 0.38)
    )
}

extension Color {
    static let arrowPanelTint = Color(nsColor: .arrowPanelTint)
    static let arrowCard = Color(nsColor: .arrowCard)
    static let arrowCardHover = Color(nsColor: .arrowCardHover)
    static let arrowText = Color(nsColor: .arrowText)
    static let arrowSecondaryText = Color(nsColor: .arrowSecondaryText)
    static let arrowTertiaryText = Color(nsColor: .arrowTertiaryText)
    static let arrowIcon = Color(nsColor: .arrowIcon)
    static let arrowIconCircle = Color(nsColor: .arrowIconCircle)
    static let arrowPill = Color(nsColor: .arrowPill)
    static let arrowStroke = Color(nsColor: .arrowStroke)
    static let arrowShelfCard = Color(nsColor: .arrowShelfCard)
    static let arrowShelfMuted = Color(nsColor: .arrowShelfMuted)
    static let arrowCheckerLight = Color(nsColor: .arrowCheckerLight)
    static let arrowCheckerDark = Color(nsColor: .arrowCheckerDark)
    static let arrowImageFrame = Color(nsColor: .arrowImageFrame)
    static let arrowGlow = Color(nsColor: .arrowGlow)
}

/// The frosted backing used by the Command Center and the clipboard shelf.
struct ArrowVisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
