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
        Island.Item(kind: kind, gx: gx, gy: gy, seed: chapter, source: .forest(book: "john", chapter: chapter),
                    footprint: CGRect(x: gx - 0.18, y: gy - 0.18, width: 0.36, height: 0.36))
    }

    static let behindFlower = item(.extra(.path), 12.28, 12.28, chapter: 1) // index 0
    static let tree = item(.tree, 12.72, 12.72, chapter: 2)          // index 1 (in front of the flowers)
    static let rock = item(.extra(.bench), 12.72, 12.28, chapter: 3)            // index 2 (adjacent spot)
    static let leftFlower = item(.extra(.path), 12.28, 12.72, chapter: 4)  // index 3 (adjacent spot)

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
        let lone = Fixture.item(.extra(.lamp), 11.5, 11.5, chapter: 9)
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

/// Large objects: the Library and landmarks are hit on their drawn picture, not just their tile.
@MainActor
struct LargeObjectHitTests {
    static func library(at gx: CGFloat, _ gy: CGFloat) -> Island.Item {
        Island.Item(kind: .library, gx: gx, gy: gy, seed: 0, source: .feature(.library),
                    footprint: CGRect(x: gx - 0.95, y: gy - 0.95, width: 1.9, height: 1.9))
    }

    @Test("The Library answers taps on its roof, walls and ground", arguments: HitTestingTests.zooms, HitTestingTests.pans)
    func libraryEverywhere(zoom: CGFloat, pan: CGSize) {
        let lib = Self.library(at: 12.5, 12.5)
        let layout = Fixture.layout(zoom: zoom)
        let bounds = IslandPainter.drawnBounds(of: lib, layout: layout)
        #expect(bounds.height > 0 && bounds.width > 0)
        // Near the top of the roof, the middle of the walls, and the ground.
        for p in [CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.1),
                  CGPoint(x: bounds.midX, y: bounds.midY),
                  layout.point(lib.gx, lib.gy)] {
            let screen = CGPoint(x: p.x + pan.width, y: p.y + pan.height)
            #expect(IslandHitTester.hit(point: screen, layout: layout, pan: pan, items: [lib]) == 0)
        }
    }

    @Test("Drawn bounds sit inside the picture's rectangle (transparent padding is ignored)")
    func boundsTrimmed() {
        let lib = Self.library(at: 12.5, 12.5)
        let layout = Fixture.layout(zoom: 2)
        guard let art = IslandPainter.art(for: lib) else { Issue.record("no library art"); return }
        let base = layout.point(lib.gx, lib.gy)
        let full = IslandPainter.imageRect(art, item: lib, tileWidth: layout.scale * 2).offsetBy(dx: base.x, dy: base.y)
        let visible = IslandPainter.drawnBounds(of: lib, layout: layout)
        #expect(full.insetBy(dx: -0.5, dy: -0.5).contains(visible))
        #expect(visible.width * visible.height < full.width * full.height)
    }

    @Test("A small thing in front of a large building still gets its own taps", arguments: HitTestingTests.zooms)
    func smallInFrontOfLarge(zoom: CGFloat) {
        let lib = Self.library(at: 12.5, 12.5)
        let flower = Fixture.item(.extra(.path), 13.5, 13.5, chapter: 7) // in front (higher gx+gy)
        let layout = Fixture.layout(zoom: zoom)
        let onFlower = layout.point(flower.gx, flower.gy)
        #expect(IslandHitTester.hit(point: onFlower, layout: layout, items: [lib, flower]) == 1)
    }
}

/// The shared picker on its own.
struct HitPickerTests {
    @Test func frontMostDirectHitWins() {
        let c = [HitCandidate(id: "back", depth: 1, onGround: false, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)),
                 HitCandidate(id: "front", depth: 5, onGround: false, bounds: CGRect(x: 40, y: 40, width: 20, height: 20))]
        #expect(HitPicker.pick(CGPoint(x: 50, y: 50), from: c, minimumTarget: 44) == "front")
        #expect(HitPicker.pick(CGPoint(x: 10, y: 10), from: c, minimumTarget: 44) == "back")
    }

    @Test func groundCountsEvenOutsideTheDrawing() {
        let c = [HitCandidate(id: "a", depth: 1, onGround: true, bounds: .zero)]
        #expect(HitPicker.pick(CGPoint(x: 500, y: 500), from: c, minimumTarget: 44) == "a")
    }

    @Test func tinyThingsGetFortyFourPoints() {
        let c = [HitCandidate(id: "tiny", depth: 1, onGround: false, bounds: CGRect(x: 100, y: 100, width: 4, height: 4))]
        #expect(HitPicker.pick(CGPoint(x: 121, y: 102), from: c, minimumTarget: 44) == "tiny")
        #expect(HitPicker.pick(CGPoint(x: 125, y: 102), from: c, minimumTarget: 44) == nil)
    }

    @Test("Direct hits beat a nearby small thing's padded target")
    func directBeatsPadding() {
        let c = [HitCandidate(id: "tiny", depth: 9, onGround: false, bounds: CGRect(x: 0, y: 0, width: 4, height: 4)),
                 HitCandidate(id: "big", depth: 1, onGround: false, bounds: CGRect(x: 10, y: 0, width: 50, height: 50))]
        #expect(HitPicker.pick(CGPoint(x: 12, y: 2), from: c, minimumTarget: 44) == "big")
    }

    @Test("Expanding to the minimum keeps the centre and never shrinks")
    func expanded() {
        let r = HitPicker.expanded(CGRect(x: 10, y: 10, width: 10, height: 100), to: 44)
        #expect(r.midX == 15 && r.midY == 60 && r.width == 44 && r.height == 100)
    }
}

/// Panning never selects: the tap tracker used on the world map.
struct TapTrackerTests {
    @Test func stillTouchIsATap() {
        var t = TapTracker()
        t.began(at: .zero)
        t.moved(to: CGPoint(x: 3, y: 4))
        let tapped = t.ended(at: CGPoint(x: 6, y: 0))
        #expect(tapped)
    }

    @Test("Moving 10pt or more, even and back, is a pan",
          arguments: [CGPoint(x: 10, y: 0), CGPoint(x: 0, y: -30), CGPoint(x: 8, y: 8)])
    func panNeverTaps(away: CGPoint) {
        var t = TapTracker()
        t.began(at: .zero)
        t.moved(to: away)
        let tapped = t.ended(at: .zero)
        #expect(!tapped)
    }

    @Test func endWithoutBeginIsNotATap() {
        var t = TapTracker()
        let tapped = t.ended(at: .zero)
        #expect(!tapped)
    }
}
