import Testing
import Foundation
import CoreGraphics
@testable import Promised_Land

@MainActor
struct GenesisSceneTests {
    private var layout: SceneLayout { SceneLayoutLoader.load(bookID: "genesis")! }

    @Test("Genesis JSON decodes through the generic book scene loader")
    func jsonDecodes() {
        #expect(layout.book == "Genesis")
        #expect(layout.chapters == 50)
        #expect(layout.events.count == 50)
    }

    @Test("Genesis chapters 1 through 50 each have exactly one event")
    func chaptersHaveOneEvent() {
        for chapter in 1...50 {
            #expect(layout.events.filter { $0.chapter == chapter }.count == 1)
        }
    }

    @Test("Every Genesis grow replaces a slot established by an earlier event")
    func growsReferenceEarlierSlots() {
        for event in layout.events where event.action == "grow" {
            #expect(layout.events.contains { $0.slot == event.slot && $0.chapter < event.chapter })
        }
    }

    @Test("Genesis stage 0 is empty")
    func stageZeroIsEmpty() {
        #expect(layout.events(at: 0).isEmpty)
        #expect(Island.single(bookID: "genesis", distinct: 0, totalReads: 50).items.isEmpty)
    }

    @Test("Genesis stage 1 shows only obj_genesis_life_1")
    func stageOneShowsFirstTree() {
        #expect(layout.events(at: 1).map(\.sprite) == ["obj_genesis_life_1"])
    }

    @Test("Genesis stage 50 uses obj_genesis_life_4 in slot L")
    func stageFiftyUsesLifeFour() {
        #expect(layout.events(at: 50).first { $0.slot == "L" }?.sprite == "obj_genesis_life_4")
    }

    @Test("Genesis stages beyond 50 equal stage 50")
    func stagesPastFiftyAreStable() {
        #expect(layout.events(at: 51) == layout.events(at: 50))
        #expect(layout.events(at: 500) == layout.events(at: 50))
    }

    @Test("Every Genesis sprite exists at 256 by 384 pixels in the asset catalog")
    func spritesExistAtAuthoredSize() {
        for sprite in Set(layout.events.map(\.sprite)) {
            let art = ArtAssets.image(sprite)
            #expect(art != nil)
            #expect(art?.image.width == 256)
            #expect(art?.image.height == 384)
        }
    }

    @Test("The Genesis cache key uses real progress and island identity")
    func cacheKeyIncludesRealStageAndIsland() {
        let island = Island.single(bookID: "genesis", distinct: 50, totalReads: 50)
        let camera = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 2)
        let item = island.items[0]
        let first = IslandRenderCache.shared.cacheKeyForTesting(item, layout: camera)
        #if DEBUG
        GenesisScene.previewStage = 1
        let previewOverride = IslandRenderCache.shared.cacheKeyForTesting(item, layout: camera)
        GenesisScene.previewStage = nil
        #expect(first == previewOverride)
        #endif
        var later = item
        later.progress = 49
        let laterKey = IslandRenderCache.shared.cacheKeyForTesting(later, layout: camera)
        #expect(first != laterKey)

