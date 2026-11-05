import Testing
import Foundation
import CoreGraphics
import SwiftData
import SwiftUI
@testable import Promised_Land


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
struct CharacterJourneyTests {
    func progress(_ journey: CharacterJourney, read: [(String, ClosedRange<Int>)]) -> JourneyProgress {
        let set = Set(read.flatMap { b, r in r.map { "\(b)#\($0)" } })
        return JourneyProgress.make(journey) { set.contains("\($0)#\($1)") }
    }

    @Test("The 12 journeys (and Jonah) are there, shortest first, with art and stops")
    func data() {
        let ids = CharacterJourneys.all.map(\.id)
        #expect(Set(ids).isSuperset(of: ["ruth", "samson", "daniel", "sarah", "mary", "abraham", "solomon", "david", "john", "paul", "moses", "jesus"]))
        let counts = CharacterJourneys.all.map { $0.requiredChapters.count }
        #expect(counts == counts.sorted())
        for j in CharacterJourneys.all {
            #expect(!j.stops.isEmpty && !j.reviewed && !j.unlockLine.isEmpty)
            for stop in j.stops {
                #expect(!stop.happened.isEmpty && !stop.reviewed)
                for span in stop.spans {
                    #expect(BibleCatalog.book(id: span.bookID).map { span.chapters.upperBound <= $0.chapterCount } == true, "\(stop.id)")
                }
            }
        }
        #expect(Set(CharacterJourneys.all.map(\.rarity)) == Set(Rarity.allCases))
    }

    @Test("Finishing Exodus to Deuteronomy completes Moses's journey, and not before")
    func moses() {
        let moses = CharacterJourneys.journey(id: "moses")!
        #expect(!progress(moses, read: [("exodus", 1...40), ("leviticus", 1...27), ("numbers", 1...36)]).isComplete)
        #expect(progress(moses, read: [("exodus", 1...40), ("leviticus", 1...27), ("numbers", 1...36), ("deuteronomy", 1...34)]).isComplete)
    }

    @Test("Stops complete when all their chapters are read; next stop and chapter follow")
    func stops() {
        let ruth = CharacterJourneys.journey(id: "ruth")!
        let p = progress(ruth, read: [("ruth", 1...2)])
        #expect(p.completedStops == ["ruth-moab", "ruth-road", "ruth-field"])
        #expect(p.nextStop?.id == "ruth-floor")
        #expect(p.nextChapter == ChapterRef(bookID: "ruth", chapter: 3))
        #expect(p.read == 2 && p.required == 4)
    }

    @Test("Reading done before this update counts (progress comes from every read)")
    @MainActor func pastReading() throws {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        for ch in 1...4 { context.insert(ChapterRead(bookID: "ruth", chapterNumber: ch, date: Date(timeIntervalSince1970: 1_600_000_000))) }
        try context.save()
        let reads = try context.fetch(FetchDescriptor<ChapterRead>())
        let set = Set(reads.map { "\($0.bookID)#\($0.chapterNumber)" })
        #expect(JourneyProgress.make(CharacterJourneys.journey(id: "ruth")!) { set.contains("\($0)#\($1)") }.isComplete)
    }

    @Test("Paul needs Acts 7–28 and every letter from Romans to Philemon")
    func paul() {
        let paul = CharacterJourneys.journey(id: "paul")!
        let books = Set(paul.requiredChapters.map(\.book))
        #expect(books.contains("romans") && books.contains("philemon") && !books.contains("hebrews"))
        #expect(!paul.requiredChapters.contains { $0.book == "acts" && $0.chapter < 7 })
    }

    @Test("Characters walk around their own story's plot")
    func home() {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let island = Island.build(chapters: (1...4).map { ("ruth", $0, start) }, quizzes: [], verses: [])
        let walkers = IslandCharacter.make([CharacterJourneys.journey(id: "ruth")!], island: island)
        let plot = island.plots.first { $0.bookID == "ruth" }!
        #expect(walkers.first?.home == plot.centre)
        for t in stride(from: 0.0, to: 60, by: 7) {
            let p = walkers[0].position(at: t)
            #expect(hypot(p.x - plot.centre.x, p.y - plot.centre.y) <= walkers[0].radius + 0.001)
        }
    }
}

struct AvatarTests {
    @Test("A saved profile from before the rebuild still shows its headcloth")
    @MainActor func legacyHeadcloth() {
        let profile = AvatarProfile(Avatar())
        profile.configData = nil
        profile.hair = "headcloth"
        profile.hairColor = "#E39A7E"
        profile.covering = "legacy"
        #expect(profile.config.head == .veil)
        #expect(profile.config.headColour == .terracotta || profile.config.headColour == .rose)
    }

    @Test("Saving a look keeps it, and the name is separate")
    @MainActor func saving() {
        let profile = AvatarProfile(Avatar(name: "Hannah"))
        profile.apply(AvatarPresets.config(for: "ruth"))
        #expect(profile.avatar.config == AvatarPresets.config(for: "ruth"))
        #expect(profile.avatar.name == "Hannah")
    }
}


@MainActor
struct ReadingCheckTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)


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
struct AvatarRenderingTests {
    let canvas = CGRect(origin: .zero, size: AvatarRenderer.canvas)

