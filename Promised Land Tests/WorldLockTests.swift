import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import Promised_Land

/// Section 4f: people are drawn in the same place and the same coordinates as the land they stand
/// on (one world, moved by one offset), so through pans, zooms and walking each keeps exactly its
/// place on its tile; and a fast pan moves the camera smoothly, exactly with the finger.
@MainActor
struct WorldLockTests {
    static let size = CGSize(width: 390, height: 844)
    static let island = LODTests.island

    /// Where something at grid point `g` ends up on screen, drawn as the island view draws people:
    /// worked out in view points, drawn in the world's coordinates (translated by −slide), then the
    /// whole world moved by +slide.
    func personOnScreen(_ g: CGPoint, layout: IslandLayout, pan: CGSize) -> CGPoint {
        let slide = PanStep.offset(pan)
        let inWorld = CGPoint(x: layout.point(g.x, g.y).x - slide.width, y: layout.point(g.x, g.y).y - slide.height)
        return CGPoint(x: inWorld.x + slide.width, y: inWorld.y + slide.height)
    }

    /// Where the ground under grid point `g` ends up on screen: drawn in the world's coordinates at
    /// the rounded pan, then the whole world moved by +slide.
    func groundOnScreen(_ g: CGPoint, base: IslandLayout, pan: CGSize) -> CGPoint {
        let inWorld = base.panned(PanStep.drawPan(pan)).point(g.x, g.y)
        let slide = PanStep.offset(pan)
        return CGPoint(x: inWorld.x + slide.width, y: inWorld.y + slide.height)
    }

    @Test("Through fast pans, zooms and walking, everyone keeps exactly their place on their tile", arguments: [0, 1, 2, 3])
    func peopleStayOnTheirTiles(quarter: Int) throws {
        let character = try #require(IslandCharacter.make(CharacterJourneys.all, island: Self.island).first)
        var rng = SeededRandom(seed: UInt64(40 + quarter))
        var pan = CGSize.zero, zoom: CGFloat = 2
        for frame in 0..<240 {
            // A shaky pan (up to 120 points a frame) with a pinch in and out on top.
            pan = CGSize(width: pan.width + rng.next(in: -120...120), height: pan.height + rng.next(in: -120...120))
            zoom = max(1, min(8, zoom * CGFloat(1 + rng.next(in: -0.08...0.08))))
            let base = IslandLayout(island: Self.island, size: Self.size, zoom: zoom, angle: CGFloat(quarter))
            let layout = base.panned(pan)
            // Walking: a Bible character's own path, a sixtieth of a second further each frame.
            let g = character.position(at: 1000 + Double(frame) / 60)
            let tile = CGPoint(x: floor(g.x) + 0.5, y: floor(g.y) + 0.5)
            let person = personOnScreen(g, layout: layout, pan: pan)
            let ground = groundOnScreen(tile, base: base, pan: pan)
            // Their offset from the middle of the tile they're on is exactly the grid offset, at this zoom and turn.
            let want = CGPoint(x: layout.point(g.x, g.y).x - layout.point(tile.x, tile.y).x, y: layout.point(g.x, g.y).y - layout.point(tile.x, tile.y).y)
            #expect(abs(person.x - ground.x - want.x) < 0.0001 && abs(person.y - ground.y - want.y) < 0.0001, "frame \(frame)")
        }
    }

    @Test("A fast pan moves the camera exactly with the finger, smoothly frame to frame")
    func fastPanIsSmooth() {
        var rng = SeededRandom(seed: 77)
        let panStart = CGSize(width: 12, height: -30)
        var translation = CGSize.zero
        var lastShown = panStart
        for _ in 0..<300 {
            // Touch updates of up to 80 points (a fast flick back and forth).
            let step = CGSize(width: rng.next(in: -80...80), height: rng.next(in: -80...80))
            translation = CGSize(width: translation.width + step.width, height: translation.height + step.height)
            let pan = CGSize(width: panStart.width + translation.width, height: panStart.height + translation.height)
            // What's on screen: drawn at the rounded pan and slid by the rest; together exactly the pan.
            let shown = CGSize(width: PanStep.drawPan(pan).width + PanStep.offset(pan).width,
                               height: PanStep.drawPan(pan).height + PanStep.offset(pan).height)
            #expect(abs(shown.width - pan.width) < 0.0001 && abs(shown.height - pan.height) < 0.0001)
            // It moved exactly as far as the finger did: nothing added, nothing lagging behind.
            #expect(abs((shown.width - lastShown.width) - step.width) < 0.0001 && abs((shown.height - lastShown.height) - step.height) < 0.0001)
            lastShown = shown
        }
    }
}
