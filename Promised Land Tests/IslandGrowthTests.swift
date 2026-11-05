import Testing
import Foundation
import CoreGraphics
import SwiftData
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

@MainActor
struct IslandGeographyTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    func island(_ books: [String]) -> Island {
        Island.build(chapters: books.enumerated().map { ($1, 1, start.addingTimeInterval(Double($0) * 86_400)) },
                     quizzes: [], verses: [])
    }

    @Test("Old Testament books grow to the left, New Testament books to the right")
    func testamentSides() {
        let i = island(["genesis", "john", "ruth", "acts", "psalms", "romans"])
        for plot in i.plots {
            let across = plot.centre.y - plot.centre.x // > 0 is left on screen
            if BibleCatalog.book(id: plot.bookID)?.testament == .old {
                #expect(across > 0, "\(plot.bookID) should be on the left")
            } else {
                #expect(across < 0, "\(plot.bookID) should be on the right")
            }
        }
    }

    @Test("Harbour books sit on the coast, beside a bay of open water")
    func harboursOnTheCoast() {
        let i = island(["genesis", "john", "ruth", "jonah", "mark", "luke", "acts"])
        let land = Set(i.tiles)
        #expect(!i.water.isEmpty)
        #expect(i.water.allSatisfy { !land.contains($0) })
        for id in ["john", "jonah"] {
            guard let plot = i.plots.first(where: { $0.bookID == id }) else { Issue.record("no plot"); continue }
            // Some tile next to the plot's border is water.
            let border = (plot.x - 2...plot.x + plot.size + 1).flatMap { x in
                (plot.y - 2...plot.y + plot.size + 1).map { Island.Tile(x: x, y: $0) } }
            #expect(border.contains { !land.contains($0) }, "\(id) should touch the sea")
        }
    }

    @Test("Turning the island keeps grid and screen in step", arguments: [0, 1, 2, 3])
    func rotationRoundTrip(quarter: Int) {
        let i = island(["genesis", "john"])
        let layout = IslandLayout(island: i, size: CGSize(width: 390, height: 844), zoom: 2, angle: CGFloat(quarter))
        let g = layout.grid(layout.point(1.37, -0.81))
        #expect(abs(g.x - 1.37) < 0.0001 && abs(g.y + 0.81) < 0.0001)
        #expect(layout.quarter == quarter)
        #expect(layout.mirrored == (quarter % 2 == 1))
    }

    @Test("A full turn comes back to the same view")
    func fullTurn() {
        let i = island(["genesis", "john"])
        let a = IslandLayout(island: i, size: CGSize(width: 390, height: 844), angle: 0)
        let b = IslandLayout(island: i, size: CGSize(width: 390, height: 844), angle: 4)
        let p = a.point(2, 3), q = b.point(2, 3)
        #expect(abs(p.x - q.x) < 0.001 && abs(p.y - q.y) < 0.001)
    }

    @Test("Taps still pick the right thing when the island is turned", arguments: [0, 1, 2, 3])
    func tapsWhenTurned(quarter: Int) {
        let i = island(["ruth"])
        let layout = IslandLayout(island: i, size: CGSize(width: 390, height: 844), zoom: 3, angle: CGFloat(quarter))
        guard let index = i.items.firstIndex(where: { if case .building = $0.kind { true } else { false } }) else { return }
        let b = i.items[index]
        #expect(IslandHitTester.hit(point: layout.point(b.gx, b.gy), layout: layout, items: i.items) == index)
    }
}

