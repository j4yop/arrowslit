// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
//
// Compatibility layer for the Vorssaint per-app audio mixer. Arrowslit does
// not ship Vorssaint's private AirPlay routing stack yet, so this file keeps
// the mixer's per-app Core Audio path intact while making AirPlay unavailable.

import AppKit
import CoreAudio
import Foundation

enum AppFeature {
    case mixer
    case audioPriority
    case soundOutputSwitcher
    case notchNotifications

    var isAvailable: Bool { true }
}

extension DefaultsKey {
    static let appVolumes = "arrowslit.mixer.appVolumes"
    static let appOutputDevices = "arrowslit.mixer.appOutputDevices"
    static let mixerCallAppVolumeEnabled = "arrowslit.mixer.callApps"
    static let mixerHiddenApps = "arrowslit.mixer.hiddenApps"
    static let mixerShowFinder = "arrowslit.mixer.showFinder"
    static let mixerLowerVolumeOnHeadphonesDisconnect = "arrowslit.mixer.lowerOnHeadphoneDisconnect"
    static let mixerHeadphonesDisconnectVolumePercent = "arrowslit.mixer.headphoneDisconnectPercent"
    static let notchNotificationsEnabled = "arrowslit.notifications.mirror"
    static let notchDismissNativeNotifications = "arrowslit.notifications.hideNative"
}

/// A deliberately inert AirPlay facade. The per-app mixer still works through
/// its aggregate-device path; only the AirPlay sentinel is absent until the
/// private AVOutputContext port lands.
enum AirPlayRouteManager {
    static let airPlaySentinelUID = "arrowslit.airplay-sentinel"
    static let isListed = false
    static let isSpeakerConnected = false
    static let currentSpeakerName: String? = nil
    static let shared = Shared()

    final class Shared: @unchecked Sendable {
        var isConnected = false
        func activate(_ completion: @escaping () -> Void) { completion() }
        func deactivate() {}
        func presentPicker() {}
        func prepareToStream() -> Bool { false }
        func stopIfIdle() {}
        func reportStreamingFailure() {}
        func routedAudioChanged(active: Bool) {}
        func addAudioStream(appID: String, buffer: AudioRingBuffer) -> AirPlayStreamRegistration? { nil }
    }
}

final class AirPlayStreamRegistration: @unchecked Sendable {
    func end() {}
}

enum Defaults {
    nonisolated(unsafe) static let standard = UserDefaults.standard

    static func sanitizedAppVolume(_ volume: Double) -> Double {
        guard volume.isFinite else { return 1 }
        return min(max(volume, 0), 2)
    }

    static func sanitizedMixerHeadphonesDisconnectVolumePercent(_ percent: Int) -> Int {
        min(max(percent, 0), 100)
    }

    static func sanitizedAppOutputDeviceUID(_ value: Any?) -> String? {
        MixerRoutingSupport.sanitizedDeviceUID(value)
    }

    static func sanitizedAppOutputDevices(_ raw: [String: Any]) -> [String: String] {
        MixerRoutingSupport.sanitizedRouteMap(raw)
    }
}

enum MicMuteSupport {
    static func isOwnDevice(name: String) -> Bool {
        ["Arrowslit Mixer", "Arrowslit AirPlay", "Arrowslit Island Levels", "Arrowslit Recorder"].contains(name)
    }
}

enum ImageThumbnailer {
    static let defaultPointSize: CGFloat = 32

    static func estimatedBitmapCost(pointSize: CGFloat) -> Int {
        Int(pointSize * pointSize * 4)
    }

    static func thumbnail(for image: NSImage, pointSize: CGFloat) -> NSImage? {
        image
    }

    static func thumbnail(for url: URL, pointSize: CGFloat) -> NSImage? {
        NSImage(contentsOf: url)
    }
}
