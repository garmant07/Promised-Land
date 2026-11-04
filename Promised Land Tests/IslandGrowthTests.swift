import Testing
import Foundation
import CoreGraphics
@testable import Promised_Land

@MainActor
struct IslandGrowthTests {
    let day: TimeInterval = 86_400
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    func buildings(_ island: Island) -> [Island.Item] {
        island.items.filter { if case .building = $0.kind { true } else { false } }
    }

    func artifacts(_ island: Island) -> [Island.Item] {
        island.items.filter { if case .chapter = $0.source { true } else { false } }
    }

    func reads(_ book: String, _ chapters: ClosedRange<Int>, times: Int = 1, from offset: Double = 0) -> [(book: String, chapter: Int, date: Date)] {
        (0..<times).flatMap { t in chapters.map { (book, $0, start.addingTimeInterval((offset + Double(t * 100 + $0)) * day)) } }
    }

    @Test("Opening a book lays its foundations before any chapter is read")
    func openingLaysFoundations() {
        let island = Island.build(chapters: [], started: [("daniel", start)], quizzes: [], verses: [])
        let built = buildings(island)
        #expect(built.count == 1)
        #expect(built.first?.source == .book("daniel"))
        #expect(built.first?.progress == 0)
        #expect(built.first?.total == 12)
        #expect(IslandPainter.buildingLevel(built[0]) == 0)
    }

    @Test("Each chapter read places one artifact around its book's plot")
    func chaptersPlaceArtifacts() {
        let island = Island.build(chapters: reads("ruth", 1...3), quizzes: [], verses: [])
        #expect(artifacts(island).count == 3)
        #expect(buildings(island).count == 1)
        #expect(buildings(island)[0].progress == 3)
        // Every artifact sits on Ruth's plot, off the building's tile.
        let plot = island.plots[0]
        let land = CGRect(x: plot.x, y: plot.y, width: plot.size, height: plot.size)
        for a in artifacts(island) {
            #expect(land.contains(CGPoint(x: a.gx, y: a.gy)))
            #expect(!buildings(island)[0].footprint.intersects(a.footprint))
        }
    }

    @Test("Story chapters place their story object instead of a theme artifact")
    func storyObjects() {
        // Genesis 6–9 is Noah's Ark: reading chapter 7 shows the ark (once), plus artifacts for the others.
        let island = Island.build(chapters: reads("genesis", 6...8), quizzes: [], verses: [])
        let stories = island.items.filter { if case .story = $0.kind { true } else { false } }
        #expect(stories.count == 1)
        #expect(artifacts(island).count == 2) // chapters 7 and 8; chapter 6's spot holds the ark
    }

    @Test("Rereading a chapter levels its artifact up, to at most 5")
    func rereadsLevelArtifacts() {
        let twice = Island.build(chapters: reads("ruth", 2...2, times: 2), quizzes: [], verses: [])
        #expect(artifacts(twice).first?.level == 2)
        let lots = Island.build(chapters: reads("ruth", 2...2, times: 8), quizzes: [], verses: [])
        #expect(artifacts(lots).first?.level == 5)
        #expect(artifacts(lots).count == 1)
    }

    @Test("Finishing a book builds it; each full reread adds a floor")
    func completionAndFloors() {
        let partial = Island.build(chapters: reads("ruth", 1...3), quizzes: [], verses: [])
        #expect(IslandPainter.buildingLevel(buildings(partial)[0]) == 0)
        let done = Island.build(chapters: reads("ruth", 1...4), quizzes: [], verses: [])
        #expect(buildings(done)[0].level == 1)
        #expect(IslandPainter.buildingLevel(buildings(done)[0]) == 1)
        let thrice = Island.build(chapters: reads("ruth", 1...4, times: 3), quizzes: [], verses: [])
        #expect(buildings(thrice)[0].level == 3)
        #expect(IslandPainter.buildingLevel(buildings(thrice)[0]) == 3)
        // A partial reread doesn't add a floor.
        let partialReread = Island.build(chapters: reads("ruth", 1...4) + reads("ruth", 1...2, from: 50), quizzes: [], verses: [])
        #expect(buildings(partialReread)[0].level == 1)
        // Drawn floors are capped, the count isn't.
        let many = BuildingData.spec(for: "ruth")
        #expect(BuildingArt.storeys(many, extraFloors: 9) == many.storeys + 3)
    }

