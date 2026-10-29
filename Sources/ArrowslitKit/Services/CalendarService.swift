import AppKit
import EventKit
import Observation

public struct CalendarEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool

    public func isHappening(at date: Date) -> Bool {
        start <= date && date < end
    }
}

@MainActor
@Observable
public final class CalendarService {
    public enum Access: Equatable, Sendable {
        case notAsked
        case granted
        case denied
        case limited
    }

    public private(set) var access: Access = .notAsked
    public private(set) var nextEvent: CalendarEvent?
    public private(set) var isRunning = false

    @ObservationIgnored private var store = EKEventStore()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var refreshTimer: Timer?

    public init() {
        access = Self.access(for: EKEventStore.authorizationStatus(for: .event))
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        access = Self.access(for: EKEventStore.authorizationStatus(for: .event))
        observers.append(NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        })
        reload()
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    public func stop() {
        isRunning = false
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    public func requestAccess() {
        NSApp.activate(ignoringOtherApps: true)
        Task { [weak self] in
            guard let self else { return }
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            if granted {
                store = EKEventStore()
            }
            access = Self.access(for: EKEventStore.authorizationStatus(for: .event))
            reload()
        }
    }

    public func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }

    public func open(_ event: CalendarEvent) {
        guard let url = URL(string: "calshow:\(event.start.timeIntervalSinceReferenceDate)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func reload() {
        access = Self.access(for: EKEventStore.authorizationStatus(for: .event))
        guard access == .granted else {
            nextEvent = nil
            return
        }
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { $0.status != .canceled && !Self.isDeclined($0) && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
        let event = events.first { !$0.isAllDay } ?? events.first
        nextEvent = event.map {
            CalendarEvent(
                id: $0.calendarItemIdentifier,
                title: $0.title?.isEmpty == false ? $0.title! : "Event",
                start: $0.startDate,
                end: $0.endDate,
                isAllDay: $0.isAllDay
            )
        }
    }

    nonisolated private static func access(for status: EKAuthorizationStatus) -> Access {
        switch status {
        case .fullAccess: .granted
        case .writeOnly: .limited
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    nonisolated private static func isDeclined(_ event: EKEvent) -> Bool {
        event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
    }
}
