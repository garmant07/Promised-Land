import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import Promised_Land

extension ImageRenderingTests {
/// Section 4h: every part of the island is drawn once (no blurry copy behind a sharp one), and a
/// drag follows the finger without jumps.
@MainActor @Suite
struct OneImageTests {
    static let island = LODTests.island
    static let insets = EdgeInsets(top: 120, leading: 8, bottom: 118, trailing: 8)
    /// Its own view size, so the shared picture cache starts cold for it.
    static let size = CGSize(width: 367, height: 803)

    /// What the island view makes when it first appears: the whole-island overview (the ground alone).
    func overviews(quarter: Int) {
        let cache = IslandRenderCache.shared
        let everything = CGRect(x: -20_000, y: -20_000, width: 40_000, height: 40_000)
        while !cache.prewarm(island: Self.island, size: Self.size, insets: Self.insets, zoom: IslandRenderCache.overviewZoom,
                             quarter: quarter, pan: .zero, bake: false, viewport: everything, groundOnly: true) { cache.drainNow() }
    }

    /// Overlap area of two rects (0 if they only touch).
    func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b)
        return i.isNull ? 0 : i.width * i.height
    }

    /// One frame of the ground layer: nothing drawn twice.
    func checkOnce(zoom: CGFloat, pan: CGSize, quarter: Int, note: String) {
        guard let f = IslandRenderCache.shared.frame(island: Self.island, size: Self.size, insets: Self.insets, zoom: zoom, quarter: quarter,
                                                     pan: pan, overrides: [:], hidden: [], deferMissing: true) else { return }
        // Close in, the buildings are drawn sharp on their own: never ground with buildings baked in under them.
        if !f.baked {
            #expect(f.bakedGround.isEmpty, "\(note): a baked stand-in under sharp buildings (zoom \(zoom), turn \(quarter))")
            #expect(f.layerClip == nil)
        }
        // Each bit of ground once: where they're drawn, no two ground pictures overlap.
        let drawn = f.ground.map { g in g.clip.map { g.rect.intersection($0) } ?? g.rect }.filter { !$0.isNull }
        var worst: CGFloat = 0
        for i in drawn.indices { for j in drawn.indices where j > i { worst = max(worst, overlap(drawn[i], drawn[j])) } }
        #expect(worst < 1, "\(note): two ground pictures overlap by \(worst) pt² (zoom \(zoom), turn \(quarter))")
        // Far out, buildings drawn on their own only inside ground that has none, never over a baked copy.
        if f.baked, !f.layers.isEmpty {
            let clip = f.layerClip ?? []
            #expect(!clip.isEmpty, "\(note): buildings drawn over baked ground")
            for r in clip { for b in f.bakedGround { #expect(overlap(r, b) < 1, "\(note): buildings over their baked copy") } }
        }
    }

    @Test("Pinch right out and back in: every frame draws each part of the island once", arguments: [0, 1, 2, 3])
    func pinchOutAndIn(quarter: Int) {
        let cache = IslandRenderCache.shared
        defer { cache.removeAll(); cache.interacting = false }
        overviews(quarter: quarter)
        cache.interacting = true   // mid-gesture: stand-ins wherever this zoom isn't ready
        let centre = IslandCamera.freeCentre(size: Self.size, insets: Self.insets)
        let limit = IslandLayout.maxZoom(island: Self.island, size: Self.size, insets: Self.insets)
        let anchor = CGPoint(x: 160, y: 400)
        var zoom = limit * 0.8, pan = CGSize.zero
        var path: [CGFloat] = []
        var z = zoom
        while z > IslandLayout.minZoom { z = max(IslandLayout.minZoom, z / 1.1); path.append(z) }
        while z < limit * 0.8 { z = min(limit * 0.8, z * 1.1); path.append(z) }
        for next in path {
            pan = PlatformScene.panKeeping(anchor, from: (zoom, pan), toZoom: next, centre: centre)
            zoom = next
            checkOnce(zoom: zoom, pan: pan, quarter: quarter, note: "pinch")
        }
    }

    @Test("Tap-to-zoom in and back out: every frame draws each part of the island once", arguments: [0, 1, 2, 3])
    func tapToZoom(quarter: Int) throws {
        let cache = IslandRenderCache.shared
        defer { cache.removeAll(); cache.interacting = false }
        overviews(quarter: quarter)
        cache.interacting = true
        let item = try #require(Self.island.items.first { $0.plotKey != nil && $0.kind.isTall })
        let toZoom = IslandCamera.visitZoom(for: item, in: Self.island, size: Self.size, insets: Self.insets, quarter: quarter)
        let toPan = IslandCamera.pan(toCentre: IslandCamera.focus(of: item, in: Self.island), island: Self.island, size: Self.size,
                                     insets: Self.insets, zoom: toZoom, quarter: quarter)
        for glide in [CameraGlide(fromZoom: 1, toZoom: toZoom, fromPan: .zero, toPan: toPan, start: 0, duration: PlatformScene.visitGlide),
                      CameraGlide(fromZoom: toZoom, toZoom: 1, fromPan: toPan, toPan: .zero, start: 0, duration: 0.5)] {
            var t = 0.0
            while true {
                let c = glide.camera(at: t)
                checkOnce(zoom: c.zoom, pan: c.pan, quarter: quarter, note: "tap-to-zoom")
                if glide.isDone(at: t) { break }
                t += 1.0 / 30
            }
        }
    }

    @Test("Slow and fast drags follow the finger 1:1, with no jump as a tap becomes a pan", arguments: [0.4, 6.0, 45.0])
    func dragFollowsFinger(step: Double) {
        var drag = DragPan()
        let start = CGSize(width: -40, height: 25)
        var translation = CGSize.zero
        var last: (pan: CGSize, translation: CGSize)?
        var rng = SeededRandom(seed: UInt64(step * 10))
        for _ in 0..<200 {
            // The finger moves `step` points a touch update, wobbling in direction.
            let a = rng.next(in: -0.6...0.6)
            translation = CGSize(width: translation.width + step * cos(a), height: translation.height + step * sin(a))
            guard let pan = drag.pan(start: start, translation: translation) else { continue }
            if let last {
                // Exactly as far as the finger, every update.
                #expect(abs((pan.width - last.pan.width) - (translation.width - last.translation.width)) < 0.0001)
                #expect(abs((pan.height - last.pan.height) - (translation.height - last.translation.height)) < 0.0001)
            } else {
                // The first moment it's a pan, the island hasn't moved yet: no leap of the tap slop.
                #expect(pan == start)
            }
            last = (pan, translation)
        }
        #expect(last != nil)
    }

    @Test("Letting go: the glide starts at exactly the finger's speed, and lands without a jump")
    func releaseHandOff() {
        let pan = CGSize(width: 100, height: -50)
        for v in [CGSize(width: 900, height: 0), CGSize(width: -2400, height: 1300), CGSize(width: 150, height: 90)] {
            let target = DragPan.glideTarget(from: pan, velocity: v)
            let glide = CameraGlide(fromZoom: 2, toZoom: 2, fromPan: pan, toPan: target, start: 0, duration: DragPan.glideDuration, easeOut: true)
            // Starts where the finger left it, at its speed.
            #expect(glide.camera(at: 0).pan == pan)
            let dt = 0.0005
            let early = glide.camera(at: dt).pan
            let speed = CGSize(width: (early.width - pan.width) / dt, height: (early.height - pan.height) / dt)
            #expect(abs(speed.width - v.width) < abs(v.width) * 0.01 + 1 && abs(speed.height - v.height) < abs(v.height) * 0.01 + 1)
            #expect(glide.camera(at: DragPan.glideDuration).pan == target)
        }
    }
}
}
