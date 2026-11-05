import Testing
import Foundation
import CoreGraphics
@testable import Promised_Land

@MainActor
struct LibraryTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    /// The first `n` books read in full, a book a day (in canon order).
    func reads(books n: Int) -> [(book: String, chapter: Int, date: Date)] {
        BibleCatalog.books.prefix(n).enumerated().flatMap { i, book in
            book.chapterNumbers.map { (book.id, $0, start.addingTimeInterval(Double(i) * 86_400 + Double($0))) }
        }
    }

    /// Chapters read until the Library reaches a stage (books in canon order, a chapter a minute).
    func reads(toReach stage: LibraryStage) -> [(book: String, chapter: Int, date: Date)] {
        Array(FullBiblePreviewData.reads.prefix(stage.threshold))
    }

    func library(_ island: Island) -> Island.Item? { island.index(of: .library).map { island.items[$0] } }

    func overlaps(_ a: Island.Plot, _ b: Island.Plot, gap: Int = 0) -> Bool {
        IslandPlacer.overlaps((a.x, a.y, a.size), (b.x, b.y, b.size), gap: gap)
    }

    @Test("Growth counts volumes and notes, and rebuilds the same stage from history")
    func stagesFromHistory() {
        #expect(LibraryGrowth(volumes: 0, notes: 0).stage == .hut)
        #expect(LibraryGrowth(volumes: 11, notes: 0).stage == .hut)
        #expect(LibraryGrowth(volumes: 10, notes: 1).stage == .room) // 10 + 2 × 1
        #expect(LibraryGrowth(volumes: 1189, notes: 0).stage == .grand)
        #expect(LibraryGrowth(volumes: 0, notes: 3).touches.contains(.writingDesk))
        #expect(LibraryGrowth(volumes: 20, notes: 0).touches.contains(.bench))
        for stage in LibraryStage.allCases {
            let island = Island.build(chapters: reads(toReach: stage), quizzes: [], verses: [], features: [.library])
            #expect(island.libraryGrowth.stage == stage)
            #expect(library(island).map(LibraryArt.stage) == stage)
        }
        // Journal entries count too: 40 chapters and 5 notes is 50 points (wings).
        let island = Island.build(chapters: Array(FullBiblePreviewData.reads.prefix(40)), quizzes: [], verses: [],
                                  features: [.library], journalNotes: 5)
        #expect(island.libraryGrowth.stage == .wings)
        // Unchecked reads don't count yet.
        let waiting = Island.build(chapters: Array(FullBiblePreviewData.reads.prefix(12)), quizzes: [], verses: [], features: [.library],
                                   unchecked: [("genesis", 12)])
        #expect(waiting.libraryGrowth.stage == .hut)
    }

    @Test("Its footprint and height grow with every stage")
    func footprintGrows() {
        var lastSize = 0, lastHeight: CGFloat = 0
        for stage in LibraryStage.allCases {
            #expect(stage.size > lastSize)
            #expect(LibraryArt.size(stage).height > lastHeight)
            lastSize = stage.size
            lastHeight = LibraryArt.size(stage).height
            let island = Island.build(chapters: reads(toReach: stage), quizzes: [], verses: [], features: [.library])
            #expect(island.library?.size == stage.size)
        }
        // The grand library is the biggest thing on the island.
        let full = Island.build(chapters: FullBiblePreviewData.reads, quizzes: [], verses: [], features: [.library, .throne])
        #expect((full.library?.size ?? 0) > (full.plots.map(\.size).max() ?? 0))
    }

    @Test("It never overlaps anything, at any stage, and never covers the plaza")
    func neverOverlaps() {
        let plaza = Island.Plot(bookID: "plaza", x: IslandPlacer.start.x, y: IslandPlacer.start.y, size: IslandPlacer.start.size)
        for n in [1, 3, 8, 20, 40, 66] {
            let island = Island.build(chapters: reads(books: n), quizzes: [], verses: [], features: [.library])
            guard let lib = island.library else { Issue.record("no library"); continue }
            #expect(!overlaps(lib, plaza, gap: 1))
            for plot in island.plots + (island.forest.map { [$0] } ?? []) {
                #expect(!overlaps(lib, plot, gap: 1), "Library overlaps \(plot.bookID) with \(n) books")
            }
            for t in island.water {
                #expect(!overlaps(lib, Island.Plot(bookID: "bay", x: t.x, y: t.y, size: 1)))
            }
            #expect(island.conflicts.isEmpty)
        }
    }

    @Test("It grows around things you moved yourself, which stay exactly where you put them")
    func respectsUserMoved() {
        let chapters = reads(toReach: .grand)
        // A Place moved by hand right where the grand library would grow.
        let grand = LibraryFootprint.rect(hutX: IslandPlacer.library.x, hutY: IslandPlacer.library.y, size: LibraryStage.grand.size)
        let spot = IslandPlacement(x: grand.x, y: grand.y, rotation: 0, moved: true)
        let island = Island.build(chapters: chapters, quizzes: [], verses: [], features: [.library], placements: ["ruth": spot])
        guard let ruth = island.plots.first(where: { $0.bookID == "ruth" }), let lib = island.library else {
            Issue.record("missing plots"); return
        }
        #expect(ruth.x == spot.x && ruth.y == spot.y)
        #expect(!overlaps(lib, ruth, gap: 1))
        #expect(!island.conflicts.contains("ruth"))
        // It still covers its hut.
        #expect(lib.x <= IslandPlacer.library.x && lib.y <= IslandPlacer.library.y)
        #expect(lib.x + lib.size >= IslandPlacer.library.x + 2 && lib.y + lib.size >= IslandPlacer.library.y + 2)
    }

    @Test("Auto-placed Places in its way are nudged outward; the rest stay put")
    func nudgesOnlyWhatsInTheWay() {
        let hut = Island.build(chapters: reads(books: 6), quizzes: [], verses: [], features: [.library])
        #expect(hut.libraryGrowth.stage >= .wings)
        let small = Island.build(chapters: reads(books: 6), quizzes: [], verses: [], features: [])
        // Saved (but not moved) spots, as edit mode saves them.
        var saved: [String: IslandPlacement] = [:]
        for p in small.plots { saved[p.bookID] = IslandPlacement(x: p.x, y: p.y, rotation: 0, moved: false) }
        let grown = Island.build(chapters: reads(books: 6), quizzes: [], verses: [], features: [.library], placements: saved)
        guard let lib = grown.library else { Issue.record("no library"); return }
        for p in grown.plots {
            let old = small.plots.first { $0.bookID == p.bookID }!
            let wasInTheWay = overlaps(lib, old, gap: 1)
            if wasInTheWay {
                #expect(!overlaps(lib, p, gap: 1))
            } else {
                #expect(p.x == old.x && p.y == old.y, "\(p.bookID) moved though it wasn't in the way")
            }
        }
        #expect(grown.conflicts.isEmpty)
    }

    @Test("Every Place's road leads to the Library")
    func roadsLeadToTheLibrary() {
        let island = Island.build(chapters: reads(books: 20), quizzes: [], verses: [], features: [.library])
        guard let lib = island.library else { Issue.record("no library"); return }
        for plot in island.plots {
            let route = island.routeToLibrary(from: plot.bookID)
            #expect(!route.isEmpty, "no road from \(plot.bookID)")
            if let last = route.last {
                #expect(IslandPlacer.overlaps((last.x, last.y, 1), (lib.x, lib.y, lib.size), gap: 0))
            }
        }
    }

    @Test("The Library growing plays a reveal with its caption")
    func reveal() {
        let island = Island.build(chapters: reads(toReach: .tower), quizzes: [], verses: [], features: [.library])
        let step = RevealPlanner.libraryStep(island: island, seen: .upperFloor)
        #expect(step?.kind == .library)
        #expect(step?.caption == "Your library added a reading tower")
        #expect(step?.changes.first?.from == CGFloat(LibraryStage.upperFloor.rawValue + 1))
        #expect(RevealPlanner.libraryStep(island: island, seen: .tower) == nil)
    }

    @Test("Edit mode: dropping a Place on the Library is a conflict, and doesn't shrink it")
    func editModeConflict() {
        let chapters = reads(toReach: .wings)
        let base = Island.build(chapters: chapters, quizzes: [], verses: [], features: [.library])
        guard let lib = base.library, let first = base.plots.first else { Issue.record("missing"); return }
        var draft = base.placements
        draft[first.bookID] = IslandPlacement(x: lib.x, y: lib.y, rotation: 0, moved: true)
        let editing = Island.build(chapters: chapters, quizzes: [], verses: [], features: [.library], placements: draft,
                                   libraryAvoid: [:])
        #expect(editing.library?.size == lib.size)
        #expect(editing.conflicts.contains(first.bookID))
        // The Library's placement is its hut, so moving it moves the whole building.
        #expect(base.placements[IslandPlacement.libraryKey]?.x == IslandPlacer.library.x)
    }
}
