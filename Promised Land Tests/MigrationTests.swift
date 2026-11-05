import Testing
import Foundation
import SwiftData
@testable import Promised_Land

@MainActor
struct IslandMigrationTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    @Test("Existing readers' islands rebuild as Places; only positions they chose themselves are kept")
    func layoutMigration() throws {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "migration-\(UUID().uuidString)")!
        // An old island: Ruth and John read, Genesis begun; plots pinned by the old layout.
        for ch in 1...4 { context.insert(ChapterRead(bookID: "ruth", chapterNumber: ch, date: start.addingTimeInterval(Double(ch) * 60))) }
        for ch in 1...3 { context.insert(ChapterRead(bookID: "john", chapterNumber: ch, date: start.addingTimeInterval(1000 + Double(ch)))) }
        context.insert(ChapterRead(bookID: "genesis", chapterNumber: 1, date: start.addingTimeInterval(5000)))
        context.insert(PlacedItem(key: "ruth", x: 5, y: 7))                              // pinned automatically
        context.insert(PlacedItem(key: "john", x: 30, y: -20, moved: true))              // moved, still fits
        context.insert(PlacedItem(key: "genesis", x: 31, y: -19, moved: true))           // moved, now overlaps John
        try context.save()

        IslandMigration.run(context, defaults: defaults)
        let left = try context.fetch(FetchDescriptor<PlacedItem>()).map(\.key).sorted()
        #expect(left == ["john"])
        #expect(defaults.integer(forKey: IslandMigration.versionKey) == IslandMigration.current)
        #expect(defaults.integer(forKey: StorageKeys.gardenSeenChapters) == -1)

        // The rebuilt island has every book's Place, grown to match the history.
        let reads = try context.fetch(FetchDescriptor<ChapterRead>())
        let saved = try context.fetch(FetchDescriptor<PlacedItem>())
        let island = Island.build(chapters: reads.map { ($0.bookID, $0.chapterNumber, $0.date) }, quizzes: [], verses: [],
                                  placements: Dictionary(uniqueKeysWithValues: saved.map { ($0.key, IslandPlacement(x: $0.x, y: $0.y, moved: $0.moved)) }))
        #expect(Set(island.plots.map(\.bookID)) == ["ruth", "john", "genesis"])
        #expect(island.growth["ruth"]?.pieces.allSatisfy { $0 != nil } == true)
        #expect(island.plots.first { $0.bookID == "john" }.map { $0.x == 30 && $0.y == -20 } == true)
        #expect(reads.count == 8) // no reading history touched

        // Running again changes nothing.
        context.insert(PlacedItem(key: "ruth", x: 9, y: 9))
        IslandMigration.run(context, defaults: defaults)
        #expect(try context.fetch(FetchDescriptor<PlacedItem>()).count == 2)
    }
}

@MainActor
struct SchemaMigrationTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pl-\(UUID().uuidString).store")
    }

    /// Writes a store the way the app did before versioning (plain schema of the V1 models).
    func writeOldStore(at url: URL) throws {
        let container = try ModelContainer(for: Schema(SchemaV1.models), configurations: ModelConfiguration(url: url))
        let context = container.mainContext
        for ch in 1...4 { context.insert(ChapterRead(bookID: "ruth", chapterNumber: ch)) }
        context.insert(ChapterRead(bookID: "john", chapterNumber: 15, checked: false))
        context.insert(QuizPass(bookID: "ruth", score: 3))
        context.insert(VerseMemorised(bookID: "ruth", reference: "Ruth 1:16"))
        context.insert(JournalEntry(bookID: "ruth", chapter: 1, text: "Kept safe"))
        context.insert(BookStarted(bookID: "genesis"))
        context.insert(PlacedItem(key: "ruth", x: 9, y: 9, moved: true))
        try context.save()
    }

    @Test("A store from before versioning opens through the migration plan with every record kept")
    func unversionedStoreMigrates() throws {
        let url = tempURL()
        try writeOldStore(at: url)
        let container = try AppSchema.container(url: url)
        let context = container.mainContext
        #expect(try context.fetch(FetchDescriptor<ChapterRead>()).count == 5)
        #expect(try context.fetch(FetchDescriptor<ChapterRead>()).filter { !$0.checked }.count == 1)
        #expect(try context.fetch(FetchDescriptor<QuizPass>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<VerseMemorised>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<JournalEntry>()).first?.text == "Kept safe")
        #expect(try context.fetch(FetchDescriptor<BookStarted>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PlacedItem>()).first?.moved == true)
        // The new records work alongside the old ones.
        context.insert(ProduceCollection(bookID: "ruth", kind: .bread, amount: 2))
        context.insert(PlacedExtra(kind: .bench, x: 1, y: 2))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<ProduceCollection>()).count == 1)
    }

    @Test("Opening the migrated store again changes nothing")
    func reopen() throws {
        let url = tempURL()
        try writeOldStore(at: url)
        do {
            let first = try AppSchema.container(url: url)
            first.mainContext.insert(ProduceGift(kind: .fish, amount: 1, recipient: "crowd"))
            try first.mainContext.save()
        }
        let again = try AppSchema.container(url: url)
        #expect(try again.mainContext.fetch(FetchDescriptor<ChapterRead>()).count == 5)
        #expect(try again.mainContext.fetch(FetchDescriptor<ProduceGift>()).count == 1)
    }
}
