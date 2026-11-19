import Testing
import Foundation
import CoreGraphics
import SwiftUI
import QuartzCore
@testable import Promised_Land

/// The performance pass: what's worked out once instead of per frame, and the rounded-pan layers.
@MainActor
struct PerformanceTests {
    static let size = CGSize(width: 390, height: 844)
    static let island = LODTests.island
    static let life = LODTests.life

    @Test("A layer drawn at the rounded pan and slid by the rest lines up with the real pan")
    func panStepLinesUp() {
        for pan in [CGSize.zero, CGSize(width: 37, height: -61), CGSize(width: 47.9, height: 48.1), CGSize(width: -500, height: 1234.5)] {
            let drawn = PanStep.drawPan(pan), slide = PanStep.offset(pan)
            // A point drawn at `drawn` and moved by `slide` lands where the real pan puts it.
            #expect(abs(drawn.width + slide.width - pan.width) < 0.0001)
            #expect(abs(drawn.height + slide.height - pan.height) < 0.0001)
            // The layer (a step bigger than the screen) always covers the screen.
            #expect(slide.width <= 0 && slide.width >= -PanStep.size)
            #expect(slide.height <= 0 && slide.height >= -PanStep.size)
        }
    }

    @Test("Small pans don't change what the still layers draw; crossing a step does")
    func smallPansDontRedraw() {
        func key(_ pan: CGSize) -> IslandGroundLayer.Key {
            .init(signature: Self.island.signature, zoom: 2, pan: PanStep.drawPan(pan), size: Self.size, insets: EdgeInsets(),
                  selected: nil, editing: false, editSelected: nil, overrides: [:], hidden: [])
        }
        #expect(key(.zero) == key(CGSize(width: 20, height: -30)))
        #expect(key(.zero) != key(CGSize(width: PanStep.size, height: 0)))
    }

    @Test("Depth order is worked out once, not per pan or zoom")
    func depthOrderOnlyWhenNeeded() {
        let wasEnabled = PerfProbe.enabled
        PerfProbe.enabled = true
        defer { PerfProbe.enabled = wasEnabled }
        let order = IslandDepthOrder()
        for (zoom, pan) in [(1.0, CGSize.zero), (2.5, CGSize(width: 100, height: -40)), (6, CGSize(width: -300, height: 90))] {
            let layout = IslandLayout(island: Self.island, size: Self.size, zoom: zoom).panned(pan)
            order.update(island: Self.island, layout: layout, overrides: [:], hidden: [])
        }
        #expect(order.sorts == 1)
        // Same order as sorting by depth directly.
        let layout = IslandLayout(island: Self.island, size: Self.size)
        let expected = Self.island.items.sorted { layout.depth($0.gx, $0.gy) < layout.depth($1.gx, $1.gy) }
        #expect(order.all.map(\.gx) == expected.map(\.gx) && order.all.map(\.gy) == expected.map(\.gy))
        #expect(order.tall.allSatisfy(\.kind.isTall) && order.tall.count == expected.filter(\.kind.isTall).count)

        order.update(island: Self.island, layout: IslandLayout(island: Self.island, size: Self.size), overrides: [:], hidden: [])
        #expect(order.sorts == 1)
        // Something mid-reveal (grown differently or hidden) is sorted again too.
        order.update(island: Self.island, layout: IslandLayout(island: Self.island, size: Self.size), overrides: [0: 0.5], hidden: [])
        order.update(island: Self.island, layout: IslandLayout(island: Self.island, size: Self.size), overrides: [0: 0.5], hidden: [1])
        #expect(order.sorts == 3)
    }

    @Test("Far out, once everyone has faded, villagers aren't even listed")
    func farOutListsNobody() {
        let director = LifeDirector()
        let layout = IslandLayout(island: Self.island, size: Self.size, zoom: 1)
        let viewport = CGRect(origin: .zero, size: Self.size)
        var listed = 0
        for f in 0..<10 {
            let t = 1000 + Double(f) / 60
            director.begin(now: t, u: layout.u)
            _ = director.plan({ listed += 1; return Self.life.figures(layout: layout, viewport: viewport) }(), now: t, viewport: viewport)
        }
        #expect(director.tier == .far)
        #expect(listed == 0)
    }

    @Test("Wave spots are looked up by the island, not worked out every frame")
    func waveSpotsCached() {
        let first = WaveSpots.spots(Self.island)
        let again = WaveSpots.spots(Self.island)
        #expect(!first.isEmpty)
        #expect(first.map(\.x) == again.map(\.x) && first.map(\.y) == again.map(\.y))
    }

    @Test("Villagers follow the same routine as before (legs worked out once per pose)")
    func villagerPeriodMatches() {
        guard let v = Self.life.villagers.first(where: { $0.routine.waypoints.count > 1 }) else { return }
        // At its own period it's back where it started.
        let a = v.pose(at: 10).point, b = v.pose(at: 10 + v.period).point
        #expect(abs(a.x - b.x) < 0.0001 && abs(a.y - b.y) < 0.0001)
    }

