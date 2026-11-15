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
            #expect(art != nil, sprite)
            #expect(art?.image.width == 256, sprite)
            #expect(art?.image.height == 384, sprite)
        }
    }

    @Test("The Genesis cache key changes when the scene stage changes")
    func cacheKeyIncludesSceneStage() {
        let item = Island.single(bookID: "genesis", distinct: 50, totalReads: 50).items[0]
        let island = Island.single(bookID: "genesis", distinct: 50, totalReads: 50)
        let camera = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 2)
        #if DEBUG
        GenesisScene.previewStage = 1
        let first = IslandRenderCache.shared.cacheKeyForTesting(item, layout: camera)
        GenesisScene.previewStage = 2
        let second = IslandRenderCache.shared.cacheKeyForTesting(item, layout: camera)
        GenesisScene.previewStage = nil
        #expect(first != second)
        #endif
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

    @Test("Non-Genesis Places keep their existing piece layout")
    func nonGenesisPlacesRemainUnchanged() {
        let island = Island.single(bookID: "ruth", distinct: 4, totalReads: 4)
        #expect(island.items.count == PlaceData.spec(for: "ruth").pieces.count)
        #expect(island.items.allSatisfy { $0.source.bookID == "ruth" })
        #expect(!island.items.contains { $0.kind == .piece(.soil) })
    }
}
