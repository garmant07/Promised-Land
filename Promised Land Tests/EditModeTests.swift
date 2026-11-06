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

/// Moving Places in edit mode: no gaps, snug placement, and overlaps that always flag the one you moved.
@MainActor
struct EditGapTests {
    static let reads = FullBiblePreviewData.reads(firstBooks: 40)
    static let base = Island.build(chapters: reads, quizzes: [], verses: [], features: [.library])

    func moved(_ key: String, by d: (Int, Int)? = nil, to spot: (Int, Int)? = nil) -> Island {
        var placements = Self.base.placements
        var p = placements[key]!
        if let d { p.x += d.0; p.y += d.1 }
        if let spot { p.x = spot.0; p.y = spot.1 }
        p.moved = true
        placements[key] = p
        return Island.build(chapters: Self.reads, quizzes: [], verses: [], features: [.library], placements: placements)
    }

    /// Sea tiles in a straight gap of one to three tiles between land (a channel or a narrow inlet),
    /// not counting a bay's mouth (gaps touching a bay stay open water).
    func channels(_ i: Island) -> Int {
        let land = Set(i.tiles)
        func byBay(_ t: Island.Tile) -> Bool {
            [(1, 0), (0, 1), (-1, 0), (0, -1)].contains { i.water.contains(Island.Tile(x: t.x + $0.0, y: t.y + $0.1)) }
        }
        var count = 0
        for t in land {
            for (dx, dy) in [(1, 0), (0, 1)] {
                for gap in 1...3 {
                    let far = Island.Tile(x: t.x + (gap + 1) * dx, y: t.y + (gap + 1) * dy)
                    guard land.contains(far) else { continue }
                    let between = (1...gap).map { Island.Tile(x: t.x + $0 * dx, y: t.y + $0 * dy) }
                    if between.allSatisfy({ !land.contains($0) && !i.water.contains($0) && !byBay($0) }) { count += gap }
                    break
                }
            }
        }
        return count
    }

    func pieces(_ i: Island) -> Int {
        let land = Set(i.tiles)
        var seen: Set<Island.Tile> = [], pieces = 0
        for t in land where !seen.contains(t) {
            pieces += 1
            var stack = [t]
            seen.insert(t)
            while let c = stack.popLast() {
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let n = Island.Tile(x: c.x + dx, y: c.y + dy)
                    if land.contains(n), seen.insert(n).inserted { stack.append(n) }
                }
            }
        }
        return pieces
    }

    @Test("Moving a Place never leaves a channel, an inlet or a separate islet, and every road still reaches the Library")
    func noGaps() {
        let key = Self.base.plots[3].bookID
        for d in [(0, 0), (1, 0), (2, 0), (3, 0), (0, 2), (-2, 1), (4, 4), (12, 12), (20, -6)] {
            let i = moved(key, by: d)
            #expect(channels(i) == 0, "moved by \(d)")
            #expect(pieces(i) == 1, "moved by \(d)")
            for plot in i.plots { #expect(!i.routeToLibrary(from: plot.bookID).isEmpty, "\(plot.bookID) after moving by \(d)") }
        }
    }

    @Test("A Place can go right beside another, with no gap")
    func snug() {
        let key = Self.base.plots[3].bookID, other = Self.base.plots[5]
        let i = moved(key, to: (other.x + other.size, other.y))
        #expect(!i.conflicts.contains(key))
        #expect(i.conflicts.isEmpty)
    }

    @Test("Dropping a Place onto another flags both, so the one you moved springs back")
    func overlapFlagsBoth() {
        let a = Self.base.plots[3], b = Self.base.plots[10]
        let i = moved(a.bookID, to: (b.x + 1, b.y + 1))
        #expect(i.conflicts.contains(a.bookID))
        #expect(i.conflicts.contains(b.bookID))
    }
}
