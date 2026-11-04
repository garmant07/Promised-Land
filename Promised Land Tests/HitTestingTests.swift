import Testing
import SwiftUI
@testable import Promised_Land

/// A small island with known items, so taps can be checked precisely.
///
/// Screen layout (around one tile): a flower and a rock sit at the back of the tile; an olive
/// tree stands in front of the flower, so its canopy covers the flower; another flower sits
/// in the left quarter, clear of the tree.
@MainActor
enum Fixture {
    static let size = CGSize(width: 390, height: 844)
    static let insets = EdgeInsets(top: 70, leading: 8, bottom: 118, trailing: 8)

    static func item(_ kind: Island.Kind, _ gx: CGFloat, _ gy: CGFloat, chapter: Int) -> Island.Item {
        Island.Item(kind: kind, gx: gx, gy: gy, seed: chapter, source: .chapter(book: "john", chapter: chapter),
                    footprint: IslandPlacement.footprint(centre: CGPoint(x: gx, y: gy), weight: kind.weight))
    }

    static let behindFlower = item(.flower, 12.3, 12.3, chapter: 1)   // index 0
    static let tree = item(.olive, 12.72, 12.7, chapter: 2)            // index 1 (in front of the flower)
    static let rock = item(.rock, 12.72, 12.32, chapter: 3)            // index 2 (adjacent quarter)
    static let leftFlower = item(.flower, 12.3, 12.72, chapter: 4)     // index 3 (adjacent quarter)

    static let island = Island(
        tiles: (11...13).flatMap { y in (11...13).map { x in Island.Tile(x: x, y: y) } },
        items: [behindFlower, tree, rock, leftFlower]
    )

    static func layout(zoom: CGFloat) -> IslandLayout {
        IslandLayout(island: island, size: size, insets: insets, zoom: zoom)
    }

    /// Where an item's base is on screen, with the view panned.
    static func screenPoint(_ item: Island.Item, layout: IslandLayout, pan: CGSize = .zero, lift: CGFloat = 0) -> CGPoint {
        let p = layout.point(item.gx, item.gy)
        return CGPoint(x: p.x + pan.width, y: p.y + pan.height - lift)
    }
}

@MainActor
struct HitTestingTests {
    nonisolated static let zooms: [CGFloat] = [1, 4] // IslandLayout.minZoom, IslandLayout.maxZoom
    nonisolated static let pans: [CGSize] = [.zero, CGSize(width: 63, height: -41)]

    @Test("Tapping a tree's canopy picks the tree, even where it covers a flower behind it",
          arguments: zooms, pans)
    func overlappingPicksFrontMost(zoom: CGFloat, pan: CGSize) {
        let layout = Fixture.layout(zoom: zoom)
        // Exactly on the hidden flower's base, which the tree's canopy is drawn over.
        let onFlower = Fixture.screenPoint(Fixture.behindFlower, layout: layout, pan: pan)
        #expect(IslandHitTester.hit(point: onFlower, layout: layout, pan: pan, items: Fixture.island.items) == 1)
        // High on the canopy.
        let canopy = Fixture.screenPoint(Fixture.tree, layout: layout, pan: pan, lift: 16 * layout.u)
        #expect(IslandHitTester.hit(point: canopy, layout: layout, pan: pan, items: Fixture.island.items) == 1)
    }

    @Test("Adjacent items each get their own taps", arguments: zooms, pans)
    func adjacentItems(zoom: CGFloat, pan: CGSize) {
        let layout = Fixture.layout(zoom: zoom)
        let items = Fixture.island.items
        let rock = Fixture.screenPoint(Fixture.rock, layout: layout, pan: pan)
        let left = Fixture.screenPoint(Fixture.leftFlower, layout: layout, pan: pan)
        #expect(IslandHitTester.hit(point: rock, layout: layout, pan: pan, items: items) == 2)
        #expect(IslandHitTester.hit(point: left, layout: layout, pan: pan, items: items) == 3)
    }

    @Test("Small things have at least a 44pt target", arguments: zooms)
    func minimumTarget(zoom: CGFloat) {
        let layout = Fixture.layout(zoom: zoom)
        let lone = Fixture.item(.tuft, 11.5, 11.5, chapter: 9)
        let base = Fixture.screenPoint(lone, layout: layout)
        // Just off its tiny footprint, but within 22pt of its base.
        let nearby = CGPoint(x: base.x + 20, y: base.y + 4)
        #expect(IslandHitTester.hit(point: nearby, layout: layout, items: [lone]) == 0)
        #expect(IslandHitTester.hit(point: CGPoint(x: base.x + 60, y: base.y + 60), layout: layout, items: [lone]) == nil)
    }

    @Test("Empty ground hits nothing")
    func emptyGround() {
        let layout = Fixture.layout(zoom: IslandLayout.maxZoom)
        let corner = layout.point(11.15, 13.85)
        #expect(IslandHitTester.hit(point: corner, layout: layout, items: Fixture.island.items) == nil)
    }

    @Test func zoomLimitsMatchTheTests() {
        #expect(Self.zooms == [IslandLayout.minZoom, IslandLayout.maxZoom])
    }

    @Test("Grid and screen mapping round-trip at any zoom", arguments: zooms)
    func roundTrip(zoom: CGFloat) {
        let layout = Fixture.layout(zoom: zoom)
        let g = layout.grid(layout.point(12.37, 11.81))
        #expect(abs(g.x - 12.37) < 0.0001 && abs(g.y - 11.81) < 0.0001)
    }
}

struct TapClassifierTests {
    @Test func smallMovementIsATap() {
        #expect(TapClassifier.isTap(translation: .zero))
        #expect(TapClassifier.isTap(translation: CGSize(width: 4, height: 3)))
    }

    @Test("A pan never opens the card", arguments: [CGSize(width: 30, height: 0), CGSize(width: 0, height: -12),
                                                    CGSize(width: 8, height: 8), CGSize(width: 10, height: 0)])
    func panIsNotATap(translation: CGSize) {
        #expect(!TapClassifier.isTap(translation: translation))
    }
}
