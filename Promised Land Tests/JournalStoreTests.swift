import Foundation
import SwiftData
import Testing
@testable import Promised_Land

@MainActor
@Suite(.serialized)
struct JournalStoreTests {
    func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: Schema(AppSchema.models), configurations:
            ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    struct EntryFields: Equatable {
        let id: UUID
        let created: Date
        let updated: Date
        let bookID: String?
        let chapter: Int?
        let prompt: String?
        let text: String
        let verseStart: Int?
        let verseEnd: Int?

        init(_ entry: JournalEntry) {
            id = entry.id
            created = entry.created
            updated = entry.updated
            bookID = entry.bookID
            chapter = entry.chapter
            prompt = entry.prompt
            text = entry.text
            verseStart = entry.verseStart
            verseEnd = entry.verseEnd
        }
    }

    @Test("Backfill files each entry once, reuses book journals, and preserves all old fields and photos")
    func backfillPreservesAndReuses() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let shelf = JournalShelf(label: "My journals")
        context.insert(shelf)
        let ruth = JournalNotebook(name: "Ruth", shelf: shelf)
        context.insert(ruth)
        let otherShelf = JournalShelf(label: "Personal")
        context.insert(otherShelf)
        let personal = JournalNotebook(name: "Ruth", shelf: otherShelf)
        context.insert(personal)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = [
            JournalEntry(bookID: "ruth", chapter: 1, prompt: "Prompt", text: "  Unchanged\ntext ", date: date),
            JournalEntry(bookID: "ruth", text: "Whole book", date: date),
            JournalEntry(bookID: "john", chapter: 3, text: "John", date: date),
            JournalEntry(text: "Free", date: date),
            JournalEntry(bookID: "ruth", text: "Already filed", date: date)
        ]
        for entry in entries {
            entry.updated = date.addingTimeInterval(25)
            context.insert(entry)
        }
        entries[2].verseStart = 16
        entries[2].verseEnd = 18
        entries[4].notebook = personal
        let photo = ReadingPhoto(bookID: "ruth", chapter: 1, imageData: Data([3, 4]),
                                 journalEntryID: entries[0].id, date: date)
        let photoID = photo.uid
        context.insert(photo)
        try context.save()
        // Snapshot the persisted fixture; backfill must preserve exactly what the store contains.
        let before = entries.map(EntryFields.init)

        try JournalStore.backfill(in: context)
        #expect(entries.map(EntryFields.init) == before)
        #expect(entries[0].notebook?.id == ruth.id)
        #expect(entries[1].notebook?.id == ruth.id)
        #expect(entries[2].notebook?.name == "John")
        #expect(entries[3].notebook?.name == "My notes")
        #expect(entries[4].notebook?.id == personal.id)
        for entry in entries.prefix(4) { #expect(entry.notebook?.shelf?.id == shelf.id) }
        let notebooks = try context.fetch(FetchDescriptor<JournalNotebook>())
        #expect(notebooks.count == 4)
        for entry in entries {
            #expect(notebooks.flatMap(\.entries).filter { $0.id == entry.id }.count == 1)
        }
        let membership = entries.map { $0.notebook?.id }
        let notebookIDs = Set(notebooks.map(\.id))
        let shelfIDs = Set(try context.fetch(FetchDescriptor<JournalShelf>()).map(\.id))
        try JournalStore.backfill(in: context)
        #expect(!context.hasChanges)
        #expect(entries.map(EntryFields.init) == before)
        #expect(entries.map { $0.notebook?.id } == membership)
        #expect(Set(try context.fetch(FetchDescriptor<JournalNotebook>()).map(\.id)) == notebookIDs)
        #expect(Set(try context.fetch(FetchDescriptor<JournalShelf>()).map(\.id)) == shelfIDs)
        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == entries.count)
        #expect(try context.fetchCount(FetchDescriptor<ReadingPhoto>()) == 1)
        #expect(photo.uid == photoID)
        #expect(photo.journalEntryID == entries[0].id)
        #expect(photo.bookID == "ruth")
        #expect(photo.chapter == 1)
        #expect(photo.date == date)
        #expect(photo.imageData == Data([3, 4]))
        #expect(try context.fetchCount(FetchDescriptor<ChapterRead>()) == 0)
    }

    @Test("A fresh store gets one empty default shelf, unchanged on the next launch")
    func freshDefaultShelf() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try JournalStore.backfill(in: context)
        let shelves = try context.fetch(FetchDescriptor<JournalShelf>())
        #expect(shelves.count == 1)
        let shelf = try #require(shelves.first)
        #expect(shelf.label == "My journals")
        #expect(shelf.notebooks.isEmpty)
        try JournalStore.backfill(in: context)
        #expect(!context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<JournalShelf>()).map(\.id) == [shelf.id])
        #expect(try context.fetchCount(FetchDescriptor<JournalNotebook>()) == 0)
    }

    @Test("Backfill creates the default shelf and never loses an unrecognised book reference")
    func backfillWithoutShelf() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let entry = JournalEntry(bookID: "legacy-book", text: "Kept")
        context.insert(entry)
        try JournalStore.backfill(in: context)
        #expect(entry.bookID == "legacy-book")
        #expect(entry.notebook?.name == "legacy-book")
        #expect(entry.notebook?.shelf?.label == "My journals")
    }

    @Test("Deleting shelves, notebooks, and entries nullifies links without cascading")
    func deletesOnlyNullify() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = JournalEntry(bookID: "john", chapter: 3, text: "Keep me")
        context.insert(first)
        try JournalStore.backfill(in: context)
        let notebook = try #require(first.notebook)
        let shelf = try #require(notebook.shelf)
        let fields = EntryFields(first)
        context.delete(shelf)
        try context.save()
        #expect(notebook.shelf == nil)
        #expect(first.notebook?.id == notebook.id)
        #expect(try context.fetchCount(FetchDescriptor<JournalNotebook>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == 1)
        #expect(EntryFields(first) == fields)
        context.delete(notebook)
        try context.save()
        #expect(first.notebook == nil)
        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == 1)
        #expect(EntryFields(first) == fields)

        try JournalStore.backfill(in: context)
        let replacement = try #require(first.notebook)
        let replacementShelf = try #require(replacement.shelf)
        context.delete(first)
        try context.save()
        #expect(replacement.entries.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<JournalNotebook>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<JournalShelf>()) == 1)
        context.delete(replacement)
        try context.save()
        #expect(replacementShelf.notebooks.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<JournalShelf>()) == 1)
    }
}

