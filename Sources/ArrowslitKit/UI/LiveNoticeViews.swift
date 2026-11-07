// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Arrowslit
//
// The live notice row and compact strip layouts.

import AppKit
import SwiftUI

/// The live closed-island metrics. The strip is two wings around the
/// physical camera: a mark and one short reading on each side, never a card.
enum LiveNoticeMetrics {
    /// The live notice metrics: measured wings, a 16 pt curved-end inset,
    /// and an 18 pt mark slot with 8 pt between it and its words.
    static let noticeInset: CGFloat = 16
    static let levelInset: CGFloat = 13
    static let minimumWing: CGFloat = 36
    static let spacing: CGFloat = 8
    static let groupSpacing: CGFloat = 10
    static let symbolSize: CGFloat = 14
    static let symbolSlot: CGFloat = 18
    static let air: CGFloat = 2
    static var noticeFont: NSFont { .monospacedDigitSystemFont(ofSize: 11, weight: .medium) }
    static let noticeTitle = Font.system(size: 11, weight: .medium)
    static let noticeDetail = Font.system(size: 11, weight: .medium)
    static let noticeNumber = Font.system(size: 11, weight: .medium).monospacedDigit()
    static let stripTitle = Font.system(size: 12, weight: .semibold)
    static let stripReading = Font.system(size: 13, weight: .semibold).monospacedDigit()
    static let stripSmall = Font.system(size: 11, weight: .medium).monospacedDigit()
    static let meterHeight: CGFloat = 5
    static let stripInset: CGFloat = 11

    /// The compact strip's fonts and clearance: a 16 pt reading, a 20 pt
    /// mark, and 11 pt from the curved end.
    static func stripTextSize(height: CGFloat) -> CGFloat { min(16, height - 6) }
    static func stripIconSize(height: CGFloat) -> CGFloat { min(20, height - 10) }

    /// The two sides of a closed notice beside the camera, each as wide as
    /// what it shows. The island reaches further toward its wider side.
    struct Wings: Equatable {
        var leading: CGFloat
        var trailing: CGFloat
        var widest: CGFloat { max(leading, trailing) }
    }

