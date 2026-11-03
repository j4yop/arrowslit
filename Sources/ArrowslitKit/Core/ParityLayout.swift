import CoreGraphics

/// Turns a presentation and a display into the exact DynamicLedge 1.4.2 panel size.
/// This is the size half of the parity layout; the window placement and presentation state
/// machine follow in the next slice.
public enum ParityLayout {
    // MARK: Display

    /// The camera housing, or a 180 pt virtual notch at the top centre of a display without one.
    public static func notch(in geometry: ScreenGeometry) -> CGRect {
        if let notch = geometry.notch { return notch }
        let width = IslandMetrics.virtualNotchWidth
        let height = max(geometry.menuBarHeight, IslandMetrics.virtualNotchMinHeight)
        return CGRect(
            x: ((geometry.size.width - width) / 2).rounded(),
            y: 0,
            width: width,
            height: height
        )
    }

    public static func isVirtualNotch(_ geometry: ScreenGeometry) -> Bool {
        geometry.notch == nil
    }

    // MARK: Compact

    public static func compactHeight(_ appearance: NotchAppearance, geometry: ScreenGeometry) -> CGFloat {
        max(appearance.height, notch(in: geometry).height)
    }

    public static func earWidth(_ appearance: NotchAppearance, geometry: ScreenGeometry) -> CGFloat {
        let height = compactHeight(appearance, geometry: geometry)
        return (IslandMetrics.earWidth(appearance, height: height) * appearance.size.scale).rounded()
    }

    public static func compactWidth(_ appearance: NotchAppearance, geometry: ScreenGeometry) -> CGFloat {
        notch(in: geometry).width + 2 * earWidth(appearance, geometry: geometry)
    }

    public static func compactBubbleDiameter(_ appearance: NotchAppearance, geometry: ScreenGeometry) -> CGFloat {
        max(((compactHeight(appearance, geometry: geometry) - 6) * appearance.size.scale).rounded(), 16)
    }

    public static func compactSize(
        _ appearance: NotchAppearance,
        geometry: ScreenGeometry,
        hasSecondary: Bool = false
    ) -> CGSize {
        let bubble = hasSecondary ? 4 + compactBubbleDiameter(appearance, geometry: geometry) : 0
        return CGSize(
            width: compactWidth(appearance, geometry: geometry) + bubble,
            height: compactHeight(appearance, geometry: geometry)
        )
    }

    /// Vorssaint's resting island adds a wing on either side of the camera
    /// and keeps two points of outline clearance below it.
    public static let restingWingWidth: CGFloat = 58
    public static let restingOutlineInset: CGFloat = 6.5

    /// The invisible hover target around the physical notch. It matches
    /// Vorssaint's resting strip so the outline has the same width and height.
    public static func hiddenSize(_ appearance: NotchAppearance, geometry: ScreenGeometry) -> CGSize {
        let notch = notch(in: geometry)
        return CGSize(
            width: min(geometry.size.width - 24, notch.width + restingWingWidth * 2),
            height: notch.height + 2
        )
    }

    // MARK: Expanded

    public static func expandedWidth(_ appearance: NotchAppearance, geometry: ScreenGeometry) -> CGFloat {
        max(
            (IslandMetrics.expandedWidth(appearance) * appearance.size.scale).rounded(),
            compactWidth(appearance, geometry: geometry) + 40
        )
    }

    public static func nookWidth(_ appearance: NotchAppearance, geometry: ScreenGeometry) -> CGFloat {
        // The 560 pt body carries a 10 pt concave shoulder on each side, like DynamicLedge.
        let flare = 2 * IslandMetrics.expandedFlare * appearance.size.scale
        return max(
            (IslandMetrics.Nook.width * appearance.size.scale + flare).rounded(),
            compactWidth(appearance, geometry: geometry) + 40
        )
    }

    public static func elongatedWidth(_ appearance: NotchAppearance, geometry: ScreenGeometry) -> CGFloat {
        let room = geometry.size.width - 2 * (IslandMetrics.Nook.elongatedEdge + IslandMetrics.expandedFlare)
        return max(
            nookWidth(appearance, geometry: geometry),
            min(room, (IslandMetrics.Nook.elongatedMaxWidth * appearance.size.scale).rounded())
        )
    }

    public static func expandedHeight(content: CGFloat, appearance: NotchAppearance, geometry: ScreenGeometry) -> CGFloat {
        notch(in: geometry).height
            + IslandMetrics.notchContentGap
            + (content * appearance.size.scale).rounded()
            + (IslandMetrics.notchBottomPadding * appearance.size.scale).rounded()
    }

    /// Content height for a workbench tab, before the notch strip and bottom padding are added.
    public static func contentHeight(
        for tab: WorkbenchTab,
        clipboardSearching: Bool = false,
        hasLyrics: Bool = false,
        hasMediaSwitcher: Bool = false
    ) -> CGFloat {
        switch tab {
        case .call: IslandMetrics.ContentHeight.call
        case .download: IslandMetrics.ContentHeight.download
        case .nowPlaying:
            IslandMetrics.ContentHeight.nowPlaying
                + (hasLyrics ? IslandMetrics.ContentHeight.lyrics : 0)
                + (hasMediaSwitcher ? IslandMetrics.ContentHeight.mediaSwitcher : 0)
        case .clipboard:
            IslandMetrics.Nook.body + IslandMetrics.Nook.bodyTopInset
                + (clipboardSearching ? IslandMetrics.Nook.searchBar : 0)
        case .home, .tray, .notes, .mirror, .calendar, .reminders, .stats, .sports, .keepAwake, .timer, .stopwatch:
            IslandMetrics.Nook.body + IslandMetrics.Nook.bodyTopInset
        case .launcher: IslandMetrics.Nook.launcherBody + IslandMetrics.Nook.bodyTopInset
        }
    }

