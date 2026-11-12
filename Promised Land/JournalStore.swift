import Foundation
import SwiftData

/// Journal filing only. Reading history and completion belong to the reading flow.
@MainActor
enum JournalStore {
    private static let defaultShelfLabel = "My journals"


    enum SaveError: Error, Equatable {
        case emptyText
        case invalidDestination
    }

    /// Saves only a note. Failure discards this insert so retrying cannot duplicate it;
    /// unrelated pending changes in the caller's context are never rolled back.
    @discardableResult
    static func save(in context: ModelContext, notebook: JournalNotebook, text: String,
                     bookID: String? = nil, chapter: Int? = nil, verseStart: Int? = nil,
                     verseEnd: Int? = nil, prompt: String? = nil) throws -> JournalEntry {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SaveError.emptyText }
        guard notebook.modelContext === context else { throw SaveError.invalidDestination }
        let entry = JournalEntry(bookID: bookID, chapter: chapter, prompt: prompt, text: trimmed)
        entry.verseStart = verseStart
        entry.verseEnd = verseEnd
        context.insert(entry)
        entry.notebook = notebook
        do {
            try context.save()
            return entry
        } catch {
            entry.notebook = nil
            context.delete(entry)
            throw error
        }
    }

    /// Run before presenting the app. Only unfiled entries are changed.
    static func backfill(in context: ModelContext) throws {
        let unfiled = try context.fetch(FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.notebook == nil }))
        let shelves = try context.fetch(FetchDescriptor<JournalShelf>())
        guard !unfiled.isEmpty || shelves.isEmpty else { return }

        let shelf = try defaultShelf(in: context)
        var notebooks: [String: JournalNotebook] = [:]
        for notebook in shelf.notebooks where notebooks[notebook.name] == nil {
            notebooks[notebook.name] = notebook
        }
        for entry in unfiled {
            let name = notebookName(bookID: entry.bookID)
            let notebook: JournalNotebook
            if let existing = notebooks[name] {
                notebook = existing
            } else {
                notebook = JournalNotebook(name: name, shelf: shelf)
                context.insert(notebook)
                notebooks[name] = notebook
            }
            entry.notebook = notebook
        }
        try context.save()
    }

    /// The destination order used by every note-save picker.
    static func preferredNotebook(in context: ModelContext, bookID: String?) throws -> JournalNotebook {
        let shelves = try context.fetch(FetchDescriptor<JournalShelf>(sortBy: [SortDescriptor(\.created)]))
        let notebooks = shelves.flatMap(\.notebooks)
        if let bookName = bookID.flatMap({ BibleCatalog.book(id: $0)?.name }),
           let bookNotebook = notebooks.first(where: { $0.name == bookName }) {
            return bookNotebook
        }
        if let recent = notebooks.max(by: { mostRecentDate($0) < mostRecentDate($1) }),
           mostRecentDate(recent) > .distantPast {
            return recent
        }
        let shelf = shelves.first ?? JournalShelf(label: defaultShelfLabel)
        if shelf.modelContext == nil { context.insert(shelf) }
        if let notes = shelf.notebooks.first(where: { $0.name == "My notes" }) { return notes }
        let notes = JournalNotebook(name: "My notes", shelf: shelf)
        context.insert(notes)
        return notes
    }

    /// Kept for callers that intentionally want the book/free default destination.
    static func defaultNotebook(in context: ModelContext, bookID: String?) throws -> JournalNotebook {
        let shelf = try defaultShelf(in: context)
        let name = notebookName(bookID: bookID)
        if let existing = shelf.notebooks.first(where: { $0.name == name }) { return existing }
        let notebook = JournalNotebook(name: name, shelf: shelf)
        context.insert(notebook)
        return notebook
    }

    static func mostRecentDate(_ notebook: JournalNotebook) -> Date {
        notebook.entries.map { max($0.updated, $0.created) }.max() ?? .distantPast
    }

    @discardableResult
    static func deleteEmptyShelf(in context: ModelContext, shelf: JournalShelf) throws -> Bool {
        let shelves = try context.fetch(FetchDescriptor<JournalShelf>())
        guard shelves.count > 1, shelf.notebooks.isEmpty else { return false }
        context.delete(shelf)
        try context.save()
        return true
    }

    @discardableResult
    static func moveJournalsAndDeleteShelf(in context: ModelContext, shelf: JournalShelf,
                                           to target: JournalShelf) throws -> Bool {
        let shelves = try context.fetch(FetchDescriptor<JournalShelf>())
        guard shelves.count > 1, shelf.id != target.id else { return false }
        shelf.notebooks.forEach { $0.shelf = target }
        context.delete(shelf)
        try context.save()
        return true
    }

    private static func defaultShelf(in context: ModelContext) throws -> JournalShelf {
        let label = defaultShelfLabel
        var request = FetchDescriptor<JournalShelf>(predicate: #Predicate { $0.label == label },
                                                    sortBy: [SortDescriptor(\.created)])
        request.fetchLimit = 1
        if let existing = try context.fetch(request).first { return existing }
        let shelf = JournalShelf(label: label)
        context.insert(shelf)
        return shelf
    }

    private static func notebookName(bookID: String?) -> String {
        guard let bookID else { return "My notes" }
        // Keep even an unrecognised legacy book ID filed without changing its reference.
        return BibleCatalog.book(id: bookID)?.name ?? bookID
    }
}
