import Testing
import Foundation
import SwiftData
import CoreGraphics
@testable import Promised_Land

@MainActor
struct CollectAllTests {
    let day0 = Date(timeIntervalSince1970: 1_780_000_000)
    func day(_ n: Int) -> Date { day0.addingTimeInterval(Double(n) * 86_400 + 3600) }

    func memoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }

    /// Ruth (farmstead, wheat) and Jonah (harbour) completed, then several reading days, and Mark
    /// half read: two baskets waiting, one Place with none.
    func seed(_ context: ModelContext) {
        for c in 1...4 { context.insert(ChapterRead(bookID: "ruth", chapterNumber: c, date: day(0))) }
        for c in 1...4 { context.insert(ChapterRead(bookID: "jonah", chapterNumber: c, date: day(1))) }
        for (i, c) in (1...6).enumerated() { context.insert(ChapterRead(bookID: "mark", chapterNumber: c, date: day(2 + i))) }
        try? context.save()
    }

    func baskets(_ context: ModelContext) throws -> [String: Int] {
        let reads = try context.fetch(FetchDescriptor<ChapterRead>())
        let collected = try context.fetch(FetchDescriptor<ProduceCollection>())
        let island = Island.build(chapters: reads.map { ($0.bookID, $0.chapterNumber, $0.date) }, quizzes: [], verses: [])
        return ProduceRules.baskets(completed: island.completed, readDates: reads.filter(\.checked).map(\.date),
                                    collections: collected.map { ($0.bookID, $0.date) })
    }

    func inventory(_ context: ModelContext) throws -> [ProduceKind: Int] {
        let collected = try context.fetch(FetchDescriptor<ProduceCollection>())
        let gifts = try context.fetch(FetchDescriptor<ProduceGift>())
        return ProduceRules.inventory(collected: collected.compactMap { c in ProduceKind(rawValue: c.kind).map { ($0, c.amount) } },
                                      given: gifts.compactMap { g in ProduceKind(rawValue: g.kind).map { ($0, g.amount) } })
    }

    @Test("Collect All takes from every Place exactly once and empties every basket")
    func everyPlaceOnce() throws {
        let container = try memoryContainer()
        let context = container.mainContext
        seed(context)
        let before = try baskets(context)
        #expect(Set(before.keys) == ["ruth", "jonah"])
        #expect(before.values.allSatisfy { $0 == ProduceRules.cap }) // capped, as before
        context.collectAllProduce(before, date: day(8))
        let collections = try context.fetch(FetchDescriptor<ProduceCollection>())
        #expect(collections.count == 2)
        #expect(Set(collections.map(\.bookID)) == ["ruth", "jonah"])
        #expect(try baskets(context).isEmpty)
        // A second tap does nothing.
        context.collectAllProduce(try baskets(context), date: day(8))
        #expect(try context.fetch(FetchDescriptor<ProduceCollection>()).count == 2)
    }

    @Test("The summary's totals match what went into the inventory")
    func totalsMatchInventory() throws {
        let container = try memoryContainer()
        let context = container.mainContext
        seed(context)
        let before = try inventory(context)
        let totals = context.collectAllProduce(try baskets(context), date: day(8))
        let after = try inventory(context)
        var delta: [ProduceKind: Int] = [:]
        for kind in ProduceKind.allCases where (after[kind] ?? 0) != (before[kind] ?? 0) {
            delta[kind] = (after[kind] ?? 0) - (before[kind] ?? 0)
        }
        #expect(delta == totals)
        let summary = CollectAll.summary(totals)
        for (kind, n) in totals { #expect(summary.contains("+\(n) \(kind.name.lowercased())")) }
    }

    @Test("Summary reads like \"+3 fish, +2 bread, +1 grapes\"")
    func summaryText() {
        #expect(CollectAll.summary([.grapes: 1, .fish: 3, .bread: 2]) == "+3 fish, +2 bread, +1 grapes")
        #expect(CollectAll.summary([:]) == "")
        #expect(CollectAll.accessibilityLabel(total: 6) == "Collect all, 6 items ready")
        #expect(CollectAll.accessibilityLabel(total: 1) == "Collect all, 1 item ready")
    }

    @Test("The button shows only when something is ready, and never in edit mode, reveals or sheets")
    func visibility() {
        #expect(CollectAll.isButtonVisible(total: 3, editing: false, revealing: false, sheetOpen: false))
        #expect(!CollectAll.isButtonVisible(total: 0, editing: false, revealing: false, sheetOpen: false))
        #expect(!CollectAll.isButtonVisible(total: 3, editing: true, revealing: false, sheetOpen: false))
        #expect(!CollectAll.isButtonVisible(total: 3, editing: false, revealing: true, sheetOpen: false))
        #expect(!CollectAll.isButtonVisible(total: 3, editing: false, revealing: false, sheetOpen: true))
    }

    @Test("Collecting one Place still takes just that Place")
    func singlePlace() throws {
        let container = try memoryContainer()
        let context = container.mainContext
        seed(context)
        let before = try baskets(context)
        context.collectProduce("ruth", kind: PlaceData.spec(for: "ruth").produce, amount: before["ruth"] ?? 0, date: day(8))
        let after = try baskets(context)
        #expect(after["ruth"] == nil)
        #expect(after["jonah"] == before["jonah"])
    }

    @Test("Only reading days fill baskets, and collecting today leaves nothing until the next reading day")
    func rulesUnchanged() throws {
        let container = try memoryContainer()
        let context = container.mainContext
        seed(context)
        context.collectAllProduce(try baskets(context), date: day(8))
        // Days with no reading add nothing.
        #expect(try baskets(context).isEmpty)
        context.insert(ChapterRead(bookID: "mark", chapterNumber: 7, date: day(12)))
        try context.save()
        #expect(try baskets(context) == ["ruth": 1, "jonah": 1])
    }

    @Test("At most 12 things fly; the rest of the on-screen baskets fly together")
    func flightIsCapped() {
        let many = (0..<30).map { (grid: CGPoint(x: $0, y: 0), kind: ProduceKind.fish, count: 2) }
        let sprites = CollectFlightPlan.sprites(many)
        #expect(sprites.count == CollectFlightPlan.maxSprites)
        #expect(sprites.map(\.count).reduce(0, +) == 60)
        #expect(sprites.last?.count == (30 - 11) * 2)
        let few = CollectFlightPlan.sprites(Array(many.prefix(3)))
        #expect(few.count == 3)
        #expect(CollectFlightPlan.length(few) < 1.0)
    }

    @Test("Collecting in Preview full Bible never writes to the real store")
    func previewIsolated() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("real-\(UUID().uuidString).store")
        let real = try AppSchema.container(url: url)
        seed(real.mainContext)
        let realBaskets = try baskets(real.mainContext)

        let preview = try FullBiblePreviewData.makeContainer()
        let island = Island.build(chapters: FullBiblePreviewData.reads, quizzes: [], verses: [], features: [.library])
        let totals = FullBiblePreviewData.collectAll(FullBiblePreviewData.baskets(island), into: preview)
        #expect(totals.values.reduce(0, +) == 66 * 2)
        #expect(try preview.mainContext.fetch(FetchDescriptor<ProduceCollection>()).count == 66)

        #expect(try real.mainContext.fetch(FetchDescriptor<ProduceCollection>()).isEmpty)
        #expect(try baskets(real.mainContext) == realBaskets)
        let reopened = try AppSchema.container(url: url)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<ProduceCollection>()).isEmpty)
    }
}
