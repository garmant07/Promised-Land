import Testing
import Foundation
import CoreGraphics
@testable import Promised_Land

struct ProduceTests {
    let cal = Calendar(identifier: .gregorian)
    let day0 = Date(timeIntervalSince1970: 1_780_000_000)
    func day(_ n: Int) -> Date { day0.addingTimeInterval(Double(n) * 86_400 + 3600) }

    @Test("Nothing is produced until a Place is complete")
    func incomplete() {
        #expect(ProduceRules.ready(completed: nil, lastCollected: nil, readingDays: [cal.startOfDay(for: day(1))], calendar: cal) == 0)
    }

    @Test("Produce accrues only on days you read, from the day the Place was completed")
    func readingDaysOnly() {
        let days = ProduceRules.readingDays([day(0), day(0), day(5)], calendar: cal)
        #expect(ProduceRules.ready(completed: day(0), lastCollected: nil, readingDays: days, calendar: cal) == 2)
        // Reading before completion doesn't count.
        #expect(ProduceRules.ready(completed: day(3), lastCollected: nil, readingDays: days, calendar: cal) == 1)
        // A week without reading adds nothing.
        #expect(ProduceRules.ready(completed: day(6), lastCollected: nil, readingDays: days, calendar: cal) == 0)
    }

    @Test("The basket holds at most a few, and collecting empties it")
    func capAndCollect() {
        let days = ProduceRules.readingDays((0..<20).map(day), calendar: cal)
        #expect(ProduceRules.ready(completed: day(0), lastCollected: nil, readingDays: days, calendar: cal) == ProduceRules.cap)
        #expect(ProduceRules.ready(completed: day(0), lastCollected: day(19), readingDays: days, calendar: cal) == 0)
        #expect(ProduceRules.ready(completed: day(0), lastCollected: day(18), readingDays: days, calendar: cal) == 1)
    }

    @Test("Giving takes from what you've collected; bread and fish together feed the crowd")
    func giving() {
        let inv = ProduceRules.inventory(collected: [(.fish, 3), (.bread, 2), (.fish, 1)], given: [(.fish, 2), (.bread, 2)])
        #expect(inv == [.fish: 2])
        #expect(ProduceRules.isFeedingTheCrowd([.bread: 1, .fish: 1]))
        #expect(!ProduceRules.isFeedingTheCrowd([.fish: 3]))
        #expect(!FeedingTheCrowd.entry.reviewed)
    }
}

@MainActor
struct VillagerTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    func island(_ reads: [(String, ClosedRange<Int>, Int)]) -> Island {
        var all: [(book: String, chapter: Int, date: Date)] = []
        var n = 0.0
        for (b, r, times) in reads { for _ in 0..<times { for c in r { all.append((b, c, start.addingTimeInterval(n))); n += 60 } } }
        return Island.build(chapters: all, quizzes: [], verses: [], features: [.library])
    }

    @Test("Villagers move in only when a Place is complete, a few per Place (more with rereads)")
    func moveIn() {
        #expect(VillagerData.villagers(island: island([("ruth", 1...3, 1)])).isEmpty)
        let once = VillagerData.villagers(island: island([("ruth", 1...4, 1)])).filter { $0.id.hasPrefix("ruth") }
        let rich = VillagerData.villagers(island: island([("ruth", 1...4, 5)])).filter { $0.id.hasPrefix("ruth") }
        #expect(once.count == 2)
        #expect(rich.count == VillagerData.perPlace)
        // A crowd gathers in the plaza.
        #expect(VillagerData.villagers(island: island([("ruth", 1...4, 1)])).contains { $0.id.hasPrefix("crowd") })
    }

    @Test("A fisherman rows out onto the bay and comes home with the catch")
    func fisherman() {
        let i = island([("jonah", 1...4, 1), ("john", 1...21, 1)])
        let plot = i.plots.first { $0.bookID == "john" }!
        let fisher = VillagerData.villagers(island: i).first { $0.id == "john-0" }!
        var boat = false, carrying = false
        for t in stride(from: 0.0, to: fisher.period, by: 0.25) {
            let p = fisher.pose(at: t)
            #expect(p.point.x.isFinite && p.point.y.isFinite)
            if p.pose == .boat {
                boat = true
                #expect(!plot.rect.insetBy(dx: 0.05, dy: 0.05).contains(p.point), "the boat is out on the water")
            }
            if p.carrying { carrying = true }
        }
        #expect(boat && carrying)
    }

    @Test("At most six travellers walk the roads")
    func travellers() {
        let i = island(BibleCatalog.books.prefix(20).map { ($0.id, 1...1, 1) })
        #expect(Traveller.make(island: i).count <= VillagerData.maxTravellers)
        for t in Traveller.make(island: i) {
            let land = Set(i.tiles)
            for time in stride(from: 0.0, to: 120, by: 7) {
                let p = t.position(at: time).point
                #expect(land.contains(Island.Tile(x: Int(floor(p.x)), y: Int(floor(p.y)))))
            }
        }
    }

    @Test("Baskets sit on complete Places with produce waiting")
    func baskets() {
        let i = island([("ruth", 1...4, 1)])
        let life = IslandLife.make(island: i, baskets: ["ruth": 2, "john": 1])
        #expect(life.baskets.map(\.bookID) == ["ruth"])
        #expect(life.baskets.first?.kind == .bread)
    }

    @Test("Zoom buckets cover the whole zoom range")
    func buckets() {
        #expect(IslandRenderCache.bucket(for: 1) == 1)
        #expect(IslandRenderCache.bucket(for: 1.1) == 1.25)
        #expect(IslandRenderCache.bucket(for: 4) == 4)
    }
}
