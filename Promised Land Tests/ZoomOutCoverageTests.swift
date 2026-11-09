import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import Promised_Land

/// Section 4e: zooming right in and then right out (a pinch, or tap-to-zoom and back) never leaves
/// land on screen undrawn, at any turn: every frame along the way draws the ground under every tile
/// in view and every building in view, worked out from the camera at that moment.
@MainActor
struct ZoomOutCoverageTests {
    static let island = LODTests.island
    static let insets = EdgeInsets(top: 120, leading: 8, bottom: 118, trailing: 8)

    /// A view size of its own, so the shared picture cache starts cold (as after launch); each turn
    /// has its own pictures anyway. The cache is emptied afterwards: these render a lot.
    static func size(_ n: Int) -> CGSize { CGSize(width: 380 + CGFloat(n), height: 830 + CGFloat(n)) }

    /// Checks one frame of the island as the ground layer draws it (live camera, missing pictures
    /// drawn from another zoom meanwhile): no tile or building in view is left out.
    func checkFrame(size: CGSize, zoom: CGFloat, pan: CGSize, quarter: Int, note: String) {
        let cache = IslandRenderCache.shared
        guard let frame = cache.frame(island: Self.island, size: size, insets: Self.insets, zoom: zoom, quarter: quarter, pan: pan,
                                      overrides: [:], hidden: [], deferMissing: true) else { Issue.record("no frame"); return }
        let layout = IslandLayout(island: Self.island, size: size, insets: Self.insets, zoom: zoom, angle: CGFloat(quarter)).panned(pan)
        let view = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
        // Ground under every tile in view.
        var missingTiles = 0, tilesInView = 0
        for t in Self.island.tiles {
            let p = layout.point(CGFloat(t.x) + 0.5, CGFloat(t.y) + 0.5)
            guard view.contains(p) else { continue }
            tilesInView += 1
            if !frame.ground.contains(where: { $0.rect.contains(p) }) { missingTiles += 1 }
        }
        #expect(missingTiles == 0, "\(note): \(missingTiles) of \(tilesInView) tiles in view with no ground (zoom \(zoom), turn \(quarter))")
        // Every building in view: in ground that includes buildings, in a Place picture, or drawn as an item.
        var missingPlaces = 0
        for plot in Self.island.allPlots {
            let p = layout.point(plot.centre.x, plot.centre.y)
            guard view.contains(p) else { continue }
            let inBakedGround = frame.bakedGround.contains { $0.contains(p) }
            let inPicture = frame.layers.contains { layer in
                switch layer {
                case .picture(_, let r): return r.contains(p)
                case .item(let item): return item.plotKey == plot.bookID
                }
            }
            if !inBakedGround && !inPicture { missingPlaces += 1 }
        }
        #expect(missingPlaces == 0, "\(note): \(missingPlaces) Places in view not drawn (zoom \(zoom), turn \(quarter))")
    }

    @Test("Pinch right in, then right out: every frame draws all the land and buildings in view", arguments: [0, 1, 2, 3])
    func pinchInThenOut(quarter: Int) {
        defer { IslandRenderCache.shared.removeAll() }
        let size = Self.size(0)
        let centre = IslandCamera.freeCentre(size: size, insets: Self.insets)
        let limit = IslandLayout.maxZoom(island: Self.island, size: size, insets: Self.insets)
        let anchor = CGPoint(x: size.width * 0.45, y: size.height * 0.5)
        var zoom: CGFloat = 1, pan = CGSize.zero
        // In, about the fingers, a frame at a time.
        while zoom < limit * 0.9 {
            let next = min(limit * 0.9, zoom * 1.12)
            pan = PlatformScene.panKeeping(anchor, from: (zoom, pan), toZoom: next, centre: centre)
            zoom = next
            checkFrame(size: size, zoom: zoom, pan: pan, quarter: quarter, note: "pinching in")
        }
        // And all the way back out (nothing rendered in the background meanwhile: the worst case).
        while zoom > IslandLayout.minZoom * 0.8 {
            let next = max(IslandLayout.minZoom * 0.8, zoom / 1.12)
            pan = PlatformScene.panKeeping(anchor, from: (zoom, pan), toZoom: next, centre: centre)
            zoom = next
            checkFrame(size: size, zoom: zoom, pan: pan, quarter: quarter, note: "pinching out")
        }
    }

    @Test("Tap-to-zoom up to a building and back: every frame draws all the land and buildings in view", arguments: [0, 1, 2, 3])
    func tapToZoomAndBack(quarter: Int) throws {
        defer { IslandRenderCache.shared.removeAll() }
        let size = Self.size(1)
        let item = try #require(Self.island.items.first { $0.plotKey != nil && $0.kind.isTall })
        let toZoom = IslandCamera.visitZoom(for: item, in: Self.island, size: size, insets: Self.insets, quarter: quarter)
        let toPan = IslandCamera.pan(toCentre: IslandCamera.focus(of: item, in: Self.island), island: Self.island, size: size,
                                     insets: Self.insets, zoom: toZoom, quarter: quarter)
        let there = CameraGlide(fromZoom: 1, toZoom: toZoom, fromPan: .zero, toPan: toPan, start: 0, duration: PlatformScene.visitGlide)
        let back = CameraGlide(fromZoom: toZoom, toZoom: 1, fromPan: toPan, toPan: .zero, start: 0, duration: 0.5)
        for (glide, note) in [(there, "stepping up"), (back, "coming back")] {
            var t = 0.0
            while true {
                let c = glide.camera(at: t)
                checkFrame(size: size, zoom: c.zoom, pan: c.pan, quarter: quarter, note: note)
                if glide.isDone(at: t) { break }
                t += 1.0 / 30
            }
        }
    }
}
