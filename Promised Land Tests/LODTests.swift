import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import Promised_Land

/// Level of detail on the fully built island (the Preview full Bible data).
@MainActor
struct LODTests {
    static let size = CGSize(width: 390, height: 844)
    static let island = Island.build(chapters: FullBiblePreviewData.reads, quizzes: [], verses: [], features: [.library, .throne],
                                     richnessOverride: 5)
    static let life = IslandLife.make(island: island)

    /// A camera at `zoom`, centred on the island's middle.
    func layout(zoom: CGFloat) -> IslandLayout {
        IslandLayout(island: Self.island, size: Self.size, zoom: zoom)
    }

    /// Runs the director for `frames` frames at a steady 60 fps and returns the last frame.
    func run(_ director: LifeDirector, layout: IslandLayout, frames: Int = 30, from t0: Double = 1000) -> [LifeDirector.Shown] {
        let viewport = CGRect(origin: .zero, size: Self.size)
        var shown: [LifeDirector.Shown] = []
        for f in 0..<frames {
            let t = t0 + Double(f) / 60
            director.begin(now: t, u: layout.u)
            shown = director.plan(Self.life.figures(layout: layout, viewport: viewport), now: t, viewport: viewport)
        }
        return shown
    }

    @Test("Far out, no villagers or travellers show")
    func far() {
        let l = layout(zoom: 1)
        #expect(l.u < IslandLOD.middleHide)
        let director = LifeDirector()
        #expect(run(director, layout: l).isEmpty)
        #expect(director.tier == .far)
    }

    @Test("In the middle, at most 15 show, all near the centre")
    func middle() {
        let zoom = (IslandLOD.middleShow + 0.1) / layout(zoom: 1).u
        let l = layout(zoom: zoom)
        let director = LifeDirector()
        let shown = run(director, layout: l).filter { $0.opacity > 0.99 }
        #expect(director.tier == .middle)
        #expect(!shown.isEmpty && shown.count <= IslandLOD.middleCap)
        let centre = CGPoint(x: Self.size.width / 2, y: Self.size.height / 2)
        let radius = min(Self.size.width, Self.size.height) * IslandLOD.middleRadius
        #expect(shown.allSatisfy { hypot($0.point.x - centre.x, $0.point.y - centre.y) <= radius + 1 })
    }

    @Test("Close in, at most 30 show, all on screen")
    func close() {
        let zoom = (IslandLOD.closeShow + 0.3) / layout(zoom: 1).u
        let l = layout(zoom: zoom)
        let director = LifeDirector()
        let shown = run(director, layout: l)
        #expect(director.tier == .close)
        #expect(!shown.isEmpty && shown.count <= IslandLOD.closeCap)
        let screen = CGRect(origin: .zero, size: Self.size)
        #expect(shown.allSatisfy { screen.contains($0.point) })
    }

    @Test("Figures fade in over about 0.3 s instead of popping")
    func fadesIn() {
        let l = layout(zoom: (IslandLOD.closeShow + 0.3) / layout(zoom: 1).u)
        let director = LifeDirector()
        let first = run(director, layout: l, frames: 2)
        #expect(first.allSatisfy { $0.opacity < 0.2 })
        let later = run(director, layout: l, frames: 25, from: 1000 + 2.0 / 60)
        #expect(later.contains { $0.opacity >= 0.99 })
    }

    @Test("Off-screen figures are paused and carry on where they left off")
    func pausedOffScreen() {
        let director = LifeDirector()
        let home = CGRect(x: 100, y: 100, width: 40, height: 40)
        let viewport = CGRect(x: 0, y: 0, width: 390, height: 844)
        var calls = 0
        func figure(at rect: CGRect) -> LifeDirector.Figure {
            LifeDirector.Figure(id: "v0", home: rect, position: { t in calls += 1; return CGPoint(x: 120 + t * 0, y: 120) })
        }
        // One second on screen.
        for f in 0...60 {
            director.begin(now: Double(f) / 60, u: 2)
            _ = director.plan([figure(at: home)], now: Double(f) / 60, viewport: viewport)
        }
        let before = director.peek("v0") ?? 0
        // Ten seconds off screen: nothing is worked out for it, and its clock stops.
        calls = 0
        let away = home.offsetBy(dx: 5000, dy: 0)
        for f in 61...660 {
            director.begin(now: Double(f) / 60, u: 2)
            _ = director.plan([figure(at: away)], now: Double(f) / 60, viewport: viewport)
        }
        #expect(calls == 0)
        #expect(director.peek("v0") == before)
        // Back on screen: it resumes from where it was (not ten seconds later).
        director.begin(now: 661.0 / 60, u: 2)
        _ = director.plan([figure(at: home)], now: 661.0 / 60, viewport: viewport)
        director.begin(now: 662.0 / 60, u: 2)
        _ = director.plan([figure(at: home)], now: 662.0 / 60, viewport: viewport)
        let after = director.peek("v0") ?? 0
        #expect(after - before < 0.1)
    }

