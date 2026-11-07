import AppKit
@preconcurrency import EventKit
import Foundation
import Observation

public struct ReminderItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let due: Date?
    public let completed: Bool
}

public struct ReminderCalendar: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
}

public enum RemindersAccess: Sendable, Equatable {
    case notAsked
    case denied
    case granted
}

@MainActor
@Observable
public final class RemindersService {
    public private(set) var access: RemindersAccess
    public private(set) var items: [ReminderItem] = []
    public private(set) var showCompleted = false
    public private(set) var excludedIDs: Set<String> = []

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var observer: NSObjectProtocol?

    public init() {
        access = Self.access(for: EKEventStore.authorizationStatus(for: .reminder))
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    public func calendars() -> [ReminderCalendar] {
        store.calendars(for: .reminder)
            .map { ReminderCalendar(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func configure(showCompleted: Bool, excludedIDs: [String]) {
        self.showCompleted = showCompleted
        self.excludedIDs = Set(excludedIDs)
        refresh()
    }

    public func requestAccess() {
        Task {
            do {
                let granted = try await store.requestFullAccessToReminders()
                access = granted ? .granted : .denied
                refresh()
            } catch {
                access = .denied
            }
        }
    }

    public func refresh() {
        guard access == .granted else {
            items = []
            return
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        let calendars = store.calendars(for: .reminder).filter { !excludedIDs.contains($0.calendarIdentifier) }
        let showingCompleted = showCompleted
        let predicate = showingCompleted
            ? store.predicateForReminders(in: calendars)
            : store.predicateForIncompleteReminders(withDueDateStarting: start, ending: end, calendars: calendars)
        Self.fetch(store: store, predicate: predicate) { [weak self] items in
            Task { @MainActor in
                self?.items = items.filter { item in
                    guard let due = item.due else { return showingCompleted && item.completed }
                    return due >= start && due < end
                }
            }
        }
    }

    /// EventKit calls its completion on a private queue. Keeping this helper
    /// nonisolated prevents the closure from inheriting the main actor, which
    /// would trip Swift's executor check on that queue.
    nonisolated private static func fetch(
        store: EKEventStore,
        predicate: NSPredicate,
        completion: @escaping @Sendable ([ReminderItem]) -> Void
    ) {
        store.fetchReminders(matching: predicate) { reminders in
            let mapped = (reminders ?? []).compactMap { reminder -> ReminderItem? in
                guard let title = reminder.title, !title.isEmpty else { return nil }
                return ReminderItem(
                    id: reminder.calendarItemIdentifier,
                    title: title,
                    due: reminder.dueDateComponents?.date,
                    completed: reminder.isCompleted
                )
            }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
            completion(mapped)
        }
    }

    public func complete(_ item: ReminderItem) {
        guard let reminder = store.calendarItem(withIdentifier: item.id) as? EKReminder else { return }
        reminder.isCompleted = true
        try? store.save(reminder, commit: true)
        items.removeAll { $0.id == item.id }
    }

    public func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func access(for status: EKAuthorizationStatus) -> RemindersAccess {
        switch status {
        case .fullAccess, .authorized:
            .granted
        case .denied, .restricted, .writeOnly:
            .denied
        case .notDetermined:
            .notAsked
        @unknown default:
            .notAsked
        }
    }
}
