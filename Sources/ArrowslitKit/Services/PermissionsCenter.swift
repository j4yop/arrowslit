import AppKit
import AVFoundation
import CoreGraphics
import EventKit
import Foundation
import Observation
import UserNotifications

public enum PermissionKind: String, CaseIterable, Identifiable, Sendable {
    case automation
    case screenRecording
    case accessibility
    case inputMonitoring
    case calendars
    case reminders
    case camera
    case microphone
    case notifications

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automation: "Automation"
        case .screenRecording: "Screen Recording"
        case .accessibility: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        case .calendars: "Calendars"
        case .reminders: "Reminders"
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .notifications: "Notifications"
        }
    }

    public var detail: String {
        switch self {
        case .automation: "Switch macOS light and dark."
        case .screenRecording: "Capture areas, windows and text."
        case .accessibility: "Volume, brightness and paste."
        case .inputMonitoring: "Global launcher shortcut."
        case .calendars: "Next event in the notch."
        case .reminders: "Today's reminders in the notch."
        case .camera: "Local preview before a call."
        case .microphone: "Call and microphone indicator."
        case .notifications: "Timer and agent alerts."
        }
    }

    public var symbol: String {
        switch self {
        case .automation: "gearshape.2.fill"
        case .screenRecording: "camera.viewfinder"
        case .accessibility: "hand.raised.fill"
        case .inputMonitoring: "keyboard.badge.ellipsis"
        case .calendars: "calendar"
        case .reminders: "checklist"
        case .camera: "camera.fill"
        case .microphone: "mic.fill"
        case .notifications: "bell.fill"
        }
    }

    public var settingsPane: String? {
        switch self {
        case .automation: "Privacy_Automation"
        case .screenRecording: "Privacy_ScreenCapture"
        case .accessibility: "Privacy_Accessibility"
        case .inputMonitoring: "Privacy_ListenEvent"
        case .calendars: "Privacy_Calendars"
        case .reminders: "Privacy_Reminders"
        case .camera: "Privacy_Camera"
        case .microphone: "Privacy_Microphone"
        case .notifications: nil
        }
    }

    public var settingsURL: URL? {
        if self == .notifications {
            return URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
        }
        return settingsPane.flatMap {
            URL(string: "x-apple.systempreferences:com.apple.preference.security?\($0)")
        }
    }
}

public enum PermissionStatus: String, Sendable {
    case granted
    case denied
    case restricted
    case limited
    case notDetermined
    case unknown

    public var isGranted: Bool { self == .granted }
}

@MainActor
@Observable
public final class PermissionsCenter {
    public private(set) var statuses: [PermissionKind: PermissionStatus] = [:]
    public private(set) var isRequesting = false
    public private(set) var automationMessage: String?

    @ObservationIgnored private let eventStore = EKEventStore()

    public init() {}

    public func status(for kind: PermissionKind) -> PermissionStatus {
        statuses[kind] ?? .unknown
    }

    public func refresh() async {
        statuses[.screenRecording] = CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
        statuses[.accessibility] = AXIsProcessTrusted() ? .granted : .notDetermined
        statuses[.inputMonitoring] = CGPreflightListenEventAccess() ? .granted : .notDetermined
        statuses[.calendars] = Self.status(for: EKEventStore.authorizationStatus(for: .event))
        statuses[.reminders] = Self.status(for: EKEventStore.authorizationStatus(for: .reminder))
        statuses[.camera] = Self.status(for: AVCaptureDevice.authorizationStatus(for: .video))
        statuses[.microphone] = Self.status(for: AVCaptureDevice.authorizationStatus(for: .audio))
        statuses[.automation] = Self.automationStatus()

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        statuses[.notifications] = Self.status(for: settings.authorizationStatus)
    }

    public func request(_ kind: PermissionKind) async {
        switch kind {
        case .automation:
            requestAutomation()
        case .screenRecording:
            if !CGPreflightScreenCaptureAccess() {
                _ = CGRequestScreenCaptureAccess()
            }
            statuses[.screenRecording] = CGPreflightScreenCaptureAccess() ? .granted : .denied
        case .accessibility:
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            statuses[.accessibility] = AXIsProcessTrusted() ? .granted : .notDetermined
        case .inputMonitoring:
            if !CGPreflightListenEventAccess() {
                _ = CGRequestListenEventAccess()
            }
            statuses[.inputMonitoring] = CGPreflightListenEventAccess() ? .granted : .denied
        case .calendars:
            _ = try? await eventStore.requestFullAccessToEvents()
        case .reminders:
            _ = try? await eventStore.requestFullAccessToReminders()
        case .camera:
            _ = await AVCaptureDevice.requestAccess(for: .video)
        case .microphone:
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        case .notifications:
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
        await refresh()
    }

    public func requestAll() async {
        guard !isRequesting else { return }
        isRequesting = true
        for kind in PermissionKind.allCases {
            if Task.isCancelled { break }
            if status(for: kind).isGranted { continue }
            await request(kind)
            try? await Task.sleep(for: .milliseconds(450))
        }
        isRequesting = false
    }

    public func openSettings(for kind: PermissionKind) {
        guard let url = kind.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func requestAutomation() {
        automationMessage = nil
        let script = "tell application \"System Events\" to get name of first process"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error {
            automationMessage = (error[NSAppleScript.errorMessage] as? String)
                ?? "Allow Arrowslit to control System Events in System Settings."
            statuses[.automation] = .denied
        } else {
            statuses[.automation] = .granted
        }
    }

    private static func automationStatus() -> PermissionStatus {
        var address = AEAddressDesc()
        let data = "com.apple.systemevents".data(using: .utf8)!
        let created = data.withUnsafeBytes { buffer in
            AECreateDesc(DescType(typeApplicationBundleID), buffer.baseAddress, buffer.count, &address)
        }
        guard created == noErr else { return .unknown }
        defer { AEDisposeDesc(&address) }
        let result = AEDeterminePermissionToAutomateTarget(&address, typeWildCard, typeWildCard, false)
        switch result {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(errAEEventWouldRequireUserConsent): return .notDetermined
        default: return .notDetermined
        }
    }

    private static func status(for value: AVAuthorizationStatus) -> PermissionStatus {
        switch value {
        case .authorized: .granted
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .unknown
        }
    }

    private static func status(for value: EKAuthorizationStatus) -> PermissionStatus {
        switch value {
        case .fullAccess, .authorized: .granted
        case .writeOnly: .limited
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .unknown
        }
    }

    private static func status(for value: UNAuthorizationStatus) -> PermissionStatus {
        switch value {
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .unknown
        }
    }
}