    static func measure(_ text: String) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return (String(text.prefix(240)) as NSString)
            .size(withAttributes: [.font: noticeFont])
            .width.rounded(.up)
    }

    static func isAccessory(_ alert: NotchAlert) -> Bool {
        if case .headphones = alert { return true }
        return false
    }

    static func isBattery(_ alert: NotchAlert) -> Bool {
        switch alert {
        case .charging, .lowBattery: return true
        default: return false
        }
    }

    static func cameraGap(for alert: NotchAlert) -> CGFloat {
        if isBattery(alert) { return 16 }
        if case .level = alert { return 0 }
        if case .systemNotification = alert { return 0 }
        return 6
    }

    static func inset(for alert: NotchAlert, wing: CGFloat) -> CGFloat {
        if case .level = alert { return levelInset }
        return min(noticeInset, wing / 2)
    }

    /// The wings measured for the same notice. Levels hold one width for
    /// their mark and their widest reading; banners measure their sender and
    /// message; every other notice measures its title and detail.
    static func wings(for alert: NotchAlert, timerWasFocus: Bool = false) -> Wings {
        if case .systemNotification(let app, let title, let body) = alert {
            return notificationWings(app: app, title: title, body: body)
        }
        if case .level(let kind, let value, let muted) = alert {
            let detail = levelDetail(kind: kind, value: value, muted: muted)
            let wing = ceil(levelInset + symbolSlot + spacing + max(measure(detail), measure("100%")))
            return Wings(leading: wing, trailing: wing)
        }
        let title = noticeTitle(alert, timerWasFocus: timerWasFocus)
        let detail = noticeDetail(alert, timerWasFocus: timerWasFocus)
        let maximum: CGFloat = isAccessory(alert) ? 160 : 240
        let gap = cameraGap(for: alert)
        func fitted(_ content: CGFloat) -> CGFloat {
            min(maximum, max(minimumWing, content.rounded(.up) + noticeInset + gap))
        }
        // An empty title leaves the mark alone, without the space after it.
        let mark = fitted(title.isEmpty ? symbolSlot : measure(title) + symbolSlot + spacing)
        return Wings(leading: mark, trailing: fitted(measure(detail)))
    }

    private static func notificationWings(app: String, title: String, body: String) -> Wings {
        let titleFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let messageFont = NSFont.systemFont(ofSize: 11)
        func width(_ text: String, _ font: NSFont) -> CGFloat {
            guard !text.isEmpty else { return 0 }
            return (String(text.prefix(240)) as NSString)
                .size(withAttributes: [.font: font]).width.rounded(.up)
        }
        let leadingText = title.isEmpty ? app : title
        let leading = 22 + 8 + width(leadingText, titleFont)
        var detail = width(body, messageFont)
        // A strip is tall enough for two lines; a long message takes the
        // width its wrapped lines need, not the whole wing.
        let room = 190 - noticeInset - 6
        if detail > room {
            let wrapped = (String(body.prefix(240)) as NSString).boundingRect(
                with: CGSize(width: room, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: messageFont]
            )
            detail = min(room, wrapped.width.rounded(.up))
        }
        func fitted(_ side: CGFloat) -> CGFloat {
            min(190, max(minimumWing, side + noticeInset + 6))
        }
        return Wings(leading: fitted(leading), trailing: fitted(detail))
    }

    static func noticeTitle(_ alert: NotchAlert, timerWasFocus: Bool = false) -> String {
        switch alert {
        case .charging(_, let isCharging): return isCharging ? "Charging" : "Plugged in"
        case .lowBattery: return "Low Battery"
        case .headphones: return "Connected"
        case .clipboard: return "Copied"
        case .microphone: return ""
        case .inputSource(let code, _): return code
        case .agentEvent(let provider, let title, _):
            if title == "Finished" { return "\(provider) finished" }
            if title == "Budget" { return "AI budget" }
            return "\(provider) · \(title)"
        case .upcomingEvent(let title, _, _, _): return title
        case .timerFinished: return timerWasFocus ? "Pomodoro finished" : "Timer finished"
        case .track(let title, _): return title
        case .systemNotification(let app, let title, _): return title.isEmpty ? app : title
        case .capture(let kind): return kind
        case .watch(let title, _): return title
        case .download: return "Downloaded"
        case .update(let version): return "Update \(version)"
        case .welcome(let name): return name.isEmpty ? "Welcome" : "Welcome, \(name)"
        case .shortcut(let name, _): return name
        case .sportsGoal(let goal): return "GOAL · \(goal.teamShortName)"
        case .agentRequest: return ""
        case .level: return ""
        }
    }

    static func noticeDetail(_ alert: NotchAlert, timerWasFocus: Bool = false) -> String {
        switch alert {
        case .charging(let level, _): return "\(level)%"
        case .lowBattery(let level): return "\(level)%"
        case .headphones(let name): return name
        case .clipboard(let kind): return kind
        case .microphone(let muted): return muted ? "Mic muted" : "Mic unmuted"
        case .inputSource(_, let name): return name
        case .agentEvent(_, _, let detail): return detail
        case .upcomingEvent(_, let startsAt, _, _):
            let minutes = max(0, Int((startsAt.timeIntervalSinceNow / 60).rounded(.up)))
            return minutes <= 0 ? "Now" : "\(minutes)m"
        case .timerFinished: return timerWasFocus ? "Break" : "Focus"
        case .track(_, let artist): return artist
        case .systemNotification(_, _, let body): return body
        case .capture: return ""
        case .watch(_, let detail): return detail
        case .download(let name): return name
        case .update: return "Ready"
        case .welcome: return "Free · Open source"
        case .shortcut(_, let succeeded): return succeeded ? "Done" : "Failed"
        case .sportsGoal(let goal): return goal.scoreLine
        case .agentRequest: return ""
        case .level(let kind, let value, let muted):
            return levelDetail(kind: kind, value: value, muted: muted)
        }
    }

    static func levelDetail(kind: NotchAlert.LevelKind, value: Double, muted: Bool) -> String {
        if muted { return "Muted" }
        return "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    static func noticeSymbol(_ alert: NotchAlert) -> String {
        switch alert {
        case .charging: return "battery.100percent.bolt"
        case .lowBattery: return "battery.25percent"
        case .headphones(let name): return accessorySymbol(for: name)
        case .clipboard: return "doc.on.clipboard"
        case .microphone(let muted): return muted ? "mic.slash.fill" : "mic.fill"
        case .inputSource: return "keyboard"
        case .agentEvent(let provider, let title, let detail):
            // A limit warning says so with its mark, whatever window it names.
            if title == "Limit" || detail.hasSuffix(" used") { return "exclamationmark.triangle.fill" }
            if title == "Limit reset" || detail == "Renewed" { return "arrow.clockwise" }
            if title == "Budget" { return "dollarsign.circle.fill" }
            return AgentProvider.allCases.first { $0.displayName == provider }?.symbol ?? "sparkle"
        case .upcomingEvent: return "calendar"
        case .timerFinished: return "timer"
        case .track: return "music.note"
        case .systemNotification: return "bell.fill"
        case .capture: return "camera.viewfinder"
        case .watch: return "eye"
        case .download: return "arrow.down.circle.fill"
        case .update: return "arrow.down.circle.fill"
        case .welcome: return "hand.wave.fill"
        case .shortcut: return "bolt.fill"
        case .sportsGoal: return "soccerball"
        case .agentRequest: return "terminal.fill"
        case .level(let kind, let value, let muted):
            switch kind {
            case .volume: return muted || value == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill"
            case .brightness: return "sun.max.fill"
            case .keyboardLight: return "keyboard"
            }
        }
    }

    /// The mark chosen for the connected device.
    static func accessorySymbol(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        return "headphones"
    }

    static func noticeTint(_ alert: NotchAlert) -> Color {
        switch alert {
        case .agentEvent(let provider, _, _):
            if noticeSymbol(alert).hasPrefix("exclamationmark") { return .orange }
            if let p = AgentProvider.allCases.first(where: { $0.displayName == provider }) { return p.tint }
            return .white
        case .timerFinished: return .orange
        case .sportsGoal: return ArrowTheme.green
        case .shortcut(_, let succeeded): return succeeded ? ArrowTheme.green : ArrowTheme.red
        default: return .white
        }
    }

    static func isNotificationBanner(_ alert: NotchAlert) -> Bool {
        if case .systemNotification = alert { return true }
        return false
    }

    static func isTrackNotice(_ alert: NotchAlert) -> Bool {
        if case .track = alert { return true }
        return false
    }
}

