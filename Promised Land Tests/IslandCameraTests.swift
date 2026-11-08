import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import Promised_Land

/// The island camera (centring), depth (who is behind a building) and panning, at every turn.
@MainActor
struct IslandCameraTests {
    static let size = CGSize(width: 390, height: 844)
    static let insets = EdgeInsets(top: 120, leading: 8, bottom: 118, trailing: 8)
    static let island = LODTests.island
    static let life = LODTests.life

    /// The tall buildings that have a footprint (Place pieces, the Library).
    static var buildings: [Island.Item] {
        island.items.filter { $0.kind.isTall && $0.footprint.width >= 1 }
    }

    @Test("Centring puts a building's middle at the middle of the screen, at every turn and zoom", arguments: [0, 1, 2, 3])
    func centring(quarter: Int) throws {
        let centre = IslandCamera.freeCentre(size: Self.size, insets: Self.insets)
        for item in Self.buildings.prefix(40) {
            let focus = IslandCamera.focus(of: item, in: Self.island)
            for zoom: CGFloat in [1, 3, 6] {
                let pan = IslandCamera.pan(toCentre: focus, island: Self.island, size: Self.size, insets: Self.insets,
                                           zoom: zoom, quarter: quarter)
                let layout = IslandLayout(island: Self.island, size: Self.size, insets: Self.insets, zoom: zoom,
                                          angle: CGFloat(quarter)).panned(pan)
                let p = layout.point(focus.x, focus.y)
                #expect(abs(p.x - centre.x) < 0.01 && abs(p.y - centre.y) < 0.01)
                // The pan limit always allows it.
                let reach = IslandCamera.reach(island: Self.island, size: Self.size, insets: Self.insets, zoom: zoom)
                #expect(abs(pan.width) <= reach.width && abs(pan.height) <= reach.height)
            }
        }
    }

    @Test("A building's focus is the middle of its Place, not wherever the tapped piece stands")
    func focusIsThePlace() throws {
        let piece = try #require(Self.island.items.first { $0.plotKey != nil && $0.plotKey != IslandPlacement.libraryKey })
        let plot = try #require(Self.island.allPlots.first { $0.bookID == piece.plotKey })
        #expect(IslandCamera.focus(of: piece, in: Self.island) == plot.centre)
    }

    /// A point just outside a footprint's corner that is highest (back), lowest (front), or
    /// furthest right (beside) on screen.
    private func outside(_ item: Island.Item, layout: IslandLayout, pick: (CGPoint, CGPoint) -> Bool) -> CGPoint {
        let f = IslandCamera.footprint(of: item)
        let corners = [CGPoint(x: f.minX, y: f.minY), CGPoint(x: f.maxX, y: f.minY), CGPoint(x: f.minX, y: f.maxY), CGPoint(x: f.maxX, y: f.maxY)]
        let corner = corners.max { pick(layout.point($1.x, $1.y), layout.point($0.x, $0.y)) }!
        let c = CGPoint(x: f.midX, y: f.midY)
        // A quarter of a tile further out from the middle, through that corner.
        let d = CGPoint(x: corner.x - c.x, y: corner.y - c.y), n = max(0.001, hypot(d.x, d.y))
        let g = CGPoint(x: corner.x + d.x / n * 0.25, y: corner.y + d.y / n * 0.25)
        return layout.point(g.x, g.y)
    }

    @Test("Someone behind a building is drawn behind it; in front or beside, they aren't", arguments: [0, 1, 2, 3])
    func depth(quarter: Int) throws {
        let layout = IslandLayout(island: Self.island, size: Self.size, insets: Self.insets, zoom: 4, angle: CGFloat(quarter))
        for item in Self.buildings.prefix(40) {
            let back = outside(item, layout: layout) { $0.y < $1.y }    // highest on screen
            let front = outside(item, layout: layout) { $0.y > $1.y }   // lowest on screen
            let side = outside(item, layout: layout) { $0.x > $1.x }    // furthest right
            #expect(IslandCamera.isBehind(feet: back, item: item, layout: layout))
            #expect(!IslandCamera.isBehind(feet: front, item: item, layout: layout))
            #expect(!IslandCamera.isBehind(feet: side, item: item, layout: layout))
            // Sorting agrees: anyone behind sorts before the building.
            #expect(back.y < IslandCamera.frontDepth(of: item, layout: layout))
        }
    }

    @Test("A character standing just behind a building is drawn under it, even past its middle", arguments: [0, 1, 2, 3])
    func characterBehindIsHidden(quarter: Int) throws {
        var checked = 0
        for item in Self.buildings.prefix(60) {
            // Looking straight at the building.
            let pan = IslandCamera.pan(toCentre: IslandCamera.focus(of: item, in: Self.island), island: Self.island, size: Self.size,
                                       insets: Self.insets, zoom: 4, quarter: quarter)
            let layout = IslandLayout(island: Self.island, size: Self.size, insets: Self.insets, zoom: 4, angle: CGFloat(quarter)).panned(pan)
            let u = layout.u
            let f = IslandCamera.footprint(of: item)
            // Feet inside the footprint's back half, but lower on screen than the building's anchor
            // (the case the old anchor test drew on top).
            let front = IslandCamera.front(of: item, layout: layout)
            let anchor = layout.point(item.gx, item.gy)
            guard let g = [CGPoint(x: f.midX, y: f.midY)].first else { continue }
            let feet = CGPoint(x: layout.point(g.x, g.y).x, y: anchor.y + 2)
            guard IslandCamera.turned(feet, layout: layout).x < front.x, IslandCamera.turned(feet, layout: layout).y < front.y else { continue }
            let figure = CGRect(x: feet.x - 4 * u, y: feet.y - 15 * u, width: 8 * u, height: 15 * u)
            let drawnOver = PlatformScene.occluders([item], figures: [figure], layout: layout,
                                                    viewport: CGRect(origin: .zero, size: Self.size), onlyIfNoneInFront: true)
            if layout.point(item.gx, item.gy).x.isFinite, IslandPainter.drawnBounds(of: item, layout: layout).intersects(figure) {
                #expect(drawnOver.count == 1, "\(item.kind) at turn \(quarter)")
                checked += 1
            }
        }
        #expect(checked > 0)
    }