    @Test("Zooming back and forth across a boundary doesn't flicker")
    func hysteresis() {
        var tier = IslandLOD.tier(u: IslandLOD.middleShow + 0.01, previous: .far)
        #expect(tier == .middle)
        // Wobbling just around the show threshold stays in the middle tier.
        for u in [0.6, 0.63, 0.57, 0.61, 0.56, 0.6] as [CGFloat] {
            tier = IslandLOD.tier(u: u, previous: tier)
            #expect(tier == .middle)
        }
        tier = IslandLOD.tier(u: IslandLOD.closeShow + 0.01, previous: tier)
        #expect(tier == .close)
        for u in [1.2, 1.29, 1.16, 1.25] as [CGFloat] {
            tier = IslandLOD.tier(u: u, previous: tier)
            #expect(tier == .close)
        }
        // Only going clearly past the hide threshold changes it.
        #expect(IslandLOD.tier(u: IslandLOD.closeHide - 0.01, previous: .close) == .middle)
        #expect(IslandLOD.tier(u: IslandLOD.middleHide - 0.01, previous: .middle) == .far)

        // And the director, zoomed back and forth around a boundary, never changes what shows.
        let director = LifeDirector()
        let base = layout(zoom: 1).u
        var shownCounts: Set<Int> = []
        var t = 1000.0
        for i in 0..<120 {
            let u = (i % 2 == 0 ? IslandLOD.closeShow + 0.05 : IslandLOD.closeHide + 0.05)
            let l = layout(zoom: u / base)
            director.begin(now: t, u: l.u)
            let shown = director.plan(Self.life.figures(layout: l, viewport: CGRect(origin: .zero, size: Self.size)), now: t,
                                      viewport: CGRect(origin: .zero, size: Self.size))
            if i > 60 { shownCounts.insert(shown.filter { $0.opacity > 0.99 }.count) }
            t += 1.0 / 60
        }
        #expect(director.tier == .close)
        #expect(shownCounts.allSatisfy { $0 <= IslandLOD.closeCap })
    }

    @Test("You can zoom in until one Place fills most of the screen")
    func zoomInClose() {
        let maxZoom = IslandLayout.maxZoom(island: Self.island, size: Self.size)
        #expect(maxZoom > IslandLayout.baseMaxZoom)
        let l = layout(zoom: maxZoom)
        // A 4-tile Place's diamond is 8 half-tiles wide.
        #expect(8 * l.scale >= Self.size.width * 0.75)
        // Zoomed right out, the whole island fits.
        let out = layout(zoom: IslandLayout.minZoom)
        let corners = Self.island.tiles.map { out.point(CGFloat($0.x), CGFloat($0.y)) }
        #expect(corners.allSatisfy { $0.x >= -1 && $0.x <= Self.size.width + 1 })
    }

    @Test("Pinching keeps the spot between your fingers still, and gives a little past the limits")
    func pinchAnchor() {
        let centre = CGPoint(x: 195, y: 422)
        let anchor = CGPoint(x: 80, y: 300)
        let pan = PlatformScene.panKeeping(anchor, from: (zoom: 2, pan: CGSize(width: 10, height: -20)), toZoom: 3, centre: centre)
        // The island point under the fingers before: (anchor - pan - centre) / zoom; after, the same.
        let before = CGPoint(x: (anchor.x - 10 - centre.x) / 2, y: (anchor.y + 20 - centre.y) / 2)
        let after = CGPoint(x: (anchor.x - pan.width - centre.x) / 3, y: (anchor.y - pan.height - centre.y) / 3)
        #expect(abs(before.x - after.x) < 0.001 && abs(before.y - after.y) < 0.001)
        #expect(PlatformScene.rubberBand(5, min: 1, max: 4) > 4)
        #expect(PlatformScene.rubberBand(5, min: 1, max: 4) < 4.3)
        #expect(PlatformScene.rubberBand(0.5, min: 1, max: 4) < 1)
        #expect(PlatformScene.rubberBand(2, min: 1, max: 4) == 2)
    }
}