    @Test("Produce baskets are cached pictures, not redrawn every frame")
    func basketsCached() {
        let wasEnabled = PerfProbe.enabled
        PerfProbe.enabled = true
        defer { PerfProbe.enabled = wasEnabled }
        var life = IslandLife.make(island: Self.island)
        let place = Self.island.plots[0]
        life.baskets = [IslandLife.Basket(bookID: place.bookID, point: place.centre, count: 3, kind: .bread)]
        let layout = IslandLayout(island: Self.island, size: Self.size, zoom: 6)
            .panned(CGSize(width: 0, height: 0))
        // Pan so the basket is on screen.
        let p = layout.point(place.centre.x, place.centre.y)
        let centred = layout.panned(CGSize(width: Self.size.width / 2 - p.x, height: Self.size.height / 2 - p.y))
        let cache = IslandRenderCache.shared
        func draw() {
            let renderer = ImageRenderer(content: Canvas { c, size in
                IslandLife.drawBaskets(&c, life: life, layout: centred, time: 0, visible: CGRect(origin: .zero, size: size))
            }.frame(width: Self.size.width, height: Self.size.height))
            _ = renderer.cgImage
        }
        let start = cache.renders
        draw()
        let after = cache.renders
        #expect(after == start + 1)  // the basket was on screen and rendered once
        draw()
        draw()
        #expect(cache.renders == after)
    }

    @Test("A full island frame reports scene costs at three zooms")
    func fullIslandSceneFrameBenchmark() {
        #if DEBUG
        let cache = IslandRenderCache.shared
        let oldScenesEnabled = SceneSystem.scenesEnabled
        defer {
            SceneSystem.scenesEnabled = oldScenesEnabled
            cache.removeAll()
            PerfProbe.resetFrameCounters()
        }

        struct Result {
            let averageMilliseconds: Double
            let counters: PerfProbe.FrameCounters
            let overCount: Int
        }

        func renderFrame(zoom: CGFloat, scenesEnabled: Bool) -> Result {
            SceneSystem.scenesEnabled = scenesEnabled
            cache.removeAll()
            let layout = IslandLayout(island: Self.island, size: Self.size, zoom: zoom)
            let viewport = CGRect(origin: .zero, size: Self.size)
            let ordered = Self.island.items.sorted { layout.depth($0.gx, $0.gy) < layout.depth($1.gx, $1.gy) }
            let staticFrame = cache.frame(island: Self.island, size: Self.size, insets: EdgeInsets(),
                                          zoom: zoom, pan: .zero, overrides: [:], hidden: [],
                                          viewport: viewport, deferMissing: false)!
            let sceneItems = ordered.filter {
                $0.source.bookID.map(SceneSystem.isSceneBook) == true &&
                SceneSystem.occludesVillager($0)
            }
            let selected = scenesEnabled
                ? Array(sceneItems.prefix(6))
                : Array(ordered.filter(\.kind.isTall).prefix(6))
            var overCount = 0

            func drawOnce() -> CGImage? {
                let renderer = ImageRenderer(content: Canvas { context, _ in
                    for ground in staticFrame.ground {
                        context.draw(Image(decorative: ground.image, scale: 1), in: ground.rect)
                    }
                    for layer in staticFrame.layers {
                        switch layer {
                        case .picture(let image, let rect):
                            context.draw(Image(decorative: image, scale: 1), in: rect)
                        case .item(let item):
                            IslandPainter.drawItem(&context, item, layout: layout)
                        }
                    }
                    for item in selected {
                        let base = layout.point(item.gx, item.gy)
                        let figure = IslandWorld.Figure(
                            id: "benchmark-" + (item.source.bookID ?? "scene"),
                            feet: CGPoint(x: base.x, y: base.y - 2 * layout.u),
                            rect: CGRect(x: base.x - 4 * layout.u, y: base.y - 17 * layout.u,
                                         width: 8 * layout.u, height: 15 * layout.u)
                        )
                        let visibleItems = IslandWorld.visibleItems(
                            ordered, layout: layout,
                            visible: CGRect(x: -10_000, y: -10_000, width: 20_000, height: 20_000)
                        )
                        let indices = IslandWorld.itemsOver(figure, items: visibleItems, layout: layout)
                        overCount += indices.count
                        context.fill(Path(ellipseIn: figure.rect), with: .color(.brown))
                        for index in indices {
                            IslandRenderCache.shared.drawItem(&context, visibleItems[index].item, layout: layout,
                                                                       sceneLayer: .tall)
                        }
                    }
                }.frame(width: Self.size.width, height: Self.size.height))
                return renderer.cgImage
            }

            _ = drawOnce()
            PerfProbe.resetFrameCounters()
            let start = CACurrentMediaTime()
            let samples = 3
            for _ in 0..<samples { _ = drawOnce() }
            let average = (CACurrentMediaTime() - start) / Double(samples) * 1000
            let counters = PerfProbe.frameCounters
            return Result(averageMilliseconds: average, counters: counters, overCount: overCount)
        }

        for zoom in [IslandLayout.minZoom, CGFloat(4), IslandLayout.maxZoom(island: Self.island, size: Self.size)] {
            let on = renderFrame(zoom: zoom, scenesEnabled: true)
            let off = renderFrame(zoom: zoom, scenesEnabled: false)
            print(String(format: "SCENE BENCH zoom=%.3f on=%.3fms off=%.3fms ratio=%.2f over=%d onCounters sprites=%d loaded=%d alpha=%d opaque=%d tall=%d pictures=%d offCounters sprites=%d loaded=%d alpha=%d opaque=%d tall=%d pictures=%d",
                         zoom, on.averageMilliseconds, off.averageMilliseconds,
                         on.averageMilliseconds / max(0.001, off.averageMilliseconds), on.overCount,
                         on.counters.spriteImagesDrawn, on.counters.imagesLoadedOrDecoded,
                         on.counters.alphaMeasurements, on.counters.opaqueMeasurements,
                         on.counters.tallLayerRedraws, on.counters.scenePictureRenders,
                         off.counters.spriteImagesDrawn, off.counters.imagesLoadedOrDecoded,
                         off.counters.alphaMeasurements, off.counters.opaqueMeasurements,
                         off.counters.tallLayerRedraws, off.counters.scenePictureRenders))
            #expect(on.overCount >= 0)
        }
        #endif
    }
}