    @Test("A passed quiz raises a banner, a memorised verse a lantern or fruit tree")
    func rewards() {
        let island = Island.build(chapters: reads("ruth", 1...1), quizzes: [("ruth", start)], verses: [("ruth", start)])
        let kinds = island.items.map(\.kind)
        #expect(kinds.contains(.reward(.banner)))
        #expect(kinds.contains(.reward(RewardData.verse(for: "ruth"))))
    }

    @Test("Nothing moves as more is read, and plots never overlap")
    func stablePlaces() {
        let first = Island.build(chapters: reads("ruth", 1...2), quizzes: [], verses: [])
        let later = Island.build(chapters: reads("ruth", 1...4) + reads("john", 1...5, from: 10) + reads("genesis", 1...20, from: 20),
                                 quizzes: [], verses: [])
        for item in first.items {
            #expect(later.items.contains { $0.source == item.source && $0.gx == item.gx && $0.gy == item.gy })
        }
        let p = later.plots.map { CGRect(x: $0.x, y: $0.y, width: $0.size, height: $0.size) }
        for i in p.indices { for j in p.indices where i < j { #expect(!p[i].insetBy(dx: -0.5, dy: -0.5).intersects(p[j])) } }
    }

    @Test("New things are added at the end, so they build in")
    func newItemsAppend() {
        let before = Island.build(chapters: reads("ruth", 1...2) + reads("john", 1...1, from: 10), quizzes: [], verses: [])
        let after = Island.build(chapters: reads("ruth", 1...2) + reads("john", 1...1, from: 10) + reads("ruth", 3...3, from: 20),
                                 quizzes: [], verses: [])
        #expect(Array(after.items.prefix(before.items.count)) == before.items.map { item in
            // Ruth's building gained a chapter, so compare everything but its progress.
            after.items.first { $0.source == item.source && $0.gx == item.gx } ?? item
        })
        #expect(after.items.last?.source == .chapter(book: "ruth", chapter: 3))
    }

    @Test("Every book's plot has room for every chapter and its rewards")
    func plotsFitEveryChapter() {
        for book in BibleCatalog.books {
            let size = IslandPlots.size(chapters: book.chapterCount)
            let slots = IslandPlots.slots(in: Island.Plot(bookID: book.id, x: 0, y: 0, size: size))
            #expect(slots.count >= book.chapterCount + RewardData.firstChapterSlot)
            #expect(Set(slots.map { "\($0.x),\($0.y)" }).count == slots.count)
        }
    }
}

struct BuildingDataTests {
    @Test("All 66 books have a building")
    func everyBook() {
        let ids = Set(BuildingData.all.map(\.bookID))
        #expect(BuildingData.all.count == 66)
        #expect(ids.count == 66)
        #expect(ids == Set(BibleCatalog.books.map(\.id)))
    }

    @Test("No two books share a silhouette")
    func uniqueSilhouettes() {
        let groups = Dictionary(grouping: BuildingData.all, by: \.silhouette).filter { $0.value.count > 1 }
        #expect(groups.isEmpty, "Shared: \(groups.mapValues { $0.map(\.bookID) })")
    }

    @Test("Specs stay in range and have artifacts")
    func ranges() {
        for spec in BuildingData.all {
            #expect((1...3).contains(spec.width) && (1...4).contains(spec.storeys) && (0...2).contains(spec.wings))
            #expect(!spec.theme.isEmpty)
        }
    }
}
