import Testing
import Foundation
import CoreGraphics
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
            #expect(layout.book.lowercased() == bookID)
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
        #expect(IslandPainter.artRegion(of: item, layout: layout)?.parts.count == 12)
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

    @Test("Genesis hit bounds and masks still use individual sprite regions")
    func genesisHitRegionsRemainIndividual() {
        let island = Island.single(bookID: "genesis", distinct: 50, totalReads: 50)
        let layout = IslandLayout(island: island, size: CGSize(width: 390, height: 844), zoom: 3)
        let item = island.items[0]
        let region = IslandPainter.artRegion(of: item, layout: layout)
        #expect(region?.parts.count == SceneSystem.activeEvents(for: item).count)
        #expect(region?.parts.contains { $0.alpha?.contains(0) == true })
    }
}
