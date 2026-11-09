import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import Promised_Land

extension ImageRenderingTests {
/// Section 4g: no frame of a gesture is spent rendering pictures, less is drawn the further out you
/// are, and once the island has appeared the first pan needs nothing new.
@MainActor @Suite
struct ZoomOutPerformanceTests {
    static let island = LODTests.island
    static let insets = EdgeInsets(top: 120, leading: 8, bottom: 118, trailing: 8)
    /// Its own view size, so the shared picture cache starts cold for it.
    static let size = CGSize(width: 371, height: 811)

    /// What the island view does when it first appears: the whole-island overview, then the
    /// pictures around the starting view (a screen further each way).
    func preload(zoom: CGFloat, pan: CGSize, quarter: Int) {
        let cache = IslandRenderCache.shared
        let everything = CGRect(x: -20_000, y: -20_000, width: 40_000, height: 40_000)
        while !cache.prewarm(island: Self.island, size: Self.size, insets: Self.insets, zoom: IslandRenderCache.overviewZoom,
                             quarter: quarter, pan: .zero, bake: true, viewport: everything) { cache.drainNow() }
        let canvas = CGRect(origin: .zero, size: PanStep.canvasSize(Self.size))
        let around = canvas.insetBy(dx: -Self.size.width, dy: -Self.size.height)
        while !cache.prewarm(island: Self.island, size: Self.size, insets: Self.insets, zoom: zoom, quarter: quarter,
                             pan: PanStep.drawPan(pan), bake: true, viewport: around) { cache.drainNow() }
    }

    func frame(zoom: CGFloat, pan: CGSize, quarter: Int) -> IslandRenderCache.Frame? {
        IslandRenderCache.shared.frame(island: Self.island, size: Self.size, insets: Self.insets, zoom: zoom, quarter: quarter,
                                       pan: PanStep.drawPan(pan), overrides: [:], hidden: [],
                                       viewport: CGRect(origin: .zero, size: PanStep.canvasSize(Self.size)), deferMissing: true)
    }

    @Test("A full pinch out renders no picture in any of its frames (the overview stands in)", arguments: [0, 1, 2, 3])
    func zoomOutRendersNothing(quarter: Int) {
        let cache = IslandRenderCache.shared
        defer { cache.removeAll(); cache.interacting = false }
        let start: CGFloat = 8
        preload(zoom: start, pan: .zero, quarter: quarter)
        cache.interacting = true   // a finger is down
        let before = cache.renders
        var zoom = start
        let centre = IslandCamera.freeCentre(size: Self.size, insets: Self.insets)
        var pan = CGSize.zero
        while zoom > IslandLayout.minZoom {
            let next = max(IslandLayout.minZoom, zoom / 1.08)
            pan = PlatformScene.panKeeping(CGPoint(x: 150, y: 420), from: (zoom, pan), toZoom: next, centre: centre)
            zoom = next
            #expect(frame(zoom: zoom, pan: pan, quarter: quarter) != nil)
        }
        #expect(cache.renders == before, "\(cache.renders - before) pictures rendered mid-gesture")
    }

    @Test("Less is drawn the further out you are")
    func lessFarOut() {
        let cache = IslandRenderCache.shared
        defer { cache.removeAll() }
        preload(zoom: 1, pan: .zero, quarter: 0)
        let director = LifeDirector()
        let life = LODTests.life
        var counts: [(zoom: CGFloat, drawn: Int)] = []
        for zoom: CGFloat in [8, 4, 2, 1] {
            // Items and pictures drawn, plus villagers and travellers showing (after their fades settle).
            let layout = IslandLayout(island: Self.island, size: Self.size, insets: Self.insets, zoom: zoom)
            let screen = CGRect(origin: .zero, size: Self.size)
            var shown: [LifeDirector.Shown] = []
            for f in 0..<40 {
                let t = 2000 + Double(f) / 60 + Double(zoom) * 10
                director.begin(now: t, u: layout.u)
                shown = director.plan(life.figures(layout: layout, viewport: screen), now: t, viewport: screen)
            }
            let f = frame(zoom: zoom, pan: .zero, quarter: 0)
            counts.append((zoom, (f?.layers.count ?? 0) + (f?.ground.count ?? 0) + shown.count))
        }
        #expect(counts.last!.drawn < counts.first!.drawn, "\(counts)")
        // Far out: no villagers or travellers at all, and buildings come as part of the ground.
        let far = IslandLayout(island: Self.island, size: Self.size, insets: Self.insets, zoom: 1)
        #expect(IslandLOD.tier(u: far.u, previous: .middle) == .far)
        #expect(frame(zoom: 1, pan: .zero, quarter: 0)?.layers.isEmpty == true)
    }

    @Test("Detail switches with a buffer: zooming back and forth at one level doesn't flip it")
    func detailHasABuffer() {
        let at = (IslandLOD.middleShow + IslandLOD.middleHide) / 2
        // Between the two thresholds the level stays whatever it was.
        #expect(IslandLOD.tier(u: at, previous: .far) == .far)
        #expect(IslandLOD.tier(u: at, previous: .middle) == .middle)
    }

    @Test("After the island appears, the first pan (a screen each way) needs no new pictures")
    func firstPanNeedsNothing() {
        let cache = IslandRenderCache.shared
        defer { cache.removeAll() }
        let zoom: CGFloat = 4
        preload(zoom: zoom, pan: .zero, quarter: 0)
        let before = cache.renders
        // Side to side, a whole screen each way, a frame at a time.
        for i in 0...120 {
            let x = sin(Double(i) / 120 * 2 * .pi) * Double(Self.size.width)
            _ = frame(zoom: zoom, pan: CGSize(width: x, height: x * 0.3), quarter: 0)
            // Everything it showed was this zoom's own picture: nothing stood in, nothing waits.
            #expect(cache.pendingCount == 0, "frame \(i) is waiting for \(cache.pendingCount) pictures")
        }
        #expect(cache.renders == before, "\(cache.renders - before) pictures rendered during the first pan")
    }
}
}