@MainActor
struct IslandEditTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)
    var reads: [(book: String, chapter: Int, date: Date)] {
        ["ruth", "john", "jonah", "acts"].enumerated().map { ($1, 1, start.addingTimeInterval(Double($0) * 86_400)) }
    }

    func build(_ placements: [String: IslandPlacement] = [:]) -> Island {
        Island.build(chapters: reads, quizzes: [], verses: [], placements: placements)
    }

    @Test("A saved place is respected")
    func savedPlace() {
        let island = build(["ruth": IslandPlacement(x: 20, y: 20, moved: true)])
        let plot = island.plots.first { $0.bookID == "ruth" }
        #expect(plot?.x == 20 && plot?.y == 20)
        #expect(island.conflicts.isEmpty)
        // Ruth's building moved with its plot.
        let building = island.items.first { $0.kind == .building("ruth") }
        #expect(building.map { $0.gx > 20 && $0.gy > 20 } == true)
    }

    @Test("Moving one plot leaves frozen plots exactly where they were")
    func othersStay() {
        let auto = build()
        var frozen = auto.placements
        frozen["ruth"] = IslandPlacement(x: 20, y: 20, moved: true)
        let moved = build(frozen)
        for plot in auto.plots where plot.bookID != "ruth" {
            #expect(moved.plots.contains { $0.bookID == plot.bookID && $0.x == plot.x && $0.y == plot.y })
        }
    }

    @Test("Overlapping plots are flagged, so they can't be dropped there")
    func overlapFlagged() {
        let auto = build()
        guard let john = auto.plots.first(where: { $0.bookID == "john" }) else { Issue.record("no john"); return }
        var frozen = auto.placements
        frozen["ruth"] = IslandPlacement(x: john.x + 1, y: john.y, moved: true)
        #expect(!build(frozen).conflicts.isEmpty)
    }

    @Test("Tidy up re-places only unmoved plots")
    func tidyUp() {
        let auto = build()
        var frozen = auto.placements
        frozen["ruth"] = IslandPlacement(x: 20, y: 20, moved: true)
        // What tidy up does: keep moved places, lay the rest out again.
        let tidied = build(frozen.filter { $0.value.moved })
        #expect(tidied.plots.first { $0.bookID == "ruth" }.map { $0.x == 20 && $0.y == 20 } == true)
        #expect(tidied.conflicts.isEmpty)
    }

    @Test("Turning a plot turns its layout but keeps everything on the plot")
    func turnedPlot() {
        let flat = build(["ruth": IslandPlacement(x: 20, y: 20)])
        let turned = build(["ruth": IslandPlacement(x: 20, y: 20, rotation: 1)])
        let a = flat.items.first { $0.source == .chapter(book: "ruth", chapter: 1) }!
        let b = turned.items.first { $0.source == .chapter(book: "ruth", chapter: 1) }!
        #expect(a.gx != b.gx || a.gy != b.gy)
        let size = IslandPlots.size(chapters: 4)
        #expect(CGRect(x: 20, y: 20, width: size, height: size).contains(CGPoint(x: b.gx, y: b.gy)))
        #expect(b.turned == 1)
    }
}

@MainActor
struct CharacterUnlockTests {
    func ids(_ books: [String], journeys: [String] = []) -> Set<String> {
        Set(CharacterUnlocks.unlocked(finishedBooks: Set(books), completedJourneys: Set(journeys)).map(\.id))
    }

    @Test("Finishing Exodus to Deuteronomy unlocks Moses, and not before")
    func moses() {
        #expect(!ids(["exodus", "leviticus", "numbers"]).contains("moses"))
        #expect(ids(["exodus", "leviticus", "numbers", "deuteronomy"]).contains("moses"))
    }

    @Test("Each character's books unlock them")
    func rules() {
        #expect(ids(["ruth"]) == ["ruth"])
        #expect(ids(["jonah"]) == ["jonah"])
        #expect(ids(["daniel"]) == ["daniel"])
        #expect(ids(["1samuel", "2samuel"]) == ["david"])
        #expect(ids(["matthew", "mark", "luke", "john"]) == ["disciples"])
        #expect(!ids(["acts", "romans"]).contains("paul"))
        let nt = BibleCatalog.books.filter { $0.testament == .new }.map(\.id)
        #expect(ids(nt).isSuperset(of: ["jesus", "paul", "disciples"]))
    }

    @Test("Completing a journey unlocks its character")
    func journeys() {
        #expect(ids([], journeys: ["jonah"]) == ["jonah"])
        #expect(ids([], journeys: ["paul-rome"]) == ["paul"])
        #expect(ids([], journeys: ["galilee"]) == ["disciples"])
    }

    @Test("Characters have rarities, stories and unreviewed content flags")
    func data() {
        #expect(Set(CharacterUnlocks.all.map(\.rarity)) == Set(Rarity.allCases))
        for c in CharacterUnlocks.all {
            #expect(BibleCatalog.book(id: c.storyBook).map { (1...$0.chapterCount).contains(c.storyChapter) } == true)
            #expect(!c.reference.isEmpty && !c.source.isEmpty)
            #expect(c.books.allSatisfy { BibleCatalog.book(id: $0) != nil })
        }
    }

