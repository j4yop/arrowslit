import AppKit
@preconcurrency import EventKit
import Observation

public struct CalendarEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let joinURL: URL?
    public let joinProvider: MeetingLinks.Provider?

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        joinURL: URL? = nil,
        joinProvider: MeetingLinks.Provider? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.joinURL = joinURL
        self.joinProvider = joinProvider
    }

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
    public private(set) var events: [CalendarEvent] = []
    public private(set) var isRunning = false

    /// Called five minutes before an event starts, once per event per launch.
    @ObservationIgnored public var onReminder: ((CalendarEvent) -> Void)?

    @ObservationIgnored private var store = EKEventStore()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var reminderTask: Task<Void, Never>?
    @ObservationIgnored private var reminded = Set<String>()

    public init() {
        access = Self.access(for: EKEventStore.authorizationStatus(for: .event))
    }

    public var nextEvent: CalendarEvent? {
        CalendarRules.nextEvent(in: events, at: Date())
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
        reminderTask?.cancel()
        reminderTask = nil
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

    public func join(_ event: CalendarEvent) {
        guard let url = event.joinURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func reload() {
        access = Self.access(for: EKEventStore.authorizationStatus(for: .event))
        guard access == .granted else {
            events = []
            scheduleReminder()
            return
        }

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let fresh = store.events(matching: predicate)
            .filter { $0.status != .canceled && !Self.isDeclined($0) && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                let join = MeetingLinks.joinLink(in: [
                    event.url?.absoluteString,
                    event.location,
                    event.notes,
                ])
                return CalendarEvent(
                    id: event.calendarItemIdentifier + "@" + String(event.startDate.timeIntervalSince1970),
                    title: event.title?.isEmpty == false ? event.title! : "Event",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    joinURL: join?.url,
                    joinProvider: join?.provider
                )
            }
        if fresh != events { events = fresh }
        scheduleReminder()
    }

    private func scheduleReminder() {
        reminderTask?.cancel()
        reminderTask = nil
        guard isRunning,
              let next = CalendarRules.nextReminder(in: events, after: Date(), reminded: reminded) else {
            return
        }
        let delay = max(0, next.at.timeIntervalSinceNow)
        reminderTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay), tolerance: .seconds(1))
            guard !Task.isCancelled, let self else { return }
            self.reminded.insert(next.event.id)
            self.onReminder?(next.event)
            self.scheduleReminder()
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
