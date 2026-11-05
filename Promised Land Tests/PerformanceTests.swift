import Testing
import Foundation
import CoreGraphics
import SwiftUI
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
            .init(signature: Self.island.signature, zoom: 2, angle: 0, pan: PanStep.drawPan(pan), size: Self.size, insets: EdgeInsets(),
                  selected: nil, editing: false, editSelected: nil, overrides: [:], hidden: [])
        }
        #expect(key(.zero) == key(CGSize(width: 20, height: -30)))
        #expect(key(.zero) != key(CGSize(width: PanStep.size, height: 0)))
    }

    @Test("Depth order is worked out once, not per pan or zoom, and again when the island turns")
    func depthOrderOnlyWhenNeeded() {
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

        order.update(island: Self.island, layout: IslandLayout(island: Self.island, size: Self.size, angle: 1), overrides: [:], hidden: [])
        #expect(order.sorts == 2)
        // Something mid-reveal (grown differently or hidden) is sorted again too.
        order.update(island: Self.island, layout: IslandLayout(island: Self.island, size: Self.size, angle: 1), overrides: [0: 0.5], hidden: [])
        order.update(island: Self.island, layout: IslandLayout(island: Self.island, size: Self.size, angle: 1), overrides: [0: 0.5], hidden: [1])
        #expect(order.sorts == 4)
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
}