    @Test("Characters walk around their own book's plot")
    func home() {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let island = Island.build(chapters: (1...4).map { ("ruth", $0, start) }, quizzes: [], verses: [])
        let walkers = IslandCharacter.make(CharacterUnlocks.unlocked(finishedBooks: ["ruth"]), island: island)
        let plot = island.plots.first { $0.bookID == "ruth" }!
        #expect(walkers.first?.home == plot.centre)
        for t in stride(from: 0.0, to: 60, by: 7) {
            let p = walkers[0].position(at: t)
            #expect(hypot(p.x - plot.centre.x, p.y - plot.centre.y) <= walkers[0].radius + 0.001)
        }
    }
}

struct AvatarTests {
    @Test("Earlier headcloth characters keep their headcloth")
    @MainActor func legacyHeadcloth() {
        let profile = AvatarProfile(Avatar())
        profile.hair = "headcloth"
        profile.hairColor = "#E39A7E"
        profile.covering = "legacy"
        let a = profile.avatar
        #expect(a.covering == .headcloth)
        #expect(a.coveringColor == "#E39A7E")
    }

    @Test("Randomise keeps the name")
    func randomise() {
        var a = Avatar()
        a.name = "Hannah"
        #expect(a.randomised().name == "Hannah")
    }
}

@MainActor
struct InteriorTextTests {
    func text(progress: Int, total: Int, level: Int) -> String {
        var item = Island.Item(kind: .building("ruth"), gx: 0, gy: 0, seed: 0)
        item.progress = progress; item.total = total; item.level = level
        return InsightSubject.buildingText(item, book: BibleCatalog.book(id: "ruth")!)
    }

    @Test("A building's inside page says how far along it is, with the exact floor count")
    func states() {
        #expect(text(progress: 0, total: 4, level: 0).hasPrefix("Foundations laid"))
        #expect(text(progress: 3, total: 4, level: 0).contains("1 more to raise"))
        #expect(text(progress: 4, total: 4, level: 1).hasPrefix("Built when you finished"))
        #expect(text(progress: 4, total: 4, level: 7).contains("6 extra floors"))
    }
}

@MainActor
struct ReadingCheckTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    @Test("Unchecked reads place artifacts but don't build until checked")
    func uncheckedReads() {
        let reads = (1...4).map { (book: "ruth", chapter: $0, date: start.addingTimeInterval(Double($0) * 86_400)) }
        let waiting = Island.build(chapters: reads, quizzes: [], verses: [], unchecked: [("ruth", 4)])
        let building = waiting.items.first { $0.kind == .building("ruth") }!
        #expect(building.progress == 3)
        #expect(IslandPainter.buildingLevel(building) == 0)
        #expect(waiting.items.contains { $0.source == .chapter(book: "ruth", chapter: 4) })
        let checked = Island.build(chapters: reads, quizzes: [], verses: [])
        #expect(IslandPainter.buildingLevel(checked.items.first { $0.kind == .building("ruth") }!) == 1)
    }

    @Test("Marking as read is one tap; the check then counts it")
    func markLatestChecked() throws {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.recordRead("ruth", 1, checked: false)
        #expect(try context.fetch(FetchDescriptor<ChapterRead>()).first?.checked == false)
        context.markLatestChecked("ruth", 1)
        #expect(try context.fetch(FetchDescriptor<ChapterRead>()).first?.checked == true)
    }

    @Test("Earlier reads count as checked")
    func defaultsChecked() {
        #expect(ChapterRead(bookID: "ruth", chapterNumber: 1).checked)
    }
}

struct PagePlannerTests {
    let verses = (1...30).map { Verse(number: $0, text: String(repeating: "word ", count: 20 + $0 % 7)) }

    @Test("Every verse appears once, in order")
    func allVerses() {
        let pages = PagePlanner.pages(verses, width: 300, height: 500, fontSize: 18, footerHeight: 200, titleHeight: 60)
        #expect(pages.flatMap { $0 }.map(\.number) == Array(1...30))
        #expect(pages.count > 1)
    }

    @Test("A wider page (an iPad spread page) needs fewer pages")
    func widerFewer() {
        let narrow = PagePlanner.pages(verses, width: 300, height: 600, fontSize: 18, footerHeight: 200, titleHeight: 60)
        let wide = PagePlanner.pages(verses, width: 600, height: 600, fontSize: 18, footerHeight: 200, titleHeight: 60)
        #expect(wide.count < narrow.count)
    }

    @Test("The last page has room for Mark as read")
    func footerRoom() {
        let short = [Verse(number: 1, text: "In the beginning God created the heavens and the earth.")]
        #expect(PagePlanner.pages(short, width: 300, height: 600, fontSize: 18, footerHeight: 200, titleHeight: 60).count == 1)
        #expect(PagePlanner.pages(short, width: 300, height: 200, fontSize: 18, footerHeight: 200, titleHeight: 60).count == 2)
    }
}

