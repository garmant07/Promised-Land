import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import Promised_Land

@MainActor
struct GenesisSceneTests {
    private let sceneBookIDs = [
        "genesis", "exodus", "leviticus", "numbers", "deuteronomy", "joshua", "judges",
        "ruth", "1samuel", "2samuel", "1kings", "2kings", "1chronicles", "2chronicles",
        "ezra", "nehemiah", "esther", "job"
    ]

    @Test("Every bundled scene passes the generic layout checks")
    func everyScenePassesGenericChecks() {
        for bookID in sceneBookIDs {
            guard let layout = SceneLayoutLoader.load(bookID: bookID),
                  let book = BibleCatalog.book(id: bookID) else {
                Issue.record("Missing scene or catalog entry for \(bookID)")
                continue
            }
            #expect(layout.book.lowercased().replacingOccurrences(of: " ", with: "") == bookID)
            #expect(layout.chapters == book.chapterCount)
            #expect(!layout.events(at: 0).isEmpty == false)
            #expect(Set(layout.events.map(\.chapter)) == Set(book.chapterNumbers))
            for chapter in book.chapterNumbers {
                let chapterEvents = layout.events.filter { $0.chapter == chapter }
                #expect(!chapterEvents.isEmpty)
                #expect(Set(chapterEvents.map(\.slot)).count == chapterEvents.count)
            }
            for event in layout.events {
                #expect((0...1).contains(event.u))
                #expect((0...1).contains(event.v))
                if event.action == "grow" {
                    #expect(layout.events.contains {
                        $0.slot == event.slot && $0.chapter <= event.chapter && $0 != event
                    })
                }
                let art = ArtAssets.image(event.sprite)
                #expect(art != nil)
                #expect(art?.image.width == 256)
                #expect(art?.image.height == 384)
            }
            #expect(layout.events(at: book.chapterCount + 1) == layout.events(at: book.chapterCount))
        }
    }

    @Test("Several events in one chapter are allowed without reusing a slot")
    func multipleEventsInOneChapter() {
        let multiEventLayouts = sceneBookIDs.compactMap { SceneLayoutLoader.load(bookID: $0) }
            .filter { layout in
                layout.events.filter { $0.chapter == 1 }.count > 1
            }
        #expect(!multiEventLayouts.isEmpty)
        for layout in multiEventLayouts {
            let chapterOne = layout.events.filter { $0.chapter == 1 }
            #expect(Set(chapterOne.map(\.slot)).count == chapterOne.count)
        }
    }

    @Test("Genesis stage 0 and final stage remain stable")
    func genesisStagesRemainStable() {
        let layout = SceneLayoutLoader.load(bookID: "genesis")!
        #expect(layout.events(at: 0).isEmpty)
        #expect(layout.events(at: 51) == layout.events(at: 50))
        #expect(layout.events(at: 500) == layout.events(at: 50))
    }

    @Test("Scene books use their own chapter count for stage")
    func sceneStageUsesLayoutChapterCount() {
        let island = Island.single(bookID: "ruth", distinct: 4, totalReads: 4)
        let item = island.items[0]
        #expect(SceneSystem.stage(for: item) == 4)
        #expect(SceneLayoutLoader.load(bookID: "ruth")!.events(at: 5) ==
                SceneLayoutLoader.load(bookID: "ruth")!.events(at: 4))
    }

    @Test("Ruth is a scene book with one book-level hit item")
    func ruthSceneHitItem() {
        let island = Island.single(bookID: "ruth", distinct: 4, totalReads: 4)
        let layout = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 3)
        let item = island.items[0]
        #expect(item.source.bookID == "ruth")
        #expect(IslandPainter.artRegion(of: item, layout: layout)?.parts.count ==
                SceneSystem.activeEvents(for: item).count)
    }

    @Test("Scene cache keys include book and stage")
    func sceneCacheKeysIncludeBookAndStage() {
        let ruth = Island.single(bookID: "ruth", distinct: 4, totalReads: 4)
        let job = Island.single(bookID: "job", distinct: 4, totalReads: 4)
        let ruthLayout = IslandLayout(island: ruth, size: CGSize(width: 390, height: 844), zoom: 2)
        let jobLayout = IslandLayout(island: job, size: CGSize(width: 390, height: 844), zoom: 2)
        let ruthKey = IslandRenderCache.shared.cacheKeyForTesting(ruth.items[0], layout: ruthLayout)
        let jobKey = IslandRenderCache.shared.cacheKeyForTesting(job.items[0], layout: jobLayout)
        #expect(ruthKey != jobKey)
        var later = ruth.items[0]
        later.progress = 3
        #expect(ruthKey != IslandRenderCache.shared.cacheKeyForTesting(later, layout: ruthLayout))
    }

    @Test("Automatic tall rule keeps grass low and raises temple or house art")
    func automaticTallRule() {
        let exodus = Island.single(bookID: "exodus", distinct: 40, totalReads: 40).items[0]
        let grass = SceneLayoutLoader.load(bookID: "exodus")!.events.first { $0.sprite == "obj_grass" }!
        #expect(SceneSystem.isTall(grass, item: exodus) == false)

        let kings = Island.single(bookID: "1kings", distinct: 22, totalReads: 22).items[0]
        let temple = SceneLayoutLoader.load(bookID: "1kings")!.events.first { $0.sprite == "obj_1kings_temple_1" }!
        #expect(SceneSystem.isTall(temple, item: kings))
    }

    @Test("Genesis authored tall events remain tall at their largest drawn width")
    func genesisAuthoredTallEventsRemainTall() {
        let layout = SceneLayoutLoader.load(bookID: "genesis")!
        let item = Island.single(bookID: "genesis", distinct: 50, totalReads: 50).items[0]
        for sprite in Set(layout.events.filter { $0.tall == true }.map(\.sprite)) {
            let event = layout.events.filter { $0.sprite == sprite }.max { $0.width < $1.width }!
            #expect(SceneSystem.isTall(event, item: item))
        }
    }

    @Test("Ruth chapter 1 contains three simultaneous scene slots")
    func ruthChapterOnePopsThreeSlots() {
        let layout = SceneLayoutLoader.load(bookID: "ruth")!
        #expect(layout.events.filter { $0.chapter == 1 }.count == 3)
        #expect(layout.events(at: 1).count == 3)
    }

    @Test("A chapter can grow one slot and add others together")
    func chapterCanGrowAndAddTogether() {
        let layout = SceneLayoutLoader.load(bookID: "ruth")!
        let previous = Dictionary(uniqueKeysWithValues: layout.events(at: 1).map { ($0.slot, $0) })
        let current = Dictionary(uniqueKeysWithValues: layout.events(at: 2).map { ($0.slot, $0) })
        #expect(current["NH"]?.action == "grow")
        #expect(current["NH"]?.sprite != previous["NH"]?.sprite)
        #expect(current["BF"]?.action == "add")
        #expect(current["SH"]?.action == "add")
    }

    @Test("Genesis hit bounds and masks still use individual sprite regions")
    func genesisHitRegionsRemainIndividual() {
        let island = Island.single(bookID: "genesis", distinct: 50, totalReads: 50)
        let layout = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 3)
        let item = island.items[0]
        let region = IslandPainter.artRegion(of: item, layout: layout)
        #expect(region?.parts.count == SceneSystem.activeEvents(for: item).count)
        #expect(region?.parts.contains { $0.alpha?.contains(0) == true } == true)
    }

    @Test("Scene shadow metadata remains decoded without rendering shadows")
    func sceneShadowMetadataRemainsDecoded() {
        let genesis = SceneLayoutLoader.load(bookID: "genesis")!
        let visibleGenesis = genesis.events(at: genesis.chapters).filter { $0.sprite != "obj_butterflies" }
        #expect(visibleGenesis.allSatisfy { $0.shadowWidth == nil })

        let ruth = SceneLayoutLoader.load(bookID: "ruth")!
        #expect(ruth.events.contains { $0.shadowWidth != nil })
    }

    @Test("Scene picture keys ignore camera pan and use a scale bucket")
    func scenePictureKeyIsStableWithinBucket() {
        let cache = IslandRenderCache.shared
        let first = cache.scenePictureKeyForTesting(bookID: "ruth", stage: 4, scale: 1.01, layoutIdentity: "ruth-4-10")
        let second = cache.scenePictureKeyForTesting(bookID: "ruth", stage: 4, scale: 1.20, layoutIdentity: "ruth-4-10")
        let differentStage = cache.scenePictureKeyForTesting(bookID: "ruth", stage: 3, scale: 1.01, layoutIdentity: "ruth-4-10")
        #expect(first == second)
        #expect(first != differentStage)
    }

    @Test("Rendering the same scene twice is a cache hit")
    func scenePictureRendersOnce() {
        let cache = IslandRenderCache.shared
        let oldEnabled = PerfProbe.enabled
        cache.removeAll()
        PerfProbe.enabled = true
        defer {
            PerfProbe.enabled = oldEnabled
            cache.removeAll()
        }

        let island = Island.single(bookID: "genesis", distinct: 50, totalReads: 50)
        let size = CGSize(width: 390, height: 844)
        #expect(cache.prewarmScenes(island: island, size: size, insets: EdgeInsets(), zoom: 3, pan: .zero))
        let afterFirst = cache.renders
        #expect(afterFirst > 0)
        #expect(cache.prewarmScenes(island: island, size: size, insets: EdgeInsets(), zoom: 3, pan: CGSize(width: 120, height: -80)))
        #expect(cache.renders == afterFirst)
    }

    @Test("Scene bucket pictures are never enlarged beyond their made size")
    func sceneBucketNeverUpscalesTooFar() {
        for u in stride(from: CGFloat(0.05), through: 20, by: 0.01) {
            let made = IslandRenderCache.sizeBucket(u)
            #expect(u / made <= 1.5)
        }
    }

    @Test("Scene redraw depth is in the same local coordinates as the scene")
    func sceneRedrawUsesSceneDepth() {
        let island = Island.single(bookID: "ruth", distinct: 4, totalReads: 4)
        let layout = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 4)
        let item = island.items[0]
        let feet = layout.point(item.gx + item.span * 0.5, item.gy + item.span * 0.5)
        let depth = IslandWorld.sceneDepth(for: feet, item: item, layout: layout)
        #expect(abs(depth - 2) < 0.0001)
        #expect(SceneLayoutLoader.load(bookID: "ruth")!.events(at: 4).map { $0.u + $0.v } ==
                SceneLayoutLoader.load(bookID: "ruth")!.events(at: 4).map { $0.u + $0.v }.sorted())
    }

    @Test("Every scene's transparent art outside its plot selects nothing")
    func sceneTransparentAreaDoesNotSelectPlace() {
        for bookID in sceneBookIDs {
            let island = Island.single(bookID: bookID, distinct: BibleCatalog.book(id: bookID)!.chapterCount,
                                       totalReads: BibleCatalog.book(id: bookID)!.chapterCount)
            let layout = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 4)
            let item = island.items[0]
            let plot = island.plots[0]
            guard let region = IslandPainter.artRegion(of: item, layout: layout),
                  let point = transparentPoint(region: region, plot: plot, layout: layout) else {
                Issue.record("Could not find transparent scene art outside the plot for \(bookID)")
                continue
            }
            #expect(IslandHitTester.hit(point: point, layout: layout, items: island.items, plots: island.plots) == nil,
                    "\(bookID) selected at \(point)")
        }
    }

    @Test("Every scene's land selects its own Place")
    func sceneLandSelectsBook() {
        for bookID in sceneBookIDs {
            let book = BibleCatalog.book(id: bookID)!
            let island = Island.single(bookID: bookID, distinct: book.chapterCount, totalReads: book.chapterCount)
            let layout = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 4)
            let plot = island.plots[0]
            let point = layout.point(CGFloat(plot.x) + 0.5, CGFloat(plot.y) + 0.5)
            #expect(IslandHitTester.hit(point: point, layout: layout, items: island.items, plots: island.plots) == 0,
                    "\(bookID) land did not select its Place")
            #expect(island.items[0].source.bookID == bookID)
        }
    }

    @Test("Every scene hides a walker behind a tall piece")
    func sceneWalkerBehindTallPieceIsCovered() {
        for bookID in sceneBookIDs {
            let book = BibleCatalog.book(id: bookID)!
            let island = Island.single(bookID: bookID, distinct: book.chapterCount, totalReads: book.chapterCount)
            let layout = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 4)
            let item = island.items[0]
            let bounds = IslandPainter.drawnBounds(of: item, layout: layout)
            guard let figure = sceneFigure(item: item, layout: layout, bounds: bounds, behind: true) else {
                Issue.record("Could not find a behind position for \(bookID)")
                continue
            }
            let entries = [(item: item, bounds: bounds)]
            #expect(IslandWorld.itemsOver(figure, items: entries, layout: layout) == [0])
        }
    }

    @Test("Every scene leaves a walker in front of a piece uncovered")
    func sceneWalkerInFrontOfPieceIsNotCovered() {
        for bookID in ["genesis", "ruth", "exodus"] {
            let book = BibleCatalog.book(id: bookID)!
            let island = Island.single(bookID: bookID, distinct: book.chapterCount, totalReads: book.chapterCount)
            let layout = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 4)
            let item = island.items[0]
            let bounds = IslandPainter.drawnBounds(of: item, layout: layout)
            let setup = sceneFrontFigure(item: item, layout: layout)
            let figure = setup.figure
            let depth = IslandWorld.sceneDepth(for: figure.feet, item: item, layout: layout)
            let redraw = SceneSystem.activeEvents(for: item).filter { $0.u + $0.v > depth }
            #expect(figure.rect.intersects(bounds))
            #expect(depth > setup.piece.u + setup.piece.v)
            #expect(!redraw.contains(setup.piece))
            #expect(!redraw.isEmpty)
            let entries = [(item: item, bounds: bounds)]
            #expect(IslandWorld.itemsOver(figure, items: entries, layout: layout) == [0])
        }
    }

    private func transparentPoint(region: HitRegion, plot: Island.Plot, layout: IslandLayout) -> CGPoint? {
        for row in 0...64 {
            for column in 0...64 {
                let point = CGPoint(x: region.bounds.minX + region.bounds.width * CGFloat(column) / 64,
                                    y: region.bounds.minY + region.bounds.height * CGFloat(row) / 64)
                if !plot.rect.contains(layout.grid(point)) && !region.contains(point) {
                    return point
                }
            }
        }
        return nil
    }

    private func sceneFigure(item: Island.Item, layout: IslandLayout, bounds: CGRect, behind: Bool) -> IslandWorld.Figure? {
        for dx in stride(from: -2.0, through: 2.0, by: 0.1) {
            for dy in stride(from: -2.0, through: 2.0, by: 0.1) {
                let feet = layout.point(item.gx + CGFloat(dx), item.gy + CGFloat(dy))
                guard IslandCamera.isBehind(feet: feet, item: item, layout: layout) == behind else { continue }
                let rect = CGRect(x: feet.x - 18, y: feet.y - 38, width: 36, height: 38)
                if rect.intersects(bounds) {
                    return IslandWorld.Figure(id: item.source.bookID ?? "scene", feet: feet, rect: rect)
                }
            }
        }
        return nil
    }

    private func sceneFrontFigure(item: Island.Item, layout: IslandLayout) -> (figure: IslandWorld.Figure, piece: SceneEvent) {
        let events = SceneSystem.activeEvents(for: item).filter {
            SceneSystem.isTall($0, item: item) && $0.u + $0.v < 1.7
        }
        let event = events.min { ($0.u + $0.v) < ($1.u + $1.v) }!
        let halfWidth = item.span * layout.scale
        let halfHeight = halfWidth / 2
        let base = layout.point(item.gx, item.gy)
        let ground = CGPoint(x: base.x + (event.u - event.v) * halfWidth,
                             y: base.y + (event.u + event.v - 1) * halfHeight)
        let feet = CGPoint(x: ground.x, y: ground.y + halfHeight * 0.1)
        let rect = CGRect(x: feet.x - 18, y: feet.y - 38, width: 36, height: 38)
        return (IslandWorld.Figure(id: item.source.bookID ?? "scene", feet: feet, rect: rect), event)
    }
}