extension JournalStoreTests {
    @Test("Saving rejects whitespace without inserting an entry")
    func saveRejectsEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let notebook = try JournalStore.defaultNotebook(in: context, bookID: nil)
        try context.save()
        #expect(throws: JournalStore.SaveError.emptyText) {
            try JournalStore.save(in: context, notebook: notebook, text: " \n\t ")
        }
        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == 0)
        #expect(notebook.entries.isEmpty)
        #expect(!context.hasChanges)
    }

    @Test("Saving uses the chosen notebook, trims text, stores scripture and never records reading")
    func saveStoresNoteOnly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let shelf = JournalShelf(label: "Personal")
        context.insert(shelf)
        let notebook = JournalNotebook(name: "Hope", shelf: shelf)
        context.insert(notebook)
        let entry = try JournalStore.save(in: context, notebook: notebook, text: " \nA note\nwith lines  ",
                                          bookID: "john", chapter: 3, verseStart: 16, verseEnd: 18, prompt: "Reflect")
        #expect(entry.notebook?.id == notebook.id)
        #expect(notebook.entries.map(\.id) == [entry.id])
        #expect(entry.text == "A note\nwith lines")
        #expect(entry.bookID == "john")
        #expect(entry.chapter == 3)
        #expect(entry.verseStart == 16)
        #expect(entry.verseEnd == 18)
        #expect(entry.prompt == "Reflect")
        #expect(entry.reference == "John 3:16–18")
        #expect(try context.fetchCount(FetchDescriptor<ChapterRead>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<BookStarted>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<QuizPass>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<VerseMemorised>()) == 0)
        #expect(!context.hasChanges)
        // A separate context verifies persistence rather than just the live object graph.
        let reader = ModelContext(container)
        let saved = try #require(reader.fetch(FetchDescriptor<JournalEntry>()).first)
        #expect(saved.notebook?.id == notebook.id)
        #expect(saved.verseStart == 16)
        #expect(saved.verseEnd == 18)
        #expect(saved.text == entry.text)
    }

    @Test("References retain whole-book and chapter forms and support single verses and ranges")
    func verseReferences() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let notebook = try JournalStore.defaultNotebook(in: context, bookID: "john")
        let free = try JournalStore.save(in: context, notebook: notebook, text: "Free")
        let book = try JournalStore.save(in: context, notebook: notebook, text: "Book", bookID: "john")
        let chapter = try JournalStore.save(in: context, notebook: notebook, text: "Chapter", bookID: "john", chapter: 3)
        let verse = try JournalStore.save(in: context, notebook: notebook, text: "Verse", bookID: "john", chapter: 3, verseStart: 16)
        let same = try JournalStore.save(in: context, notebook: notebook, text: "Same", bookID: "john", chapter: 3, verseStart: 16, verseEnd: 16)
        #expect(free.reference == nil)
        #expect(free.bookID == nil && free.chapter == nil && free.prompt == nil)
        #expect(free.verseStart == nil && free.verseEnd == nil)
        #expect(book.reference == "John")
        #expect(chapter.reference == "John 3")
        #expect(verse.reference == "John 3:16")
        #expect(same.reference == "John 3:16")
    }

    @Test("Default destinations reuse backfilled journals and file new book and free notes")
    func defaultDestinations() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let old = JournalEntry(bookID: "ruth", text: "Old")
        context.insert(old)
        try JournalStore.backfill(in: context)
        let ruth = try JournalStore.defaultNotebook(in: context, bookID: "ruth")
        #expect(ruth.id == old.notebook?.id)
        let free = try JournalStore.defaultNotebook(in: context, bookID: nil)
        let repeatedFree = try JournalStore.defaultNotebook(in: context, bookID: nil)
        #expect(free.id == repeatedFree.id)
        let note = try JournalStore.save(in: context, notebook: free, text: "New")
        #expect(note.notebook?.name == "My notes")
        #expect(free.shelf?.id == ruth.shelf?.id)
        #expect(try context.fetchCount(FetchDescriptor<JournalShelf>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<JournalNotebook>()) == 2)
    }

    @Test("A destination from another context is rejected without changing either store")
    func saveRejectsForeignNotebook() throws {
        let first = try makeContainer()
        let second = try makeContainer()
        let notebook = try JournalStore.defaultNotebook(in: first.mainContext, bookID: nil)
        try first.mainContext.save()
        #expect(throws: JournalStore.SaveError.invalidDestination) {
            try JournalStore.save(in: second.mainContext, notebook: notebook, text: "Keep stores separate")
        }
        #expect(try first.mainContext.fetchCount(FetchDescriptor<JournalEntry>()) == 0)
        #expect(try second.mainContext.fetchCount(FetchDescriptor<JournalEntry>()) == 0)
    }
}