    /// Runs the director through a settle and then a hard wiggle (up to 60 points either way,
    /// every frame) at `zoom`, calling `check` on every frame of the wiggle.
    private func wiggle(zoom: CGFloat, check: ([LifeDirector.Shown], [String: LifeDirector.Figure], CGRect) throws -> Void) rethrows {
        let base = IslandLayout(island: Self.island, size: Self.size, zoom: zoom)
        let director = LifeDirector()
        let screen = CGRect(origin: .zero, size: Self.size)
        let viewport = screen.insetBy(dx: -PlatformScene.lifeMargin, dy: -PlatformScene.lifeMargin)
        var rng = SeededRandom(seed: 7)
        var t = 1000.0
        func frame(pan: CGSize) -> ([LifeDirector.Shown], [String: LifeDirector.Figure]) {
            t += 1.0 / 60
            let layout = base.panned(pan)
            director.begin(now: t, u: layout.u)
            let figures = Self.life.figures(layout: layout, viewport: viewport)
            let shown = director.plan(figures, now: t, viewport: viewport, screen: screen)
            return (shown, Dictionary(figures.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }))
        }
        for _ in 0..<40 { _ = frame(pan: .zero) }
        for _ in 0..<180 {
            let pan = CGSize(width: CGFloat(rng.next(in: -60...60)), height: CGFloat(rng.next(in: -60...60)))
            let (shown, figures) = frame(pan: pan)
            try check(shown, figures, screen)
        }
    }

    @Test("Rapid shaky panning: every figure is drawn exactly where it is, and none on screen flickers")
    func rapidPans() throws {
        // Close in on the full island: more figures nearby than the cap, so the cap is in play.
        let zoom = (IslandLOD.closeShow + 0.6) / IslandLayout(island: Self.island, size: Self.size).u
        var fullyShown: Set<String> = []
        var checked = 0
        try wiggle(zoom: zoom) { shown, figures, screen in
            var now: Set<String> = []
            for s in shown {
                let figure = try #require(figures[s.id])
                #expect(figure.position(s.time) == s.point)          // drawn exactly where it is now
                if screen.contains(s.point) && s.opacity == 1 { now.insert(s.id) }
                checked += 1
            }
            // Anyone fully shown on screen stays fully shown while still on screen (no flicker): a
            // fade-out always starts with a frame below 1, so it would show up here.
            for id in fullyShown where !now.contains(id) {
                if let s = shown.first(where: { $0.id == id }) { #expect(!screen.contains(s.point) || s.opacity == 1, "\(id) flickered") }
            }
            fullyShown = now
        }
        #expect(checked > 0)
    }

    @Test("Rapid shaky panning closer in: everyone on screen is fully there, none fades in late at an edge")
    func noEdgePopIn() throws {
        let zoom = (IslandLOD.closeShow + 2.5) / IslandLayout(island: Self.island, size: Self.size).u
        var checked = 0
        wiggle(zoom: zoom) { shown, _, screen in
            let onScreen = shown.filter { screen.contains($0.point) }
            #expect(onScreen.count < IslandLOD.closeCap)              // the cap isn't what's deciding here
            for s in onScreen {
                #expect(s.opacity == 1, "\(s.id) faded in on screen: \(s.opacity) at \(s.point)")
                checked += 1
            }
        }
        #expect(checked > 0)
    }

    @Test("Birds fly in the island's space: they move with the pan and turn with the island")
    func birdsInWorldSpace() {
        let sky = Self.life.sky
        let mid = IslandLife.birdPoint(0.5, sky: sky)
        #expect(abs(mid.x - sky.midX) < 0.01 && abs(mid.y - sky.midY) < 0.01)   // over the island's middle
        let layout = IslandLayout(island: Self.island, size: Self.size, zoom: 2)
        let a = layout.point(mid.x, mid.y), b = layout.panned(CGSize(width: 50, height: -30)).point(mid.x, mid.y)
        #expect(abs(b.x - a.x - 50) < 0.001 && abs(b.y - a.y + 30) < 0.001)
        let turned = IslandLayout(island: Self.island, size: Self.size, zoom: 2, angle: 1)
        let start = IslandLife.birdPoint(0, sky: sky)
        #expect(layout.point(start.x, start.y) != turned.point(start.x, start.y))
    }
}

/// A small seeded generator, so the wiggle is the same every run.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return range.lowerBound + Double(state % 1_000_000) / 1_000_000 * (range.upperBound - range.lowerBound)
    }
}
