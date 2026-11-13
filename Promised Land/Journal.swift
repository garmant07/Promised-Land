import Foundation
import SwiftData

/// Current models. V1 through V3 keep their own unchanged journal definitions.
typealias JournalEntry = SchemaV5.JournalEntry
typealias JournalShelf = SchemaV5.JournalShelf
typealias JournalNotebook = SchemaV5.JournalNotebook

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
    @Model
    final class ChapterRead {
        var bookID: String
        var chapterNumber: Int
        var date: Date
        var checked: Bool = true
        init(bookID: String, chapterNumber: Int, date: Date = .now, checked: Bool = true) {
            self.bookID = bookID; self.chapterNumber = chapterNumber; self.date = date; self.checked = checked
        }
    }

    @Model
    final class QuizPass {
        var bookID: String
        var score: Int
        var date: Date
        var passed: Bool = true
        init(bookID: String, score: Int, passed: Bool = true, date: Date = .now) {
            self.bookID = bookID; self.score = score; self.passed = passed; self.date = date
        }
    }

    @Model
    final class VerseMemorised {
        var bookID: String
        var reference: String
        var date: Date
        init(bookID: String, reference: String, date: Date = .now) {
            self.bookID = bookID; self.reference = reference; self.date = date
        }
    }

    @Model
    final class AvatarProfile {
        var name: String
        var robe: String
        var skin: String
        var hair: String
        var hairColor: String
        var sash: String
        var sandals: String
        var beard: String = "none"
        var covering: String = "legacy"
        var coveringColor: String = ""
        var configData: Data? = nil
        init(name: String, robe: String, skin: String, hair: String, hairColor: String,
             sash: String, sandals: String, beard: String = "none", covering: String = "legacy",
             coveringColor: String = "", configData: Data? = nil) {
            self.name = name; self.robe = robe; self.skin = skin; self.hair = hair
            self.hairColor = hairColor; self.sash = sash; self.sandals = sandals
            self.beard = beard; self.covering = covering; self.coveringColor = coveringColor
            self.configData = configData
        }
    }

    @Model
    final class CrownCasting {
        var date: Date
        var cycle: Int
        var perBook: [String: Int]
        init(cycle: Int, perBook: [String: Int], date: Date = .now) {
            self.date = date; self.cycle = cycle; self.perBook = perBook
        }
    }

    @Model
    final class BookStarted {
        var bookID: String
        var date: Date
        init(bookID: String, date: Date = .now) { self.bookID = bookID; self.date = date }
    }

    @Model
    final class PlacedItem {
        var key: String = ""
        var x: Int = 0
        var y: Int = 0
        var rotation: Int = 0
        var moved: Bool = false
        var date: Date = Date()
        init(key: String, x: Int, y: Int, rotation: Int = 0, moved: Bool = false) {
            self.key = key; self.x = x; self.y = y; self.rotation = rotation; self.moved = moved
        }
    }

    @Model
    final class ProduceCollection {
        var bookID: String = ""
        var kind: String = ""
        var amount: Int = 0
        var date: Date = Date()
        init(bookID: String, kind: String, amount: Int, date: Date = .now) {
            self.bookID = bookID; self.kind = kind; self.amount = amount; self.date = date
        }
    }

    @Model
    final class ProduceGift {
        var kind: String = ""
        var amount: Int = 0
        var date: Date = Date()
        var recipient: String = ""
        init(kind: String, amount: Int, recipient: String, date: Date = .now) {
            self.kind = kind; self.amount = amount; self.recipient = recipient; self.date = date
        }
    }

    @Model
    final class PlacedExtra {
        var uid: String = UUID().uuidString
        var kind: String = ""
        var x: Double = 0
        var y: Double = 0
        var rotation: Int = 0
        var date: Date = Date()
        init(kind: String, x: Double, y: Double, rotation: Int = 0) {
            self.kind = kind; self.x = x; self.y = y; self.rotation = rotation
        }
    }

    @Model
    final class ReadingPhoto {
        var uid: UUID = UUID()
        var bookID: String = ""
        var chapter: Int = 0
        var date: Date = Date()
        @Attribute(.externalStorage) var imageData: Data?
        var journalEntryID: UUID?
        init(bookID: String, chapter: Int, imageData: Data?, journalEntryID: UUID? = nil, date: Date = .now) {
            self.bookID = bookID; self.chapter = chapter; self.imageData = imageData
            self.journalEntryID = journalEntryID; self.date = date
        }
    }

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

/// Version 5: adds continuation ordering metadata to journal pages.
nonisolated enum SchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)
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
        var pageOrder: Double? = nil
        var isContinuation: Bool = false

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
