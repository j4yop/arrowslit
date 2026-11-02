import AppKit
import Foundation
import Testing
@testable import ArrowslitKit

@Suite("To-do store")
@MainActor
struct TodoStoreTests {
    @Test func addsOrdersTogglesAndPersists() {
        let suite = "ArrowslitTodoTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = TodoStore(defaults: defaults)
        store.add("First")
        store.add("Second")
        #expect(store.ordered.map(\.title) == ["Second", "First"])
        let first = store.ordered.first { $0.title == "First" }!
        store.toggle(first.id)
        #expect(store.ordered.map(\.title) == ["Second", "First"])
        #expect(store.ordered.last?.isDone == true)

        let reloaded = TodoStore(defaults: defaults)
        #expect(reloaded.ordered.map(\.title) == ["Second", "First"])
        reloaded.remove(first.id)
        #expect(reloaded.items.count == 1)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func ignoresEmptyTasksAndCapsTheList() {
        let suite = "ArrowslitTodoTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = TodoStore(defaults: defaults)
        store.add("   ")
        #expect(store.items.isEmpty)
        for index in 0..<(TodoStore.capacity + 4) {
            store.add("Task \(index)")
        }
        #expect(store.items.count == TodoStore.capacity)
        defaults.removePersistentDomain(forName: suite)
    }
}

@Suite("Rich notes")
@MainActor
struct RichNotesTests {
    @Test func keepsPlainTextAndFormattingAcrossReload() {
        let suite = "ArrowslitNotesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = NotesStore(defaults: defaults)
        let note = NSMutableAttributedString(string: "Hello notes")
        note.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 13), range: NSRange(location: 0, length: 5))
        store.update(note)
        #expect(store.text == "Hello notes")
        #expect(!store.isSaved)
        store.save()
        #expect(store.isSaved)

        let reloaded = NotesStore(defaults: defaults)
        #expect(reloaded.text == "Hello notes")
        #expect(reloaded.attributedText.string == "Hello notes")
        reloaded.clear()
        #expect(reloaded.text.isEmpty)
        defaults.removePersistentDomain(forName: suite)
    }
}

@Suite("Favorite shortcuts")
@MainActor
struct FavoriteShortcutsTests {
    @Test func capsAtFourAndTogglesOff() {
        let suite = "ArrowslitShortcutTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults)
        for index in 0..<SettingsStore.maximumFavoriteShortcuts {
            let added = store.toggleFavorite("Shortcut \(index)")
            #expect(added)
        }
        let overflow = store.toggleFavorite("Too many")
        #expect(!overflow)
        let removed = store.toggleFavorite("Shortcut 0")
        #expect(removed)
        #expect(store.favoriteShortcuts.count == 3)
        defaults.removePersistentDomain(forName: suite)
    }
}