@MainActor
struct JourneyContextTests {
    @Test("Paul's voyage has the six stops in order")
    func paul() {
        let names = JourneyData.journey(id: "paul-rome")!.stops.map(\.name)
        #expect(names == ["Sidon", "Myra", "Fair Havens, Crete", "The storm", "Melita (Malta)", "Rome"])
    }

    @Test("Every stop has a context card and a real chapter; journeys stay unreviewed")
    func contextCards() {
        for journey in JourneyData.all {
            #expect(!journey.reviewed)
            for stop in journey.stops {
                #expect(!stop.place.isEmpty && !stop.happened.isEmpty && !stop.lookedLike.isEmpty)
                #expect(BibleCatalog.book(id: stop.bookID).map { (1...$0.chapterCount).contains(stop.chapter) } == true)
            }
        }
    }

    @Test("Completing a journey welcomes a character")
    func rewards() {
        for journey in JourneyData.all { #expect(JourneyData.reward(journey) != nil) }
    }

    @Test("What can I build? names a book's artifacts, stories and characters")
    func catalogue() {
        #expect(BuildPreview.artifactLine("ruth").hasPrefix("Chapters place: "))
        #expect(BuildPreview.storyLine("genesis")?.contains("Noah's Ark") == true)
        #expect(BuildPreview.characterLine("exodus") == "Helps welcome Moses")
        #expect(BuildPreview.characterLine("obadiah") == nil)
    }
}

@MainActor
struct GroupsTests {
    @Test("The mock service offers one read-only sample group, labelled Preview")
    func mock() async throws {
        let groups = try await MockGroupsService().groups()
        #expect(groups.count == 1)
        #expect(groups[0].isPreview)
        #expect(groups[0].members.count >= 2)
    }

    @Test("Everyone's reads build one shared island")
    func sharedIsland() {
        let group = MockGroupsService.sample
        #expect(group.combinedReads.count == group.members.map(\.reads.count).reduce(0, +))
        let island = Island.build(chapters: group.combinedReads, quizzes: [], verses: [])
        // Every book anyone read has a plot.
        #expect(Set(island.plots.map(\.bookID)) == Set(group.combinedReads.map(\.book)))
    }

    @Test("Who read what lists each member's chapters per book")
    func contributions() {
        let group = MockGroupsService.sample
        let psalms = group.contributions.first { $0.book == "psalms" }
        #expect(psalms?.members.count == 2) // two sample members read Psalms
        #expect(psalms?.members.first?.chapters == 60) // most first
    }
}

struct SpreadTests {
    @Test("Two pages side by side only when the space is wide and landscape")
    func spread() {
        #expect(PageReaderLayout.isSpread(CGSize(width: 1180, height: 800)))
        #expect(!PageReaderLayout.isSpread(CGSize(width: 820, height: 1100)))
        #expect(!PageReaderLayout.isSpread(CGSize(width: 600, height: 390)))
    }

    @Test("A spread always ends on a full pair of pages")
    func evenSpread() {
        let short = [Verse(number: 1, text: "In the beginning God created the heavens and the earth.")]
        #expect(PagePlanner.pages(short, width: 400, height: 700, fontSize: 18, footerHeight: 190, titleHeight: 56, evenCount: true).count == 2)
        #expect(PagePlanner.pages(short, width: 400, height: 700, fontSize: 18, footerHeight: 190, titleHeight: 56).count == 1)
    }
}

@MainActor
struct UnlockNoticeTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    func ids(_ island: Island, journeys: [Journey] = []) -> Set<String> {
        Set(UnlockNotices.all(island: island, completedJourneys: journeys).map(\.id))
    }

    @Test("Finishing a book, rereading it, story objects, rewards and the Library are announced")
    func announced() {
        let reads = (1...4).flatMap { ch in (0..<3).map { t in ("ruth", ch, start.addingTimeInterval(Double(t * 10 + ch) * 86_400)) } }
            + [("genesis", 6, start)]
        let island = Island.build(chapters: reads, quizzes: [("ruth", start)], verses: [("ruth", start)], features: [.library])
        let found = ids(island)
        #expect(found.isSuperset(of: ["built:ruth", "floor:ruth:2", "floor:ruth:3", "story:ark", "reward:ruth:banner", "library"]))
        #expect(found.contains("reward:ruth:\(RewardData.verse(for: "ruth").rawValue)"))
    }

