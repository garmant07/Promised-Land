import Testing
import Foundation
import SwiftData
import CoreGraphics
@testable import Promised_Land

@MainActor
struct EditModeTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    @Test("Extras are earned by reading streaks and reading days")
    func earned() {
        #expect(RewardData.extrasEarned(longestStreak: 0, readingDays: 0).values.allSatisfy { $0 == 0 })
        let week = RewardData.extrasEarned(longestStreak: 7, readingDays: 10)
        #expect(week[.path] == 5 && week[.tree] == 2 && week[.fence] == 4 && week[.bench] == 1 && week[.lamp] == 1)
        #expect(RewardData.extrasEarned(longestStreak: 999, readingDays: 999)[.path] == 40) // capped
    }

    @Test("The longest streak counts the longest run of reading days")
    func longest() {
        let day: TimeInterval = 86_400
        let dates = [0, 1, 2, 5, 6, 6, 7, 8].map { start.addingTimeInterval(Double($0) * day) }
        #expect(Streak.longest(from: dates) == 4)
        #expect(Streak.longest(from: []) == 0)
    }

    @Test("Extras must stand on open land, not in the sea or inside a Place")
    func extraValidity() {
        let reads = [("ruth", 1, start)]
        let base = Island.build(chapters: reads, quizzes: [], verses: [])
        let plot = base.plots[0]
        let onPlaza = PlacedExtraInfo(id: "a", kind: .bench, x: 0.5, y: 0.5)
        let inPlace = PlacedExtraInfo(id: "b", kind: .lamp, x: CGFloat(plot.x) + 1.5, y: CGFloat(plot.y) + 1.5)
        let atSea = PlacedExtraInfo(id: "c", kind: .tree, x: 80.5, y: 80.5)
        let island = Island.build(chapters: reads, quizzes: [], verses: [], extras: [onPlaza, inPlace, atSea])
        #expect(!island.conflicts.contains("extra:a"))
        #expect(island.conflicts.contains("extra:b"))
        #expect(island.conflicts.contains("extra:c"))
        #expect(island.items.filter { if case .extra = $0.kind { true } else { false } }.count == 3)
    }

    @Test("Placed extras are saved, moved and removed")
    func saving() throws {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.saveExtras([PlacedExtraInfo(id: "x", kind: .bench, x: 1.5, y: 2.5), PlacedExtraInfo(id: "y", kind: .lamp, x: 3.5, y: 3.5)])
        #expect(try context.fetch(FetchDescriptor<PlacedExtra>()).count == 2)
        context.saveExtras([PlacedExtraInfo(id: "x", kind: .bench, x: 4.5, y: 2.5)])
        let rows = try context.fetch(FetchDescriptor<PlacedExtra>())
        #expect(rows.count == 1 && rows[0].x == 4.5)
    }

    @Test("Places you've moved are kept by the generator; new Places avoid them")
    func movedKept() {
        let reads = ["ruth", "john", "acts"].enumerated().map { ($1, 1, start.addingTimeInterval(Double($0))) }
        let moved = ["john": IslandPlacement(x: 2, y: 6, moved: true)]
        let more = reads + [("genesis", 1, start.addingTimeInterval(10)), ("psalms", 1, start.addingTimeInterval(11))]
        let island = Island.build(chapters: more, quizzes: [], verses: [], placements: moved)
        let john = island.plots.first { $0.bookID == "john" }!
        #expect(john.x == 2 && john.y == 6)
        for p in island.plots where p.bookID != "john" { #expect(!p.rect.intersects(john.rect)) }
    }
}
