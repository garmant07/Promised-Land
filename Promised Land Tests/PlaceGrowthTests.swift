import Testing
import Foundation
import CoreGraphics
@testable import Promised_Land

@MainActor
struct PlaceGrowthTests {
    let day: TimeInterval = 86_400
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    func reads(_ book: String, _ chapters: ClosedRange<Int>, times: Int = 1, from offset: Double = 0) -> [(book: String, chapter: Int, date: Date)] {
        (0..<times).flatMap { t in chapters.map { (book, $0, start.addingTimeInterval((offset + Double(t * 200 + $0)) * day)) } }
    }

    @Test("All 66 books have one Place, founded by its first piece, with captions and unique spots")
    func specs() {
        #expect(PlaceData.specs.count == 66)
        #expect(Set(PlaceData.specs.map(\.bookID)) == Set(BibleCatalog.books.map(\.id)))
        for spec in PlaceData.all {
            #expect(!spec.reviewed && !spec.reference.isEmpty && !spec.source.isEmpty)
            #expect(spec.pieces.first?.at == 0, "\(spec.bookID) is founded by its first piece")
            #expect(spec.pieces.allSatisfy { !$0.caption.isEmpty })
            #expect(spec.pieces.allSatisfy { !$0.isGrowable || $0.growCaption != nil || $0.cap == 1 })
            let spots = spec.pieces.map(\.spot).filter { $0 != .centre }
            #expect(Set(spots).count == spots.count, "\(spec.bookID) has two pieces on one spot")
        }
    }

