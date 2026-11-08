import Testing
import Foundation
import SwiftData
@testable import Promised_Land

/// The shared progress snapshot is built once and reused until the stored records change.
@MainActor
struct ProgressCacheTests {
    private func context() throws -> ModelContext {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func snapshot(_ cache: GameProgressCache, _ context: ModelContext, now: Date = .now) throws -> GameProgress {
        let reads = try context.fetch(FetchDescriptor<ChapterRead>())
        return cache.progress(context: context, counts: [reads.count, 0, 0, 0, 0], now: now) {
            GameProgress(reads: reads, quizzes: [], memorised: [])
        }
    }

    @Test("Reading progress many times builds it once (a list of 66 books costs one build)")
    func buildsOnce() throws {
        let cache = GameProgressCache()
        let ctx = try context()
        var builds = 0
        for _ in 0..<200 {
            _ = cache.progress(context: ctx, counts: [3, 0, 0, 0, 0]) { builds += 1; return .empty }
        }
        #expect(builds == 1)
    }

    @Test("A new read, a save, a new day or another store all rebuild it")
    func rebuildsOnChange() throws {
        let cache = GameProgressCache()
        let ctx = try context()
        #expect(try snapshot(cache, ctx).chaptersRead("ruth") == 0)

        ctx.insert(ChapterRead(bookID: "ruth", chapterNumber: 1, date: .now))      // count changes
        #expect(try snapshot(cache, ctx).chaptersRead("ruth") == 1)

        // A change that keeps the count the same shows up once it's saved.
        let read = try ctx.fetch(FetchDescriptor<ChapterRead>()).first!
        read.chapterNumber = 2
        cache.invalidate()                                                           // what a save does
        #expect(try snapshot(cache, ctx).isRead("ruth", chapter: 2))

        var builds = 0
        let counts = [1, 0, 0, 0, 0]
        _ = cache.progress(context: ctx, counts: counts, now: .now.addingTimeInterval(86_400 * 2)) { builds += 1; return .empty }
        #expect(builds == 1)                                                         // a new day (streaks)
        _ = cache.progress(context: try context(), counts: counts, now: .now.addingTimeInterval(86_400 * 2)) { builds += 1; return .empty }
        #expect(builds == 2)                                                         // another store
    }

    @Test("Saving the store invalidates the shared snapshot")
    func saveNotification() throws {
        let ctx = try context()
        let cache = GameProgressCache.shared
        var builds = 0
        _ = cache.progress(context: ctx, counts: [0, 0, 0, 0, 0]) { builds += 1; return .empty }
        _ = cache.progress(context: ctx, counts: [0, 0, 0, 0, 0]) { builds += 1; return .empty }
        #expect(builds == 1)
        ctx.insert(BookStarted(bookID: "ruth", date: .now))
        try ctx.save()
        _ = cache.progress(context: ctx, counts: [0, 0, 0, 0, 0]) { builds += 1; return .empty }
        #expect(builds == 2)
    }
}
