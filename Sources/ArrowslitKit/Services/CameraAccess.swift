import AppKit
import AVFoundation
import Observation

@MainActor
@Observable
public final class CameraAccess {
    public enum State: Equatable, Sendable {
        case notAsked
        case granted
        case denied
        case noCamera
    }

    public private(set) var state: State = CameraAccess.current()
    public var isCameraOff = false

    public init() {}

    public func refresh() {
        state = Self.current()
    }

    public func request() {
        NSApp.activate(ignoringOtherApps: true)
        Task { [weak self] in
            _ = await AVCaptureDevice.requestAccess(for: .video)
            self?.refresh()
        }
    }

    public func toggle() {
        isCameraOff.toggle()
    }

    public func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func current() -> State {
        guard AVCaptureDevice.default(for: .video) != nil else { return .noCamera }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }
}
