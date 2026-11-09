import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import Promised_Land

/// Section 4j: what's on screen keeps its own pictures through a pan even if the system empties the
/// cache; people are never drawn a frame behind; turning from close in zooms out first.
@MainActor
struct PanGlitchTests {
    @Test("Turning from close in (or panned away) zooms out to the whole island first; from there it turns at once")
    func rotateZoomsOutFirst() {
        #expect(RotatePlan.steps(zoom: 3, pan: CGSize(width: 40, height: -20)) == [.zoomOut, .turn])
        #expect(RotatePlan.steps(zoom: 1.4, pan: .zero) == [.zoomOut, .turn])
        #expect(RotatePlan.steps(zoom: IslandLayout.minZoom, pan: CGSize(width: 120, height: 0)) == [.zoomOut, .turn])
        #expect(RotatePlan.steps(zoom: IslandLayout.minZoom, pan: .zero) == [.turn])
        #expect((0.4...0.6).contains(RotatePlan.zoomOutDuration))
    }

    @Test("Anyone moving redraws the people layer at once, even within one tick; a pure pan doesn't")
    func peopleNeverLag() {
        func key(pan: CGSize, feet: CGPoint) -> PeopleLayerKey {
            // As the island view builds it: positions in the world's own coordinates (view point − slide).
            let slide = PanStep.offset(pan)
            return PeopleLayerKey(drawPan: PanStep.drawPan(pan), zoom: 2, angle: 0, time: 7, people: ["me"],
                                  places: [Int(((feet.x + pan.width - slide.width) * 8).rounded()), Int(((feet.y + pan.height - slide.height) * 8).rounded())],
                                  over: [[]], facingLeft: false, avatar: 1, zooming: false, size: CGSize(width: 390, height: 844))
        }
        let feet = CGPoint(x: 100, y: 200)   // where they stand, before the pan
        // Panning within a step: the same drawing, only moved.
        #expect(key(pan: CGSize(width: 3, height: 4), feet: feet) == key(pan: CGSize(width: 21, height: -17), feet: feet))
        // Someone sets off (same tick of the clock): redrawn straight away.
        #expect(key(pan: CGSize(width: 3, height: 4), feet: feet) != key(pan: CGSize(width: 3, height: 4), feet: CGPoint(x: 101, y: 200)))
    }
}

extension ImageRenderingTests {
@MainActor @Suite
struct HeldPictureTests {
    static let island = LODTests.island
    static let size = CGSize(width: 359, height: 791)

    @Test("If the system empties the picture cache mid-pan, what's on screen keeps its own pictures (no stand-ins)")
    func survivesMemoryWarning() {
        let cache = IslandRenderCache.shared
        defer { cache.removeAll(); cache.interacting = false }
        let canvas = CGRect(origin: .zero, size: PanStep.canvasSize(Self.size))
        func frame(_ pan: CGSize) -> IslandRenderCache.Frame? {
            cache.frame(island: Self.island, size: Self.size, insets: EdgeInsets(), zoom: 3, quarter: 0, pan: PanStep.drawPan(pan),
                        overrides: [:], hidden: [], viewport: canvas, deferMissing: true)
        }
        let start = CGSize(width: 10, height: 10)
        _ = frame(start)                 // the view as it is (rendered)
        cache.interacting = true         // a finger is down
        cache.simulateMemoryWarning()    // the system empties the cache
        let before = cache.renders
        // Panning within the same step: everything drawn is still this zoom's own picture.
        for i in 0..<20 {
            let f = frame(CGSize(width: start.width + CGFloat(i), height: start.height - CGFloat(i)))
            #expect(f?.ground.allSatisfy { $0.clip == nil } == true, "a stand-in was drawn on frame \(i)")
            #expect(cache.pendingCount == 0)
        }
        #expect(cache.renders == before)
    }
}
}