        let otherIsland = Island.single(bookID: "genesis", distinct: 49, totalReads: 50)
        let otherLayout = IslandLayout(island: otherIsland, size: CGSize(width: 390, height: 844), zoom: 2)
        #expect(first != IslandRenderCache.shared.cacheKeyForTesting(otherIsland.items[0], layout: otherLayout))
    }

    @Test("The Genesis hit item resolves to book genesis")
    func hitItemResolvesToGenesis() {
        let island = Island.single(bookID: "genesis", distinct: 50, totalReads: 50)
        #expect(island.items.count == 1)
        #expect(island.items[0].kind == .piece(.soil))
        #expect(island.items[0].source.bookID == "genesis")
    }

    @Test("The Genesis hit bounds cover the full authored scene at stage 50")
    func hitBoundsCoverScene() {
        let island = Island.single(bookID: "genesis", distinct: 50, totalReads: 50)
        let layout = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 3)
        let item = island.items[0]
        let bounds = IslandPainter.drawnBounds(of: item, layout: layout)
        let local = GenesisScene.localBounds(item: item, u: layout.u, stage: 50)
        #expect(!bounds.isEmpty)
        #expect(bounds.contains(CGPoint(x: layout.point(item.gx, item.gy).x + local.midX,
                                        y: layout.point(item.gx, item.gy).y + local.minY + 1)))
    }

    @Test("Genesis hit testing exposes sprite masks rather than one union rectangle")
    func genesisSpriteMasksAreIndividual() {
        let island = Island.single(bookID: "genesis", distinct: 50, totalReads: 50)
        let layout = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 3)
        let item = island.items[0]
        guard let region = IslandPainter.artRegion(of: item, layout: layout) else {
            Issue.record("Genesis should expose sprite hit regions")
            return
        }
        #expect(region.parts.count == GenesisScene.activeEvents(at: 50).count)
        let transparent = region.parts.first { part in
            guard let alpha = part.alpha else { return false }
            return alpha.contains(0)
        }
        if let transparent, let alpha = transparent.alpha, let index = alpha.firstIndex(of: 0) {
            let x = CGFloat(index % 64)
            let y = CGFloat(index / 64)
            let point = CGPoint(x: transparent.bounds.minX + (x + 0.5) * transparent.bounds.width / 64,
                                y: transparent.bounds.minY + (y + 0.5) * transparent.bounds.height / 64)
            let maskedPart = HitRegion(bounds: transparent.bounds, alpha: alpha)
            #expect(alpha[index] == 0)
            #expect(maskedPart.contains(point) == false)
        }
        let centre = CGPoint(x: region.parts[0].bounds.midX, y: region.parts[0].bounds.midY)
        #expect(region.contains(centre))
    }

    @Test("Genesis outside its plot and art does not hit")
    func genesisOutsidePlotDoesNotHit() {
        let island = Island.single(bookID: "genesis", distinct: 50, totalReads: 50)
        let layout = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 3)
        let item = island.items[0]
        let plot = island.plots.first { $0.bookID == "genesis" }!
        let point = layout.point(CGFloat(plot.x) - 4, CGFloat(plot.y) - 4)
        #expect(IslandHitTester.hit(point: point, layout: layout, items: island.items, plots: island.allPlots) == nil)
    }

    @Test("Genesis's tall life trees and fruit tree occlude a villager")
    func tallGenesisObjectsOccludeVillagers() {
        let island = Island.single(bookID: "genesis", distinct: 11, totalReads: 50)
        let item = island.items[0]
        let camera = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 3)
        let bounds = IslandPainter.drawnBounds(of: item, layout: camera)
        let figure = IslandWorld.Figure(id: "villager", feet: camera.point(item.gx - 0.2, item.gy - 0.2),
                                        rect: bounds.insetBy(dx: bounds.width * 0.35, dy: bounds.height * 0.35))
        let visible = IslandWorld.visibleItems(island.items, layout: camera, visible: bounds)
        #expect(GenesisScene.occludesVillager(item))
        #expect(IslandWorld.itemsOver(figure, items: visible, layout: camera) == [0])
    }

    @Test("A person in front of the Genesis tree is not occluded")
    func personInFrontOfGenesisTreeIsNotOccluded() {
        let island = Island.single(bookID: "genesis", distinct: 11, totalReads: 50)
        let item = island.items[0]
        let camera = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 3)
        let bounds = IslandPainter.drawnBounds(of: item, layout: camera)
        let figure = IslandWorld.Figure(id: "villager", feet: camera.point(item.gx + 3.0, item.gy + 3.0),
                                        rect: bounds.insetBy(dx: bounds.width * 0.35, dy: bounds.height * 0.35))
        let visible = IslandWorld.visibleItems(island.items, layout: camera, visible: bounds)
        #expect(IslandWorld.itemsOver(figure, items: visible, layout: camera).isEmpty)
    }

    @Test("Genesis ground pieces never occlude a person")
    func genesisGroundDoesNotOccludeVillager() {
        let island = Island.single(bookID: "genesis", distinct: 3, totalReads: 50)
        let item = island.items[0]
        let camera = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 3)
        let bounds = IslandPainter.drawnBounds(of: item, layout: camera)
        let figure = IslandWorld.Figure(id: "villager", feet: camera.point(item.gx - 0.2, item.gy - 0.2),
                                        rect: bounds.insetBy(dx: bounds.width * 0.35, dy: bounds.height * 0.35))
        let visible = IslandWorld.visibleItems(island.items, layout: camera, visible: bounds)
        #expect(GenesisScene.activeEvents(at: 3).filter { $0.tall }.isEmpty)
        #expect(IslandWorld.itemsOver(figure, items: visible, layout: camera).isEmpty)
    }
}
