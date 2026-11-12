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
            context.insert(entry)
            entry.updated = date.addingTimeInterval(25)
        }
        entries[2].verseStart = 16
        entries[2].verseEnd = 18
        entries[4].notebook = personal
        let before = entries.map(EntryFields.init)
        let photo = ReadingPhoto(bookID: "ruth", chapter: 1, imageData: Data([3, 4]),
                                 journalEntryID: entries[0].id, date: date)
        let photoID = photo.uid
        context.insert(photo)
        try context.save()

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
