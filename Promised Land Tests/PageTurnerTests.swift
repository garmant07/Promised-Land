import Testing
import Foundation
@testable import Promised_Land

@MainActor
struct PageTurnerTests {
    let t0 = Date(timeIntervalSince1970: 5_000_000)

    @Test("Rapid taps during a turn are ignored: one tap, one page, never two at once")
    func rapidTaps() {
        var t = PageTurner()
        t.setCount(6)
        #expect(t.canTurn(by: 1, at: t0))
        t.lock(at: t0)
        t.turn(by: 1, at: t0)
        // Ten more taps while the page is still sliding: none of them count.
        for i in 1...10 { #expect(!t.canTurn(by: 1, at: t0.addingTimeInterval(Double(i) * 0.02))) }
        #expect(t.current == 1)
        t.finishTurn()
        #expect(t.canTurn(by: 1, at: t0.addingTimeInterval(0.31)))
    }

    @Test("Mashing forward and back always lands on exactly one page in range")
    func mashing() {
        var t = PageTurner()
        t.setCount(4)
        var now = t0
        for step in 0..<200 {
            let delta = step % 3 == 0 ? -1 : 1
            now = now.addingTimeInterval(0.05)
            if t.canTurn(by: delta, at: now) {
                let before = t.current
                t.lock(at: now)
                t.turn(by: delta, at: now)
                #expect(abs(t.current - before) == 1)          // one page per turn
                if step % 2 == 0 { t.finishTurn() }            // some animations finish, some lapse
            }
            #expect((0..<4).contains(t.current))
        }
    }

    @Test("The lock lapses on its own, so the pages can't get stuck")
    func lockLapses() {
        var t = PageTurner()
        t.setCount(3)
        t.lock(at: t0)
        t.turn(by: 1, at: t0)                                  // no finishTurn: the animation never reported back
        #expect(t.isTurning(at: t0.addingTimeInterval(0.2)))
        #expect(!t.isTurning(at: t0.addingTimeInterval(PageTurner.maxLock)))
        #expect(t.canTurn(by: 1, at: t0.addingTimeInterval(PageTurner.maxLock)))
    }

    @Test("Stays in range at the ends and when the page count shrinks")
    func bounds() {
        var t = PageTurner()
        t.setCount(3)
        #expect(!t.canTurn(by: -1, at: t0))                    // already on the first page
        t.jump(to: 2)
        #expect(!t.canTurn(by: 1, at: t0))                     // already on the last page
        t.setCount(2)                                          // the text re-flowed onto fewer pages
        #expect(t.current == 1)
        t.setCount(0)
        #expect(t.current == 0 && t.count == 1)
    }
}