/// One compact notice row: the leading wing reads from the curved end toward
/// the camera, the trailing wing reads from the camera toward the other end.
/// Each side is as wide as what it shows, and the island reaches further
/// toward its wider side.
struct LiveNoticeView: View {
    @Bindable var state: AppState
    let alert: NotchAlert
    let width: CGFloat
    let height: CGFloat
    let notchWidth: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var wings: LiveNoticeMetrics.Wings {
        LiveNoticeMetrics.wings(for: alert, timerWasFocus: state.timer.lastWasFocus)
    }
    private var tint: Color { LiveNoticeMetrics.noticeTint(alert) }
    private var cameraGap: CGFloat { LiveNoticeMetrics.cameraGap(for: alert) }
    private var leadingInset: CGFloat { LiveNoticeMetrics.inset(for: alert, wing: wings.leading) }
    private var trailingInset: CGFloat { LiveNoticeMetrics.inset(for: alert, wing: wings.trailing) }
    private var title: String { LiveNoticeMetrics.noticeTitle(alert, timerWasFocus: state.timer.lastWasFocus) }
    private var detail: String { LiveNoticeMetrics.noticeDetail(alert, timerWasFocus: state.timer.lastWasFocus) }

    var body: some View {
        HStack(spacing: 0) {
            leadingContent
                .padding(.leading, leadingInset)
                .padding(.trailing, cameraGap)
                .frame(width: wings.leading, height: height, alignment: .leading)
                .clipped()

            Color.clear.frame(width: notchWidth)

            trailingContent
                .padding(.leading, cameraGap)
                .padding(.trailing, trailingInset)
                .frame(width: wings.trailing, height: height, alignment: .trailing)
                .clipped()
        }
        .frame(width: width, height: height)
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var leadingContent: some View {
        if LiveNoticeMetrics.isNotificationBanner(alert), case .systemNotification(let app, _, _) = alert {
            HStack(spacing: LiveNoticeMetrics.spacing) {
                NotificationIcon(app: app, size: min(22, height - 4))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if LiveNoticeMetrics.isTrackNotice(alert) {
            HStack(spacing: LiveNoticeMetrics.spacing) {
                TrackNoticeArtwork(state: state, size: min(18, height - 6))
                Text(title)
                    .font(LiveNoticeMetrics.noticeTitle)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if case .level = alert {
            HStack(spacing: LiveNoticeMetrics.spacing) {
                Image(systemName: LiveNoticeMetrics.noticeSymbol(alert))
                    .font(.system(size: LiveNoticeMetrics.symbolSize, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: LiveNoticeMetrics.symbolSlot)
                Text(detail)
                    .font(LiveNoticeMetrics.noticeNumber)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
        } else {
            HStack(spacing: LiveNoticeMetrics.spacing) {
                mark
                if !title.isEmpty {
                    Text(title)
                        .font(LiveNoticeMetrics.noticeTitle)
                        .monospacedDigit()
                        .foregroundStyle(isTimer ? .orange : .white)
                        .lineLimit(1)
                        .truncationMode(LiveNoticeMetrics.isTrackNotice(alert) ? .tail : .middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder private var trailingContent: some View {
        if case .level(let kind, let value, let muted) = alert {
            VSNoticeMeter(value: muted ? 0 : value, tint: tint)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: value)
        } else if LiveNoticeMetrics.isNotificationBanner(alert) {
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            Text(detail)
                .font(LiveNoticeMetrics.noticeDetail)
                .foregroundStyle(trailingTint)
                .lineLimit(1)
                .truncationMode(LiveNoticeMetrics.isAccessory(alert) ? .middle : .tail)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder private var mark: some View {
        if case .agentEvent(let provider, let title, _) = alert,
           let agent = AgentProvider.allCases.first(where: { $0.displayName == provider }),
           title == "Finished" {
            NotchAgentMark(provider: agent, size: 13, tint: agent.tint)
                .frame(width: LiveNoticeMetrics.symbolSlot)
        } else if case .upcomingEvent = alert {
            Circle()
                .fill(ArrowTheme.amber)
                .frame(width: 6, height: 6)
                .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5) }
                .frame(width: LiveNoticeMetrics.symbolSlot)
        } else {
            Image(systemName: LiveNoticeMetrics.noticeSymbol(alert))
                .font(.system(size: LiveNoticeMetrics.symbolSize, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: LiveNoticeMetrics.symbolSlot)
        }
    }

    private var isTimer: Bool {
        if case .timerFinished = alert { return true }
        return false
    }

    private var trailingTint: Color {
        if isTimer { return .orange.opacity(0.8) }
        if case .upcomingEvent(_, let startsAt, _, _) = alert,
           startsAt <= Date(), startsAt.addingTimeInterval(60 * 60) > Date() {
            return .mint
        }
        return .white.opacity(0.8)
    }

    private var accessibilityText: String {
        [title, detail]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// The app's icon in a system notification. Arrowslit receives the sender's
/// name; the icon is resolved when AppKit knows it.
private struct NotificationIcon: View {
    let app: String
    let size: CGFloat

    var body: some View {
        Group {
            if let image = Self.icon(for: app) {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: "bell.fill")
                    .font(.system(size: max(8, size - 3), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }

    private static func icon(for app: String) -> NSImage? {
        if let path = NSWorkspace.shared.fullPath(forApplication: app) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }
}

private struct TrackNoticeArtwork: View {
    @Bindable var state: AppState
    let size: CGFloat

    var body: some View {
        Group {
            if let artwork = state.nowPlaying.activeArtwork {
                Image(nsImage: artwork).resizable().interpolation(.high).scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
        }
    }
}

/// The notice meter: a quiet capsule that fills from the leading edge.
struct VSNoticeMeter: View {
    let value: Double
    let tint: Color
    var height: CGFloat = LiveNoticeMetrics.meterHeight

    var body: some View {
        let fraction = value.isFinite ? min(1, max(0, value)) : 0
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(.white.opacity(0.14))
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.9))
                    .frame(width: max(fraction > 0 ? height : 0,
                                      max(0, proxy.size.width) * fraction))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// The non-music, non-agent closed strips. Every one keeps the same two-wing
/// grammar: one mark and one short reading per side.
struct LiveActivityStrip: View {
    @Bindable var state: AppState
    let activity: NotchActivity?
    let width: CGFloat
    let height: CGFloat
    let notchWidth: CGFloat
    @ObservedObject private var agentUsage = AgentUsageService.shared

    private var ear: CGFloat { max(0, (width - notchWidth) / 2) }
    private var inset: CGFloat { LiveNoticeMetrics.stripInset }
    private var iconSize: CGFloat { LiveNoticeMetrics.stripIconSize(height: height) }
    private var textSize: CGFloat { LiveNoticeMetrics.stripTextSize(height: height) }
    /// A call's app mark and duration sit in the middle of each wing, like
    /// the media and agent strips, rather than on the outer ends.
    private var centersContent: Bool { activity == .call }

    var body: some View {
        HStack(spacing: 0) {
            leading
                .padding(.leading, centersContent ? 0 : inset)
                .frame(width: ear, height: height, alignment: centersContent ? .center : .leading)
                .clipped()
            Color.clear.frame(width: notchWidth)
            trailing
                .padding(.trailing, centersContent ? 0 : inset)
                .frame(width: ear, height: height, alignment: centersContent ? .center : .trailing)
                .clipped()
        }
        .frame(width: width, height: height)
        .foregroundStyle(.white)
    }

    @ViewBuilder private var leading: some View {
        switch activity {
        case .timer:
            Image(systemName: state.timer.isPaused ? "pause.circle"
                  : state.timer.justFinished ? "checkmark.circle" : "timer")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.orange)
        case .stopwatch:
            Image(systemName: "stopwatch")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.orange)
        case .calendar:
            HStack(spacing: 5) {
                Circle()
                    .fill(ArrowTheme.amber)
                    .frame(width: 6, height: 6)
                    .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5) }
                if let event = state.calendar.nextEvent {
                    Text(event.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .keepAwake:
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.yellow)
        case .download:
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: min(17, height - 10), weight: .regular))
                if let item = state.downloadProgress.items.first {
                    Text(item.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        case .watch:
            Image(systemName: "eye")
                .font(.system(size: iconSize, weight: .medium))
        case .call:
            if let icon = state.calls.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                Image(systemName: state.calls.session?.isCall == true ? "phone.fill" : "mic.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(state.calls.session?.isCall == true ? ArrowTheme.green : ArrowTheme.amber)
            }
        case .charging:
            Image(systemName: "battery.100percent.bolt")
                .font(.system(size: iconSize, weight: .medium))
        case .stats:
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.system(size: iconSize, weight: .medium))
                Text("CPU \(Int((state.stats.cpu * 100).rounded()))%")
                    .font(LiveNoticeMetrics.stripSmall)
                    .lineLimit(1)
            }
        case .sports:
            if let match = state.sports.notchMatch {
                HStack(spacing: 3) {
                    Circle().fill(match.isLive ? ArrowTheme.green : .white.opacity(0.4)).frame(width: 4.5, height: 4.5)
                    Text(match.home.shortName)
                        .font(LiveNoticeMetrics.stripTitle)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(match.homeScore.map(String.init) ?? "–")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        case .nowPlaying:
            // The music strip keeps its own view.
            EmptyView()
        case .agents:
            // The agent strip keeps its own view.
            EmptyView()
        case .none:
            SlitMark(height: 14)
        }
    }

    @ViewBuilder private var trailing: some View {
        switch activity {
        case .timer:
            Text(ClockFormat.clock(state.timer.remaining, roundingUp: true))
                .font(.system(size: textSize, weight: .medium).monospacedDigit())
                .foregroundStyle(.orange)
                .lineLimit(1)
        case .stopwatch:
            Text(ClockFormat.clock(state.stopwatch.elapsed, tenths: true))
                .font(.system(size: textSize, weight: .medium).monospacedDigit())
                .foregroundStyle(.orange)
                .lineLimit(1)
        case .calendar:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let event = state.calendar.nextEvent {
                    let ongoing = event.isHappening(at: context.date)
                    let target = ongoing ? event.end : event.start
                    HStack(spacing: 4) {
                        Text(Self.countdownText(until: target, now: context.date))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(ongoing ? .mint : .white)
                            .lineLimit(1)
                        Text(Self.eventTimeText(event, ongoing: ongoing))
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .keepAwake:
            // An open session runs until it is switched off, so it reads as
            // infinity; a timed one would show the time left.
            Image(systemName: "infinity")
                .font(.system(size: textSize, weight: .medium))
                .foregroundStyle(.yellow)
        case .download:
            if let fraction = state.downloadProgress.summary.fraction {
                HStack(spacing: 6) {
                    VSNoticeMeter(value: fraction, tint: .white, height: 4)
                        .padding(.leading, 4)
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: 30, alignment: .trailing)
                }
            } else {
                ProgressView().controlSize(.mini)
            }
        case .watch:
            Text("Watching")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        case .call:
            if let session = state.calls.session {
                HStack(spacing: 4) {
                    if state.microphone.isMuted {
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ArrowTheme.red)
                    }
                    Text(session.startDate, style: .timer)
                        .font(.system(size: 15, weight: .medium).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        case .charging:
            Text("\(state.system.batteryLevel)%")
                .font(.system(size: textSize, weight: .medium).monospacedDigit())
                .lineLimit(1)
        case .stats:
            Text("MEM \(Int((state.stats.memoryShare * 100).rounded()))%")
                .font(LiveNoticeMetrics.stripSmall)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        case .sports:
            if let match = state.sports.notchMatch {
                HStack(spacing: 3) {
                    Text(match.away.shortName)
                        .font(LiveNoticeMetrics.stripTitle)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(match.awayScore.map(String.init) ?? "–")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        case .nowPlaying:
            EmptyView()
        case .agents:
            EmptyView()
        case .none:
            Text(state.compactValue)
                .font(LiveNoticeMetrics.stripReading)
                .lineLimit(1)
        }
    }

    private static func countdownText(until target: Date, now: Date) -> String {
        let seconds = max(0, Int(ceil(target.timeIntervalSince(now))))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func eventTimeText(_ event: CalendarEvent, ongoing: Bool) -> String {
        let time = (ongoing ? event.end : event.start)
            .formatted(date: .omitted, time: .shortened)
        return (ongoing ? "→\u{2009}" : "·\u{2009}") + time
    }
}