    @Test("Ordinary chapter artifacts and unfinished buildings aren't announced")
    func quiet() {
        let island = Island.build(chapters: [("ruth", 2, start)], quizzes: [], verses: [])
        #expect(ids(island).isEmpty)
    }

    @Test("Completed journeys are announced, and every notice can be found again")
    func journeysAndIndices() {
        let island = Island.build(chapters: (1...4).map { ("ruth", $0, start) }, quizzes: [], verses: [])
        let notices = UnlockNotices.all(island: island, completedJourneys: [JourneyData.journey(id: "jonah")!])
        #expect(notices.contains { $0.id == "journey:jonah" && $0.itemIndex == nil })
        for n in notices { if let i = n.itemIndex { #expect(island.items.indices.contains(i)) } }
    }
}

@MainActor
struct LibraryHubTests {
    @Test("The Library's shelves hold all 66 books, once each, in order")
    func shelves() {
        let shelved = BookSection.all.flatMap(\.books).map(\.id)
        #expect(shelved == BibleCatalog.books.map(\.id))
        #expect(BookSection.all.first?.books.last?.id == "deuteronomy")
        #expect(BookSection.all.first { $0.id == "prophets" }?.books.last?.id == "malachi")
        #expect(BookSection.all.first { $0.id == "gospels" }?.books.map(\.id) == ["matthew", "mark", "luke", "john"])
    }
}

@MainActor
struct SectionLayoutTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    func island(_ books: [String]) -> Island {
        Island.build(chapters: books.enumerated().map { ($1, 1, start.addingTimeInterval(Double($0) * 3600)) }, quizzes: [], verses: [])
    }

    @Test("Each part of the Bible grows its own way: the Law up-left, the Gospels up-right")
    func directions() {
        let law = ["genesis", "exodus", "leviticus", "numbers", "deuteronomy"]
        let gospels = ["matthew", "mark", "luke", "john"]
        let i = island(law + gospels)
        func mean(_ ids: [String]) -> CGPoint {
            let ps = i.plots.filter { ids.contains($0.bookID) }.map(\.centre)
            return CGPoint(x: ps.map(\.x).reduce(0, +) / CGFloat(ps.count) - 1, y: ps.map(\.y).reduce(0, +) / CGFloat(ps.count) - 1)
        }
        let l = mean(law), g = mean(gospels)
        #expect(l.y - l.x > 0 && g.y - g.x < 0) // opposite Testament halves
        #expect(l.x < 0) // the Law leans towards -x (up-left on screen)
        #expect(g.y < 0) // the Gospels lean towards -y (up-right on screen)
    }

    @Test("All 66 books: no plots overlap and the island is one piece of land")
    func wholeBible() {
        let i = island(BibleCatalog.books.map(\.id))
        let rects = i.plots.map { CGRect(x: $0.x, y: $0.y, width: $0.size, height: $0.size) }
        for a in rects.indices { for b in rects.indices where a < b { #expect(!rects[a].intersects(rects[b])) } }
        // Flood fill the land from the starting square.
        let land = Set(i.tiles)
        var seen: Set<Island.Tile> = [i.tiles[0]]
        var queue = [i.tiles[0]]
        while let t = queue.popLast() {
            for n in [Island.Tile(x: t.x + 1, y: t.y), Island.Tile(x: t.x - 1, y: t.y), Island.Tile(x: t.x, y: t.y + 1), Island.Tile(x: t.x, y: t.y - 1)]
            where land.contains(n) && seen.insert(n).inserted { queue.append(n) }
        }
        #expect(seen.count == land.count)
    }

    @Test("Leviticus has its tabernacle story object")
    func leviticus() {
        let i = island(["leviticus"])
        #expect(i.items.contains { $0.kind == .story("altar-offerings") })
    }
}

@MainActor
struct RevealOrderTests {
    @Test("Reading adds new things at the end, even with the Library on the island")
    func appendOnly() {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let before = Island.build(chapters: [("ruth", 1, start)], quizzes: [], verses: [], features: [.library])
        let after = Island.build(chapters: [("ruth", 1, start), ("ruth", 2, start.addingTimeInterval(86_400))],
                                 quizzes: [], verses: [], features: [.library])
        #expect(after.items.count == before.items.count + 1)
        #expect(after.items.last?.source == .chapter(book: "ruth", chapter: 2))
        #expect(after.items.first?.kind == .library)
    }
}
