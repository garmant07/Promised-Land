import Testing
@testable import Promised_Land

struct FirstJourneyTests {
    @Test("An existing player is never eligible for the first-time journey")
    func existingPlayerIsDone() {
        let defaults = UserDefaults(suiteName: "FirstJourneyTests.existing")!
        defaults.removePersistentDomain(forName: "FirstJourneyTests.existing")
        defaults.set(FirstJourneyStep.notStarted.rawValue, forKey: FirstJourneyStore.stepKey)

        #expect(FirstJourneyStore.bootstrap(hasOnboarded: true, defaults: defaults) == .done)
        #expect(defaults.string(forKey: FirstJourneyStore.stepKey) == FirstJourneyStep.done.rawValue)
    }

    @Test("Finishing onboarding starts the journey at welcome")
    func finishingOnboardingStartsWelcome() {
        let defaults = UserDefaults(suiteName: "FirstJourneyTests.finish")!
        defaults.removePersistentDomain(forName: "FirstJourneyTests.finish")

        FirstJourneyStore.finishOnboarding(defaults: defaults)

        #expect(defaults.integer(forKey: FirstJourneyStore.versionKey) == FirstJourneyStore.version)
        #expect(defaults.string(forKey: FirstJourneyStore.stepKey) == FirstJourneyStep.welcome.rawValue)
    }

    @Test("The first-time journey advances in order")
    func advancesInOrder() {
        #expect(FirstJourneyTransition.advance(.notStarted) == .welcome)
        #expect(FirstJourneyTransition.advance(.welcome) == .library)
        #expect(FirstJourneyTransition.advance(.library) == .reading)
        #expect(FirstJourneyTransition.advance(.reading) == .reveal)
        #expect(FirstJourneyTransition.advance(.reveal) == .done)
    }

    @Test("Leaving the reader before counting returns to the Library spotlight")
    func readerClosedBeforeCountingReturnsToLibrary() {
        #expect(FirstJourneyTransition.readerClosedBeforeCounting(.reading) == .library)
        #expect(FirstJourneyTransition.readerClosedBeforeCounting(.library) == .library)
    }
}
