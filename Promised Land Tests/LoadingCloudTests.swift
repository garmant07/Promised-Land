import Testing
import Foundation
import CoreGraphics
@testable import Promised_Land

/// Section 4i: the clouds part only once the island has loaded and run smoothly (never stuck, never a
/// flash), and a pan within a step doesn't redraw the people layer (it only moves with the world).
@MainActor
struct LoadingCloudTests {
    @Test("The clouds wait for loading and smooth frames, show for a minimum, and never get stuck")
    func gate() {
        var g = LoadingGate(started: 0)
        for i in 0..<30 { g.frame(duration: 1.0 / 60); #expect(!g.shouldPart(at: Double(i) * 0.1)) }  // not loaded yet
        g.markLoaded()
        for _ in 0..<(LoadingGate.smoothFramesNeeded - 1) { g.frame(duration: 1.0 / 60) }
        g.frame(duration: 0.2)                                         // a long frame starts the count again
        #expect(!g.shouldPart(at: 3))
        for _ in 0..<LoadingGate.smoothFramesNeeded { g.frame(duration: 1.0 / 60) }
        #expect(g.shouldPart(at: 3))
        var quick = LoadingGate(started: 0)
        quick.markLoaded()
        for _ in 0..<20 { quick.frame(duration: 1.0 / 60) }
        #expect(!quick.shouldPart(at: 0.3))                            // a short minimum, no flash
        #expect(quick.shouldPart(at: LoadingGate.minimum))
        #expect(LoadingGate(started: 0).shouldPart(at: LoadingGate.maximum))  // never stuck
    }

    @Test("Panning within a step leaves the people layer as it is (only the shared offset moves)")
    func peopleLayerHoldsStill() {
        func key(_ pan: CGSize) -> PeopleLayerKey {
            PeopleLayerKey(drawPan: PanStep.drawPan(pan), zoom: 1, angle: 0, time: 5, people: ["me"], places: [80, 80], over: [[]],
                           facingLeft: false, avatar: 1, zooming: false, size: CGSize(width: 390, height: 844))
        }
        #expect(key(CGSize(width: 10, height: 5)) == key(CGSize(width: 30, height: -20)))   // same step: not redrawn
        #expect(key(CGSize(width: 10, height: 5)) != key(CGSize(width: 200, height: 5)))    // next step: redrawn
    }
}
