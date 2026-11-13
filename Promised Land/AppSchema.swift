import Foundation
import SwiftData

// MARK: - New records (schema version 2)

/// Produce collected from a complete Place (tapping its basket).
@Model
final class ProduceCollection {
    var bookID: String = ""
    /// A `ProduceKind` raw value.
    var kind: String = ""
    var amount: Int = 0
    var date: Date = Date.now

    init(bookID: String, kind: ProduceKind, amount: Int, date: Date = .now) {
        self.bookID = bookID
        self.kind = kind.rawValue
        self.amount = amount
        self.date = date
    }
}

/// Produce given away: to the crowd in the plaza, or set aside for a friend's island.
/// Stored only on this device; nothing is sent anywhere.
@Model
final class ProduceGift {
    var kind: String = ""
    var amount: Int = 0
    var date: Date = Date.now
    /// "crowd", or "friend:<friend id>".
    var recipient: String = ""

    init(kind: ProduceKind, amount: Int, recipient: String, date: Date = .now) {
        self.kind = kind.rawValue
        self.amount = amount
        self.recipient = recipient
        self.date = date
    }
}

/// A small decoration (path, fence, bench, tree, lamp) placed in edit mode.
@Model
final class PlacedExtra {
    var uid: String = UUID().uuidString
    /// An `ExtraKind` raw value.
    var kind: String = ""
    var x: Double = 0
    var y: Double = 0
    var rotation: Int = 0
    var date: Date = Date.now

    init(kind: ExtraKind, x: Double, y: Double, rotation: Int = 0) {
        self.kind = kind.rawValue
        self.x = x
        self.y = y
        self.rotation = rotation
    }
}

/// A photo of a page of your own Bible, kept privately with a journal entry if you choose.
@Model
final class ReadingPhoto {
    var uid: UUID = UUID()
    var bookID: String = ""
    var chapter: Int = 0
    var date: Date = Date.now
    @Attribute(.externalStorage) var imageData: Data?
    /// The journal entry it belongs to, if any.
    var journalEntryID: UUID?

    init(bookID: String, chapter: Int, imageData: Data?, journalEntryID: UUID? = nil, date: Date = .now) {
        self.bookID = bookID
        self.chapter = chapter
        self.imageData = imageData
        self.journalEntryID = journalEntryID
        self.date = date
    }
}

// MARK: - Versions

/// Version 1: everything stored before the growing-Places round (the store had no version
/// until now; these are exactly its models, unchanged).
nonisolated enum SchemaV1: VersionedSchema {
    // Frozen stored shape. Never add fields to a historical schema.
    @Model
    final class JournalEntry {
        var id: UUID
        var created: Date
        var updated: Date
        /// The Bible book (and chapter) it's about, if any. Free entries have neither.
        var bookID: String?
        var chapter: Int?
        /// The reflection prompt it answers, if any.
        var prompt: String?
        var text: String

        init(bookID: String? = nil, chapter: Int? = nil, prompt: String? = nil, text: String, date: Date = .now) {
            self.id = UUID()
            self.created = date
            self.updated = date
            self.bookID = bookID
            self.chapter = chapter
            self.prompt = prompt
            self.text = text
        }

    }

    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ChapterRead.self, QuizPass.self, VerseMemorised.self, JournalEntry.self, AvatarProfile.self, CrownCasting.self,
         BookStarted.self, PlacedItem.self]
    }
}

/// Version 2: adds produce, gifts, placed extras and Bible photos. Nothing existing changes.
nonisolated enum SchemaV2: VersionedSchema {
    // Frozen stored shape. Never add fields to a historical schema.
    @Model
    final class JournalEntry {
        var id: UUID
        var created: Date
        var updated: Date
        /// The Bible book (and chapter) it's about, if any. Free entries have neither.
        var bookID: String?
        var chapter: Int?
        /// The reflection prompt it answers, if any.
        var prompt: String?
        var text: String

        init(bookID: String? = nil, chapter: Int? = nil, prompt: String? = nil, text: String, date: Date = .now) {
            self.id = UUID()
            self.created = date
            self.updated = date
            self.bookID = bookID
            self.chapter = chapter
            self.prompt = prompt
            self.text = text
        }

    }

    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ChapterRead.self, QuizPass.self, VerseMemorised.self, JournalEntry.self, AvatarProfile.self, CrownCasting.self,
         BookStarted.self, PlacedItem.self, ProduceCollection.self, ProduceGift.self, PlacedExtra.self, ReadingPhoto.self]
    }
}

/// Every step is additive, so each is a lightweight migration: all saved progress is kept.
nonisolated enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
         .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
         .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
         .lightweight(fromVersion: SchemaV4.self, toVersion: SchemaV5.self)]
    }
}

/// Every SwiftData model the app stores, registered once for the app and previews.
enum AppSchema {
    static var models: [any PersistentModel.Type] { SchemaV5.models }

    /// The app's on-disk store, opened through the migration plan.
    static func container(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = url.map { ModelConfiguration(schema: schema, url: $0, cloudKitDatabase: .none) } ?? ModelConfiguration(schema: schema)
        return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: config)
    }
}
