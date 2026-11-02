import Observation
import SwiftUI

/// The display a panel is on. Views read this instead of a process-wide screen so mirror
/// panels on other displays use their own notch and width.
private struct PanelGeometryKey: EnvironmentKey {
    static let defaultValue = ScreenGeometry(
        size: CGSize(width: 1440, height: 900),
        notch: nil,
        menuBarHeight: 24
    )
}

extension EnvironmentValues {
    var panelGeometry: ScreenGeometry {
        get { self[PanelGeometryKey.self] }
        set { self[PanelGeometryKey.self] = newValue }
    }
}

/// Whether this panel is the one the pointer and keyboard are using. With All displays there
/// is one panel per screen; the others mirror the compact state and never take focus.
@MainActor
@Observable
final class PanelRole {
    var isActive: Bool

    init(isActive: Bool) {
        self.isActive = isActive
    }
}