    func check(_ c: AvatarConfig) {
        let layers = AvatarRenderer.layers(c)
        #expect(layers.count == 12) // every layer is always present (maybe empty)
        let b = AvatarRenderer.bounds(c)
        #expect(canvas.insetBy(dx: -0.5, dy: -0.5).contains(b), "\(c) draws outside the canvas: \(b)")
        // The sandalled feet stand on the shared anchor.
        let feet = layers.first { $0.name == "body" }!.shapes.map { $0.path.boundingRect }.reduce(CGRect.null) { $0.union($1) }
        #expect(abs(feet.maxY - AvatarRenderer.footAnchor.y) < 3)
    }

    @Test("Every single option renders inside the canvas, feet on the anchor")
    func everyOption() {
        let base = AvatarConfig()
        for v in SkinTone.allCases { var c = base; c.skin = v; check(c) }
        for v in HairStyle.allCases { var c = base; c.hair = v; c.head = .none; check(c) }
        for v in HairColour.allCases { var c = base; c.hairColour = v; check(c) }
        for v in BeardStyle.allCases { var c = base; c.beard = v; check(c) }
        for v in HeadCovering.allCases { var c = base; c.head = v; check(c) }
        for v in RobeStyle.allCases { var c = base; c.robe = v; check(c) }
        for v in SashStyle.allCases { var c = base; c.sash = v; check(c) }
        for v in CloakStyle.allCases { var c = base; c.cloak = v; check(c) }
        for v in HeldItem.allCases { var c = base; c.item = v; check(c) }
        for v in SandalColour.allCases { var c = base; c.sandals = v; check(c) }
    }

    @Test("Hundreds of random combinations render without trouble")
    func randomCombinations() {
        var g = SeededGenerator(seed: 7)
        for _ in 0..<300 { check(AvatarConfig.random(using: &g)) }
    }

    @Test("Every character preset renders")
    func presets() {
        for id in PresetAccess.ids { check(AvatarPresets.config(for: id)) }
        #expect(AvatarPresets.config(for: "solomon").head == .crown)
        #expect(AvatarPresets.config(for: "paul").hair == .baldWithSides)
    }

    @Test("Old or partial saved looks decode with sensible defaults")
    func decoding() throws {
        let empty = try JSONDecoder().decode(AvatarConfig.self, from: Data("{}".utf8))
        #expect(empty == AvatarConfig())
        let partial = try JSONDecoder().decode(AvatarConfig.self, from: Data(#"{"hair":"bald","robeColour":"sage","unknown":1}"#.utf8))
        #expect(partial.hair == .bald && partial.robeColour == .sage && partial.skin == AvatarConfig().skin)
        let bad = try JSONDecoder().decode(AvatarConfig.self, from: Data(#"{"hair":"mohawk"}"#.utf8))
        #expect(bad.hair == AvatarConfig().hair)
        let round = try JSONDecoder().decode(AvatarConfig.self, from: JSONEncoder().encode(AvatarPresets.config(for: "moses")))
        #expect(round == AvatarPresets.config(for: "moses"))
    }

    @Test("The first avatar carries over to the nearest new look")
    func migration() {
        let old = AvatarConfig.migrated(robe: "#93AECF", skin: "#5E3D28", hair: "headcloth", hairColor: "#E39A7E",
                                        sash: "#7A4A2A", sandals: "brown", beard: "long", covering: "legacy", coveringColor: "")
        #expect(old.robeColour == .skyBlue)
        #expect(old.skin == .deep)
        #expect(old.head == .veil)
        #expect(old.beard == .longFlowing)
        #expect(old.sash == .brownBelt)
    }
}

/// A repeatable random number generator for tests.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@MainActor
struct CrownTests {
    func reads(_ book: String, _ chapters: ClosedRange<Int>, times: Int) -> [ChapterRead] {
        (0..<times).flatMap { _ in chapters.map { ChapterRead(bookID: book, chapterNumber: $0) } }
    }

    @Test("The first full read earns no crown; each further full reread earns one")
    func crowns() {
        let once = GameProgress(reads: reads("ruth", 1...4, times: 1), quizzes: [], memorised: [])
        #expect(once.crownsEarned("ruth") == 0)
        let thrice = GameProgress(reads: reads("ruth", 1...4, times: 3), quizzes: [], memorised: [])
        #expect(thrice.crownsEarned("ruth") == 2)
        // A partial reread doesn't count.
        let partial = GameProgress(reads: reads("ruth", 1...4, times: 1) + reads("ruth", 1...3, times: 1), quizzes: [], memorised: [])
        #expect(partial.crownsEarned("ruth") == 0)
    }

    @Test("Each crown is announced once, and the throne room is announced when it appears")
    func notices() {
        let island = Island.build(chapters: (1...4).map { ("ruth", $0, Date()) }, quizzes: [], verses: [], features: [.library, .throne])
        let ids = Set(UnlockNotices.all(island: island, crowns: ["ruth": 2]).map(\.id))
        #expect(ids.isSuperset(of: ["crown:ruth:1", "crown:ruth:2", "throne"]))
        // The throne sits beyond everything on the Revelation (right) side.
        let throne = island.items.first { $0.kind == .throne }!
        let others = island.plots.map { $0.centre.x - $0.centre.y }
        #expect(others.allSatisfy { throne.gx - throne.gy > $0 })
    }
}
