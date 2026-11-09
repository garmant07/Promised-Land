import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import Promised_Land

/// Section 4b: buildings stay on their land however the camera moves, nothing on screen is dropped
/// and re-added, and birds are always on top.
@MainActor
struct IslandLayeringTests {
    static let size = CGSize(width: 390, height: 844)
    static let island = LODTests.island

    @Test("Buildings stay on their tiles through fast pans, at every turn and zoom", arguments: [0, 1, 2, 3])
    func buildingsStayOnTiles(quarter: Int) throws {
        var rng = SeededRandom(seed: UInt64(11 + quarter))
        for zoom: CGFloat in [1, 2.3, 4.7] {
            var pan = CGSize.zero
            let base = try #require(IslandRenderCache.shared.frame(island: Self.island, size: Self.size, insets: EdgeInsets(), zoom: zoom,
                                                                   quarter: quarter, pan: pan, overrides: [:], hidden: [],
                                                                   viewport: CGRect(x: -3000, y: -3000, width: 6000, height: 6000)))
            for _ in 0..<12 {
                // A fast, shaky pan: up to 300 points in a frame.
                pan = CGSize(width: pan.width + rng.next(in: -300...300), height: pan.height + rng.next(in: -300...300))
                let moved = try #require(IslandRenderCache.shared.frame(island: Self.island, size: Self.size, insets: EdgeInsets(), zoom: zoom,
                                                                        quarter: quarter, pan: pan, overrides: [:], hidden: [],
                                                                        viewport: CGRect(x: -3000, y: -3000, width: 6000, height: 6000)))
                // The ground and every Place picture move by exactly the pan: nothing drifts off its land.
                #expect(moved.ground.count == base.ground.count && moved.layers.count == base.layers.count)
                for (a, b) in zip(base.ground, moved.ground) {
                    #expect(abs(b.rect.minX - a.rect.minX - pan.width) < 0.001 && abs(b.rect.minY - a.rect.minY - pan.height) < 0.001)
                }
                for (a, b) in zip(base.layers, moved.layers) {
                    if case .picture(_, let ra) = a, case .picture(_, let rb) = b {
                        #expect(abs(rb.minX - ra.minX - pan.width) < 0.001 && abs(rb.minY - ra.minY - pan.height) < 0.001)
                    }
                }
                // The still layer is drawn at a rounded pan and slid by the rest: together, exactly the pan.
                let drawn = PanStep.drawPan(pan), slide = PanStep.offset(pan)
                #expect(abs(drawn.width + slide.width - pan.width) < 0.001 && abs(drawn.height + slide.height - pan.height) < 0.001)
            }
        }
    }

    @Test("A building drawn over someone is placed only from its grid point, moving exactly with the camera", arguments: [0, 1, 2, 3])
    func redrawIsOnTheSameSpot(quarter: Int) {
        let base = IslandLayout(island: Self.island, size: Self.size, zoom: 3.3, angle: CGFloat(quarter))
        var rng = SeededRandom(seed: UInt64(quarter + 3))
        for _ in 0..<8 {
            let d = CGSize(width: rng.next(in: -400...400), height: rng.next(in: -400...400))
            let moved = base.panned(d)
            for item in Self.island.items.prefix(120) {
                let a = IslandWorld.pictureRect(item, layout: base), b = IslandWorld.pictureRect(item, layout: moved)
                #expect(abs(b.minX - a.minX - d.width) < 0.001 && abs(b.minY - a.minY - d.height) < 0.001)
                // Relative to its own grid point, the same at any pan.
                let pa = base.point(item.gx, item.gy), pb = moved.point(item.gx, item.gy)
                #expect(abs((a.minX - pa.x) - (b.minX - pb.x)) < 0.001 && abs((a.minY - pa.y) - (b.minY - pb.y)) < 0.001)
            }
        }
    }

    @Test("Nothing is dropped and re-added while it stays inside the visible rect")
    func stableVisibility() {
        let screen = CGRect(origin: .zero, size: Self.size)
        let visible = screen.insetBy(dx: -PlatformScene.lifeMargin, dy: -PlatformScene.lifeMargin)
        let base = IslandLayout(island: Self.island, size: Self.size, zoom: 3)
        let ordered = Self.island.items
        var rng = SeededRandom(seed: 5)
        var pan = CGSize.zero
        var previous: [Island.Item] = []
        var checked = 0
        for _ in 0..<120 {
            pan = CGSize(width: pan.width + rng.next(in: -40...40), height: pan.height + rng.next(in: -40...40))
            let layout = base.panned(pan)
            let now = IslandWorld.visibleItems(ordered, layout: layout, visible: visible).map(\.item)
            // Anything that was in and is still well inside the rect is still in.
            for item in previous where visible.insetBy(dx: 1, dy: 1).contains(IslandWorld.pictureRect(item, layout: layout)) {
                #expect(now.contains(item), "\(item.kind) dropped while inside the rect")
                checked += 1
            }
            previous = now
        }
        #expect(checked > 0)
    }

    @Test("Birds are always drawn above everything on the island")
    func birdsOnTop() {
        #expect(IslandLayer.birds.z > IslandLayer.people.z)
        #expect(IslandLayer.birds.z > IslandLayer.effects.z)
        #expect(IslandLayer.birds.z > IslandLayer.dim.z)
        // Only the tappable baskets and speech bubbles (UI) are above them.
        #expect(IslandLayer.allCases.filter { $0.z > IslandLayer.birds.z } == [.baskets, .bubbles])
    }
}
