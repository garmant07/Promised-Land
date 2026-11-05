import Testing
import Foundation
import SwiftData
@testable import Promised_Land

@MainActor
struct FullBiblePreviewTests {
    @Test("The preview reads every chapter of all 66 books in its own in-memory store")
    func everyChapter() throws {
        let container = try FullBiblePreviewData.makeContainer()
        #expect(container.configurations.allSatisfy { $0.isStoredInMemoryOnly })
        let reads = try container.mainContext.fetch(FetchDescriptor<ChapterRead>())
        #expect(reads.count == BibleCatalog.totalChapters)
        #expect(Set(reads.map(\.bookID)).count == 66)
    }

    @Test("The preview never writes to the real store")
    func isolated() throws {
        // A stand-in for the real store, on disk, with some progress.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("real-\(UUID().uuidString).store")
        let real = try AppSchema.container(url: url)
        real.mainContext.insert(ChapterRead(bookID: "ruth", chapterNumber: 1))
        try real.mainContext.save()

        let preview = try FullBiblePreviewData.makeContainer()
        preview.mainContext.insert(PlacedExtra(kind: .bench, x: 1, y: 1))
        try preview.mainContext.save()

        #expect(try real.mainContext.fetch(FetchDescriptor<ChapterRead>()).count == 1)
        #expect(try real.mainContext.fetch(FetchDescriptor<PlacedExtra>()).isEmpty)
        #expect(preview.configurations.allSatisfy { $0.url != url })
        // Reopening the real store from disk shows the same: nothing leaked in.
        let reopened = try AppSchema.container(url: url)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<ChapterRead>()).count == 1)
    }

    @Test("The full island has every Place complete, with villagers, roads and the throne room")
    func fullIsland() {
        let island = Island.build(chapters: FullBiblePreviewData.reads, quizzes: [], verses: [], features: [.library, .throne],
                                  richnessOverride: 5)
        #expect(island.plots.count == 66)
        #expect(island.completed.count == 66)
        #expect(island.roads.count == island.allPlots.count)
        #expect(island.items.contains { $0.kind == .throne })
        let villagers = VillagerData.villagers(island: island)
        #expect(villagers.filter { !$0.id.hasPrefix("crowd") }.count == 66 * VillagerData.perPlace)
        // Replay: a prefix of the books builds a smaller island.
        let half = Island.build(chapters: FullBiblePreviewData.reads(firstBooks: 20), quizzes: [], verses: [])
        #expect(half.plots.count == 20)
    }
}