    /// True for the three views that stretch across the top in the elongated layout.
    public static func isElongated(_ tab: WorkbenchTab, appearance: NotchAppearance) -> Bool {
        guard appearance.nookLayout == .elongated else { return false }
        return tab == .home || tab == .tray || tab == .clipboard
    }

    public static func expandedSize(
        for tab: WorkbenchTab,
        appearance: NotchAppearance,
        geometry: ScreenGeometry,
        clipboardSearching: Bool = false,
        hasLyrics: Bool = false,
        hasMediaSwitcher: Bool = false
    ) -> CGSize {
        // Everything except the three dedicated activity panels lives in the nook width.
        let nook = tab != .call && tab != .download && tab != .nowPlaying
        let width: CGFloat
        if isElongated(tab, appearance: appearance) {
            width = elongatedWidth(appearance, geometry: geometry)
        } else if nook {
            width = nookWidth(appearance, geometry: geometry)
        } else {
            width = expandedWidth(appearance, geometry: geometry)
        }
        return CGSize(
            width: width,
            height: expandedHeight(
                content: contentHeight(
                    for: tab,
                    clipboardSearching: clipboardSearching,
                    hasLyrics: hasLyrics,
                    hasMediaSwitcher: hasMediaSwitcher
                ),
                appearance: appearance,
                geometry: geometry
            )
        )
    }

    public static func clockSize(_ appearance: NotchAppearance, geometry: ScreenGeometry) -> CGSize {
        CGSize(
            width: expandedWidth(appearance, geometry: geometry),
            height: expandedHeight(content: IslandMetrics.ContentHeight.timer, appearance: appearance, geometry: geometry)
        )
    }

    // MARK: Alerts

    public static func alertWidth(for alert: NotchAlert, appearance: NotchAppearance, geometry: ScreenGeometry) -> CGFloat {
        let notch = notch(in: geometry)
        let ear = earWidth(appearance, geometry: geometry)
        let scale = appearance.size.scale

        switch alert {
        case .level:
            return notch.width + 2 * max(ear, (IslandMetrics.levelEarWidth * scale).rounded())
        case .upcomingEvent, .download, .update, .welcome, .sportsGoal, .shortcut:
            return notch.width + 2 * max(ear, (IslandMetrics.namedAlertEarWidth * scale).rounded())
        case .agentRequest:
            return 560
        case .timerFinished, .charging, .lowBattery, .headphones:
            return notch.width + 2 * max(ear, (IslandMetrics.alertEarWidth * scale).rounded())
        }
    }

    public static func alertSize(for alert: NotchAlert, appearance: NotchAppearance, geometry: ScreenGeometry) -> CGSize {
        let compact = compactHeight(appearance, geometry: geometry)
        let height: CGFloat = {
            if case .level = alert { return compact }
            return compact + (6 * appearance.size.scale).rounded()
        }()
        return CGSize(
            width: alertWidth(for: alert, appearance: appearance, geometry: geometry),
            height: height
        )
    }

    // MARK: The one entry point views use

    public static func size(
        for presentation: NotchPresentation,
        appearance: NotchAppearance,
        geometry: ScreenGeometry
    ) -> CGSize {
        switch presentation {
        case .hidden:
            return hiddenSize(appearance, geometry: geometry)
        case .idle:
            return compactSize(appearance, geometry: geometry)
        case .compact(_, let secondary):
            return compactSize(appearance, geometry: geometry, hasSecondary: secondary != nil)
        case .hud(let alert):
            return CGSize(
                width: alertWidth(for: alert, appearance: appearance, geometry: geometry),
                height: compactHeight(appearance, geometry: geometry)
            )
        case .alert(let alert):
            return alertSize(for: alert, appearance: appearance, geometry: geometry)
        case .expanded(let tab):
            return expandedSize(for: tab, appearance: appearance, geometry: geometry)
        case .clockRunning:
            return clockSize(appearance, geometry: geometry)
        }
    }

    // MARK: Shape

    public static func bottomRadius(for presentation: NotchPresentation, appearance: NotchAppearance, geometry: ScreenGeometry) -> CGFloat {
        let height = compactHeight(appearance, geometry: geometry)
        switch presentation {
        case .hidden(let peek):
            return peek ? 11 : 9
        case .idle, .compact, .hud:
            return min(height * 0.42, 14)
        case .alert(let alert):
            if case .level = alert { return min(height * 0.42, 14) }
            return min(height * 0.42, 16)
        case .expanded, .clockRunning:
            return (IslandMetrics.notchExpandedRadius * appearance.size.scale).rounded()
        }
    }

    public static func flare(for presentation: NotchPresentation) -> CGFloat {
        switch presentation {
        case .hidden:
            return 5
        case .idle, .compact, .hud, .alert:
            return IslandMetrics.compactFlare
        case .expanded, .clockRunning:
            return IslandMetrics.expandedFlare
        }
    }
}