    @Test("Every chapter of every book visibly adds to its Place (no chapter adds nothing)")
    func everyChapterGrows() {
        for book in BibleCatalog.books {
            let spec = PlaceData.spec(for: book.id)
            #expect(!PlaceGrowth.after(0, spec: spec, chapters: book.chapterCount).isFounded)
            var previous = PlaceGrowth.after(0, spec: spec, chapters: book.chapterCount)
            for n in 1...book.chapterCount {
                let now = PlaceGrowth.after(n, spec: spec, chapters: book.chapterCount)
                #expect(now.isFounded)
                #expect(now != previous, "\(book.name) \(n) added nothing")
                let grewPiece = now.pieces.indices.contains { i in (now.pieces[i] ?? 0) > (previous.pieces[i] ?? 0) }
                let flourished = now.flourish > previous.flourish && now.flourish <= PlaceGrowth.flourishCap
                #expect(grewPiece || flourished, "\(book.name) \(n): nothing visible changed")
                for (i, g) in now.pieces.enumerated() { if let g { #expect(g <= spec.pieces[i].cap) } }
                previous = now
            }
            // Every piece is built by the time the book is finished.
            #expect(previous.pieces.allSatisfy { $0 != nil }, "\(book.name) leaves a piece unbuilt")
        }
    }

    @Test("Ruth: the farmstead founds at chapter 1 and the barn comes at chapter 2")
    func ruthSteps() {
        let spec = PlaceData.spec(for: "ruth")
        let one = PlaceGrowth.after(1, spec: spec, chapters: 4)
        #expect(one.pieces[0] == 1 && one.pieces[1] == 1) // farmhouse and the wheat patch
        let two = PlaceGrowth.after(2, spec: spec, chapters: 4)
        #expect(two.lastPieces.map { spec.pieces[$0].kind } == [.barn])
    }

    @Test("Rereads raise richness without adding land or moving anything")
    func rereads() {
        let once = Island.build(chapters: reads("ruth", 1...4), quizzes: [], verses: [])
        let thrice = Island.build(chapters: reads("ruth", 1...4, times: 3), quizzes: [], verses: [])
        #expect(once.tiles.count == thrice.tiles.count && once.plots == thrice.plots)
        #expect(once.items.map { "\($0.gx),\($0.gy)" } == thrice.items.map { "\($0.gx),\($0.gy)" })
        #expect(once.items.first { if case .piece = $0.kind { true } else { false } }?.level == 1)
        #expect(thrice.items.first { if case .piece = $0.kind { true } else { false } }?.level == 3)
        #expect(PlaceGrowth.richness(totalReads: 99, chapters: 4) == 5)
    }

    @Test("Reads waiting for their reading check don't build yet")
    func unchecked() {
        let r = reads("ruth", 1...4)
        let waiting = Island.build(chapters: r, quizzes: [], verses: [], unchecked: [("ruth", 4)])
        #expect(waiting.growth["ruth"]?.pieces.last == nil || waiting.growth["ruth"]?.pieces.last! == nil)
        let checked = Island.build(chapters: r, quizzes: [], verses: [])
        #expect(checked.growth["ruth"]?.pieces.allSatisfy { $0 != nil } == true)
    }

    @Test("A passed quiz raises a banner, a memorised verse a lantern or fruit tree")
    func rewards() {
        let island = Island.build(chapters: reads("ruth", 1...1), quizzes: [("ruth", start)], verses: [("ruth", start)])
        let kinds = island.items.map(\.kind)
        #expect(kinds.contains(.reward(.banner)))
        #expect(kinds.contains(.reward(RewardData.verse(for: "ruth"))))
    }

    @Test("Tree chapters grow the shared forest")
    func forest() {
        let none = Island.build(chapters: reads("ruth", 1...4), quizzes: [], verses: [])
        #expect(none.forest == nil)
        let some = Island.build(chapters: reads("genesis", 1...3) + reads("psalms", 1...1, from: 10), quizzes: [], verses: [])
        #expect(some.forest != nil)
        #expect(some.items.filter { $0.kind == .tree }.count == 2 * ForestData.treesPerChapter)
        for entry in ForestData.chapters {
            #expect(!entry.reviewed)
            #expect(BibleCatalog.book(id: entry.bookID).map { (1...$0.chapterCount).contains(entry.chapter) } == true)
        }
    }

    @Test("A Place's card says how far it has grown")
    func placeText() {
        #expect(InsightSubject.placeText(bookID: "ruth", read: 2, total: 4, richness: 1).contains("2 of 4"))
        #expect(InsightSubject.placeText(bookID: "ruth", read: 4, total: 4, richness: 1).hasPrefix("Complete"))
        #expect(InsightSubject.placeText(bookID: "ruth", read: 4, total: 4, richness: 3).contains("richness 3"))
    }

    @Test("Completing a Place and each richer level are announced; growing ones aren't")
    func notices() {
        let partial = Island.build(chapters: reads("ruth", 1...2), quizzes: [], verses: [])
        #expect(UnlockNotices.all(island: partial).isEmpty)
        let done = Island.build(chapters: reads("ruth", 1...4, times: 3), quizzes: [("ruth", start)], verses: [], features: [.library])
        let ids = Set(UnlockNotices.all(island: done).map(\.id))
        #expect(ids.isSuperset(of: ["built:ruth", "floor:ruth:2", "floor:ruth:3", "reward:ruth:banner", "library"]))
        for n in UnlockNotices.all(island: done) { if let i = n.itemIndex { #expect(done.items.indices.contains(i)) } }
    }

    @Test("What can I build? lists what grows in a Place")
    func catalogue() {
        #expect(BuildPreview.artifactLine("ruth").contains("the barn is built"))
        #expect(BuildPreview.characterLine("exodus") == "Counts toward Moses's journey")
    }

    @Test("One Place on its own (for its inside page) has all its pieces")
    func single() {
        let island = Island.single(bookID: "ruth", distinct: 4, totalReads: 4)
        #expect(island.items.count == PlaceData.spec(for: "ruth").pieces.count)
    }
}

@MainActor
struct PlacementTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    func island(_ books: [String], placements: [String: IslandPlacement] = [:]) -> Island {
        Island.build(chapters: books.enumerated().map { ($1, 1, start.addingTimeInterval(Double($0) * 3600)) },
                     quizzes: [], verses: [], features: [.library], placements: placements)
    }

    func connected(_ i: Island) -> Bool {
        let land = Set(i.tiles)
        var seen: Set<Island.Tile> = [i.tiles[0]]
        var queue = [i.tiles[0]]
        while let t = queue.popLast() {
            for n in [Island.Tile(x: t.x + 1, y: t.y), Island.Tile(x: t.x - 1, y: t.y), Island.Tile(x: t.x, y: t.y + 1), Island.Tile(x: t.x, y: t.y - 1)]
            where land.contains(n) && seen.insert(n).inserted { queue.append(n) }
        }
        return seen.count == land.count
    }

    @Test("All 66 Places: deterministic, never overlapping, with breathing room, on one piece of land")
    func wholeBible() {
        let ids = BibleCatalog.books.map(\.id)
        let a = island(ids), b = island(ids)
        #expect(a.plots == b.plots && a.roads == b.roads)
        #expect(a.plots.count == 66)
        let rects = a.allPlots.map(\.rect)
        for x in rects.indices { for y in rects.indices where x < y { #expect(!rects[x].insetBy(dx: -0.5, dy: -0.5).intersects(rects[y])) } }
        #expect(connected(a))
        let land = Set(a.tiles)
        for plot in a.allPlots {
            for ty in plot.y..<(plot.y + plot.size) { for tx in plot.x..<(plot.x + plot.size) { #expect(land.contains(Island.Tile(x: tx, y: ty))) } }
        }
    }

    @Test("Places stay put as more is read")
    func stable() {
        let first = island(["ruth", "john"])
        let later = island(["ruth", "john", "genesis", "acts", "psalms", "jonah"])
        for plot in first.plots { #expect(later.plots.contains(plot)) }
    }

    @Test("Old Testament Places lean left, New Testament Places lean right")
    func lean() {
        let i = island(["genesis", "matthew", "exodus", "mark", "psalms", "luke", "isaiah", "romans"])
        func mean(_ t: Testament) -> CGFloat {
            let ps = i.plots.filter { BibleCatalog.book(id: $0.bookID)?.testament == t }.map { $0.centre.y - $0.centre.x }
            return ps.reduce(0, +) / CGFloat(ps.count)
        }
        #expect(mean(.old) > mean(.new))
    }

    @Test("Waterside Places sit on the coast, beside a bay of open water")
    func waterside() {
        let i = island(["genesis", "john", "ruth", "jonah", "mark", "acts"])
        let land = Set(i.tiles)
        #expect(i.water.allSatisfy { !land.contains($0) })
        for id in ["john", "jonah", "mark"] {
            let plot = i.plots.first { $0.bookID == id }!
            #expect(plot.bay != nil, "\(id) has a bay")
            let bay = IslandPlacer.bay(x: plot.x, y: plot.y, size: plot.size, side: plot.bay!)
            #expect(bay.allSatisfy { i.water.contains($0) })
        }
    }

    @Test("Roads join every Place to the island, over land")
    func roads() {
        let i = island(["genesis", "john", "ruth", "jonah", "acts", "psalms", "romans"])
        #expect(i.roads.count == i.allPlots.count) // each Place and the forest, plus the Library to the start
        let land = Set(i.tiles)
        for road in i.roads {
            #expect(road.count >= 2)
            #expect(road.allSatisfy { land.contains($0) })
            for (a, b) in zip(road, road.dropFirst()) { #expect(abs(a.x - b.x) + abs(a.y - b.y) <= 1) }
        }
    }

    @Test("All the roads are one connected network, and every walk to the Library steps tile by tile")
    func roadsConnect() {
        for island in [island(["genesis", "john", "ruth", "jonah", "acts", "psalms", "romans"]),
                       Island.build(chapters: FullBiblePreviewData.reads, quizzes: [], verses: [], features: [.library, .throne],
                                    richnessOverride: 5)] {
            // Road tiles form a single piece (4-way neighbours).
            let tiles = Set(island.roads.flatMap { $0 })
            var seen: Set<Island.Tile> = [], pieces = 0
            for t in tiles where !seen.contains(t) {
                pieces += 1
                var stack = [t]
                seen.insert(t)
                while let c = stack.popLast() {
                    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                        let n = Island.Tile(x: c.x + dx, y: c.y + dy)
                        if tiles.contains(n), seen.insert(n).inserted { stack.append(n) }
                    }
                }
            }
            #expect(pieces == 1)
            // Every Place's walk to the Library exists and never jumps (no gliding through buildings).
            for plot in island.plots {
                let walk = island.routeToLibrary(from: plot.bookID)
                #expect(!walk.isEmpty, "\(plot.bookID) has no road to the Library")
                for (a, b) in zip(walk, walk.dropFirst()) { #expect(abs(a.x - b.x) + abs(a.y - b.y) == 1, "\(plot.bookID)") }
                if let library = island.library { #expect(library.rect.contains(CGPoint(x: CGFloat(walk.last!.x) + 0.5, y: CGFloat(walk.last!.y) + 0.5))) }
            }
            // Travellers' roads never jump either.
            for t in Traveller.make(island: island) {
                for (a, b) in zip(t.road, t.road.dropFirst()) { #expect(abs(a.x - b.x) + abs(a.y - b.y) <= 1) }
            }
        }
    }

    @Test("A Place you moved stays exactly there; others avoid it and roads follow it")
    func moved() {
        let auto = island(["ruth", "john", "jonah", "acts"])
        let moved = island(["ruth", "john", "jonah", "acts", "genesis"], placements: ["ruth": IslandPlacement(x: 14, y: -12, moved: true)])
        let ruth = moved.plots.first { $0.bookID == "ruth" }!
        #expect(ruth.x == 14 && ruth.y == -12)
        #expect(moved.conflicts.isEmpty)
        for p in moved.plots where p.bookID != "ruth" { #expect(!p.rect.insetBy(dx: -0.5, dy: -0.5).intersects(ruth.rect)) }
        #expect(moved.roads != auto.roads)
        // Ruth's pieces moved with her Place.
        let piece = moved.items.first { $0.source == .place(book: "ruth", piece: 0) }!
        #expect(ruth.rect.contains(CGPoint(x: piece.gx, y: piece.gy)))
    }

    @Test("Overlapping a saved place is flagged, so it can't be dropped there")
    func overlap() {
        let auto = island(["ruth", "john"])
        let john = auto.plots.first { $0.bookID == "john" }!
        var frozen = auto.placements
        frozen["ruth"] = IslandPlacement(x: john.x + 1, y: john.y, moved: true)
        #expect(!island(["ruth", "john"], placements: frozen).conflicts.isEmpty)
    }

    @Test("Tidy up re-places only unmoved Places")
    func tidy() {
        let auto = island(["ruth", "john", "acts"])
        var frozen = auto.placements
        frozen["ruth"] = IslandPlacement(x: 16, y: 16, moved: true)
        let tidied = island(["ruth", "john", "acts"], placements: frozen.filter { $0.value.moved })
        #expect(tidied.plots.first { $0.bookID == "ruth" }.map { $0.x == 16 && $0.y == 16 } == true)
        #expect(tidied.conflicts.isEmpty)
    }

    @Test("Turning a Place turns its layout but keeps every piece inside it")
    func turned() {
        let flat = island(["genesis"], placements: ["genesis": IslandPlacement(x: 20, y: 20)])
        let turned = island(["genesis"], placements: ["genesis": IslandPlacement(x: 20, y: 20, rotation: 1)])
        let a = flat.items.first { $0.source == .place(book: "genesis", piece: 2) }
        let b = turned.items.first { $0.source == .place(book: "genesis", piece: 2) }
        #expect(a == nil && b == nil) // only chapter 1 read: later pieces not yet built
        let tf = Island.build(chapters: (1...10).map { ("genesis", $0, start) }, quizzes: [], verses: [],
                              placements: ["genesis": IslandPlacement(x: 20, y: 20, rotation: 1)])
        let size = PlaceData.spec(for: "genesis").size
        for item in tf.items { guard case .place("genesis", _) = item.source else { continue }
            #expect(CGRect(x: 20, y: 20, width: size, height: size).contains(CGPoint(x: item.gx, y: item.gy)))
            #expect(item.turned == 1)
        }
    }

    @Test("Taps pick a Place's piece when the island is turned", arguments: [0, 1, 2, 3])
    func tapsWhenTurned(quarter: Int) {
        let i = Island.build(chapters: [("ruth", 1, start)], quizzes: [], verses: [])
        let layout = IslandLayout(island: i, size: CGSize(width: 390, height: 844), zoom: 3, angle: CGFloat(quarter))
        let index = i.items.firstIndex { $0.kind == .piece(.farmhouse) }!
        let b = i.items[index]
        let hit = IslandHitTester.hit(point: layout.point(b.gx, b.gy), layout: layout, items: i.items)
        #expect(hit.map { i.items[$0].source.bookID } == "ruth")
    }
}
