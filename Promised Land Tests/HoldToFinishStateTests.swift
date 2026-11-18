import Testing
@testable import Promised_Land

struct HoldToFinishStateTests {
    @Test("Completing a hold can trigger the finish action only once")
    func completingTriggersOnce() {
        var state = HoldToFinishState()
        var coverCount = 0
        var actionCount = 0

        let began = state.begin(readingTimerEnabled: false, canFinish: false)
        let completed = state.complete()
        let completedAgain = state.complete()
        #expect(began)
        if completed {
            coverCount += 1
        }
        if completedAgain {
            coverCount += 1
        }

        #expect(coverCount == 1)
        #expect(state.didComplete)

        // Model the reader's ordering: presenting the sheet while the cover is visible is blocked.
        var coverVisible = false
        func presentAfterCover() {
            guard !coverVisible else { return }
            actionCount += 1
        }

        coverVisible = completed
        presentAfterCover()
        coverVisible = false
        presentAfterCover()
        #expect(actionCount == 1)
    }

    @Test("Releasing early does not complete and resets the hold")
    func releasingEarlyResets() {
        var state = HoldToFinishState()
        var coverCount = 0
        var actionCount = 0

        let began = state.begin(readingTimerEnabled: false, canFinish: false)
        state.releaseEarly()
        let completed = state.complete()

        #expect(began)
        #expect(!state.isHolding)
        #expect(!state.didComplete)
        if completed {
            coverCount += 1
            actionCount += 1
        }

        #expect(!completed)
        #expect(coverCount == 0)
        #expect(actionCount == 0)
    }

    @Test("A timed finish cannot start until canFinish is true")
    func timedFinishRequiresGate() {
        var state = HoldToFinishState()

        let blocked = state.begin(readingTimerEnabled: true, canFinish: false)
        let stillHolding = state.isHolding
        let stillCompleted = state.didComplete
        let allowed = state.begin(readingTimerEnabled: true, canFinish: true)

        #expect(!blocked)
        #expect(!stillHolding)
        #expect(!stillCompleted)
        #expect(allowed)
    }
}
