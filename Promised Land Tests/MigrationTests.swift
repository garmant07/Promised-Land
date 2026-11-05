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
