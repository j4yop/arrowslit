import AppKit
import CoreGraphics
import Foundation
import Observation

/// Tracks whether the login session is locked or the screen saver is up. The panel uses this
/// to hide while locked, or to raise itself above the lock screen when the user opts in.
@MainActor
@Observable
public final class SessionLockService {
    public private(set) var isLocked = false

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    #if DEBUG
    @ObservationIgnored private var isSimulated = false
    #endif

    public init() {}

    public func start() {
        guard observers.isEmpty else { return }
        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setLocked(true) }
        })
        observers.append(center.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setLocked(false) }
        })
        observers.append(center.addObserver(
            forName: Notification.Name("com.apple.screensaver.didstart"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setLocked(true) }
        })
        observers.append(center.addObserver(
            forName: Notification.Name("com.apple.screensaver.didstop"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setLocked(false) }
        })

        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setLocked(true) }
        })
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setLocked(false) }
        })

        refresh()
    }

    public func stop() {
        let center = DistributedNotificationCenter.default()
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { workspace.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    public func refresh() {
        let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any]
        let locked: Bool
        if let value = dictionary?["CGSSessionScreenIsLocked"] as? Bool {
            locked = value
        } else if let value = dictionary?["CGSSessionScreenIsLocked"] as? Int {
            locked = value != 0
        } else {
            locked = false
        }
        setLocked(locked)
    }

    private func setLocked(_ locked: Bool) {
        #if DEBUG
        guard !isSimulated else { return }
        #endif
        guard isLocked != locked else { return }
        isLocked = locked
    }

    #if DEBUG
    public func simulateLocked(_ locked: Bool) {
        isSimulated = true
        guard isLocked != locked else { return }
        isLocked = locked
    }

    public func endSimulation() {
        isSimulated = false
        refresh()
    }
    #endif
}
