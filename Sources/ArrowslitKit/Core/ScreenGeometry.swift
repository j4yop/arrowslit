import AppKit
import CoreGraphics

/// The parts of a display the panel needs, in points with a top-left origin.
public struct ScreenGeometry: Equatable, Sendable {
    public var size: CGSize
    public var notch: CGRect?
    public var menuBarHeight: CGFloat

    public init(size: CGSize, notch: CGRect?, menuBarHeight: CGFloat) {
        self.size = size
        self.notch = notch
        self.menuBarHeight = menuBarHeight
    }

    public var hasNotch: Bool { notch != nil }

    /// The camera housing, or a virtual 160 pt notch at the top centre of a display without one.
    public var housing: CGRect {
        if let notch { return notch }
        let width: CGFloat = 160
        let height = max(menuBarHeight, 30)
        return CGRect(x: ((size.width - width) / 2).rounded(), y: 0, width: width, height: height)
    }

    public var centreX: CGFloat { housing.midX }

    /// The compact strip never gets narrower than the notch plus two readable ears.
    public var compactWidth: CGFloat {
        max(320, min(420, (housing.width + 140).rounded()))
    }

    /// Space available on each side of the camera housing inside a panel of `width`.
    public func earWidth(in width: CGFloat) -> CGFloat {
        max(0, (width - housing.width) / 2)
    }
}

@MainActor
public enum ScreenReader {
    public static func geometry(for screen: NSScreen) -> ScreenGeometry {
        let frame = screen.frame
        var notch: CGRect?
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let minX = left.maxX - frame.minX
            let maxX = right.minX - frame.minX
            if maxX > minX {
                notch = CGRect(x: minX, y: 0, width: maxX - minX, height: screen.safeAreaInsets.top)
            }
        }
        let reservedTop = frame.maxY - screen.visibleFrame.maxY
        let menuBar = reservedTop > 0 ? reservedTop : NSStatusBar.system.thickness + 2
        return ScreenGeometry(size: frame.size, notch: notch, menuBarHeight: menuBar)
    }

    public static func builtIn() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// Geometry for the display the panel is on, with a safe fallback.
    public static var current: ScreenGeometry {
        if let screen = builtIn() {
            return geometry(for: screen)
        }
        return ScreenGeometry(
            size: CGSize(width: 1440, height: 900),
            notch: nil,
            menuBarHeight: 24
        )
    }
}
