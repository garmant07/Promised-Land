import Foundation
import SwiftData

/// Current models. V1 through V3 keep their own unchanged journal definitions.
typealias JournalEntry = SchemaV4.JournalEntry
typealias JournalShelf = SchemaV4.JournalShelf
typealias JournalNotebook = SchemaV4.JournalNotebook

enum JournalNotebookColor {
    static let paletteCount = 8

    /// Stable across launches and independent of Swift's randomized String/Hashable hashing.
    static func automaticIndex(for id: UUID) -> Int {
        withUnsafeBytes(of: id.uuid) { bytes in
            bytes.reduce(0) { $0 + Int($1) } % paletteCount
        }
    }
}

/// Version 4: adds an optional user-selected notebook colour. Existing notebooks remain automatic.
nonisolated enum SchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ChapterRead.self, QuizPass.self, VerseMemorised.self, JournalEntry.self, AvatarProfile.self, CrownCasting.self,
         BookStarted.self, PlacedItem.self, ProduceCollection.self, ProduceGift.self, PlacedExtra.self, ReadingPhoto.self,
         JournalShelf.self, JournalNotebook.self]
    }

    @Model
    final class JournalShelf {
        var id: UUID = UUID()
        var label: String = ""
        var created: Date = Date.now
        @Relationship(deleteRule: .nullify, inverse: \JournalNotebook.shelf)
        var notebooks: [JournalNotebook] = []

        init(label: String, created: Date = .now) {
            self.label = label
            self.created = created
        }
    }

    @Model
    final class JournalNotebook {
        var id: UUID = UUID()
        var name: String = ""
        var created: Date = Date.now
        var colorIndex: Int? = nil
        @Relationship(deleteRule: .nullify)
        var shelf: JournalShelf? = nil
        @Relationship(deleteRule: .nullify, inverse: \JournalEntry.notebook)
        var entries: [JournalEntry] = []

        init(name: String, shelf: JournalShelf? = nil, created: Date = .now, colorIndex: Int? = nil) {
            self.name = name
            self.shelf = shelf
            self.created = created
            self.colorIndex = colorIndex
        }
    }

    @Model
    final class JournalEntry {
        var id: UUID
        var created: Date
        var updated: Date
        var bookID: String?
        var chapter: Int?
        var prompt: String?
        var text: String
        @Relationship(deleteRule: .nullify)
        var notebook: JournalNotebook? = nil
        var verseStart: Int? = nil
        var verseEnd: Int? = nil

        init(bookID: String? = nil, chapter: Int? = nil, prompt: String? = nil, text: String, date: Date = .now) {
            self.id = UUID()
            self.created = date
            self.updated = date
            self.bookID = bookID
            self.chapter = chapter
            self.prompt = prompt
            self.text = text
        }

        @MainActor var reference: String? {
            guard let bookID, let book = BibleCatalog.book(id: bookID) else { return nil }
            guard let chapter else { return book.name }
            let chapterReference = "\(book.name) \(chapter)"
            guard let verseStart else { return chapterReference }
            if let verseEnd, verseEnd != verseStart {
                return "\(chapterReference):\(verseStart)–\(verseEnd)"
            }
            return "\(chapterReference):\(verseStart)"
        }
    }
}

nonisolated enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ChapterRead.self, QuizPass.self, VerseMemorised.self, JournalEntry.self, AvatarProfile.self, CrownCasting.self,
         BookStarted.self, PlacedItem.self, ProduceCollection.self, ProduceGift.self, PlacedExtra.self, ReadingPhoto.self,
         JournalShelf.self, JournalNotebook.self]
    }

    @Model
    final class JournalShelf {
        var id: UUID = UUID()
        var label: String = ""
        var created: Date = Date.now
        @Relationship(deleteRule: .nullify, inverse: \JournalNotebook.shelf)
        var notebooks: [JournalNotebook] = []

        init(label: String, created: Date = .now) {
            self.label = label
            self.created = created
        }
    }

    @Model
    final class JournalNotebook {
        var id: UUID = UUID()
        var name: String = ""
        var created: Date = Date.now
        @Relationship(deleteRule: .nullify)
        var shelf: JournalShelf? = nil
        @Relationship(deleteRule: .nullify, inverse: \JournalEntry.notebook)
        var entries: [JournalEntry] = []

        init(name: String, shelf: JournalShelf? = nil, created: Date = .now) {
            self.name = name
            self.shelf = shelf
            self.created = created
        }
    }

    @Model
    final class JournalEntry {
        var id: UUID
        var created: Date
        var updated: Date
        var bookID: String?
        var chapter: Int?
        var prompt: String?
        var text: String
        @Relationship(deleteRule: .nullify)
        var notebook: JournalNotebook? = nil
        var verseStart: Int? = nil
        var verseEnd: Int? = nil

        init(bookID: String? = nil, chapter: Int? = nil, prompt: String? = nil, text: String, date: Date = .now) {
            self.id = UUID()
            self.created = date
            self.updated = date
            self.bookID = bookID
            self.chapter = chapter
            self.prompt = prompt
            self.text = text
        }

        @MainActor var reference: String? {
            guard let bookID, let book = BibleCatalog.book(id: bookID) else { return nil }
            guard let chapter else { return book.name }
            let chapterReference = "\(book.name) \(chapter)"
            guard let verseStart else { return chapterReference }
            if let verseEnd, verseEnd != verseStart {
                return "\(chapterReference):\(verseStart)–\(verseEnd)"
            }
            return "\(chapterReference):\(verseStart)"
        }
    }
}
