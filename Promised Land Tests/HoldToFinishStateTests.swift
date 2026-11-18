import Testing
@testable import Promised_Land

struct HoldToFinishStateTests {
    @Test("Completing a hold can trigger the finish action only once")
    func completingTriggersOnce() {
        var state = HoldToFinishState()
        var actionCount = 0

        #expect(state.begin(readingTimerEnabled: false, canFinish: false))
        if state.complete() {
            actionCount += 1
        }
        if state.complete() {
            actionCount += 1
        }

        #expect(actionCount == 1)
        #expect(state.didComplete)
    }

    @Test("Releasing early does not complete and resets the hold")
    func releasingEarlyResets() {
        var state = HoldToFinishState()

        #expect(state.begin(readingTimerEnabled: false, canFinish: false))
        state.releaseEarly()

        #expect(!state.isHolding)
        #expect(!state.didComplete)
        #expect(!state.complete())
    }

    @Test("A timed finish cannot start until canFinish is true")
    func timedFinishRequiresGate() {
        var state = HoldToFinishState()

        #expect(!state.begin(readingTimerEnabled: true, canFinish: false))
        #expect(!state.isHolding)
        #expect(!state.didComplete)

        #expect(state.begin(readingTimerEnabled: true, canFinish: true))
    }
}
