import Testing
import Foundation
@testable import Promised_Land

struct FirstJourneyTests {
    @Test("Names trim whitespace, stop at twenty characters, and reject empty input")
    func nameRules() {
        #expect(FirstJourneyName.normalized("  Sarah  ") == "Sarah")
        #expect(FirstJourneyName.normalized(String(repeating: "a", count: 25)).count == 20)
        #expect(FirstJourneyName.normalized("   ").isEmpty)
    }

    @Test("The first-journey tap filter accepts the Library and rejects other items")
    func libraryTapFilter() {
        #expect(FirstJourneyLibraryTap.isAllowed(.feature(.library)))
        #expect(!FirstJourneyLibraryTap.isAllowed(.feature(.throne)))
        #expect(!FirstJourneyLibraryTap.isAllowed(.place(book: "genesis", piece: 0)))
        #expect(!FirstJourneyLibraryTap.isAllowed(nil))
    }

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

    @Test("A freshly onboarded player with a chosen sex skips the avatar update")
    func freshlyOnboardedPlayerSkipsAvatarUpdate() {
        #expect(!ContentViewRouting.shouldPresentAvatarUpdate(
            hasOnboarded: true,
            sex: .female,
            finishedOnboardingThisSession: true
        ))
        #expect(ContentViewRouting.shouldPresentAvatarUpdate(
            hasOnboarded: true,
            sex: nil,
            finishedOnboardingThisSession: false
        ))
    }

    @Test("Finishing onboarding preserves the selected male and female looks")
    func finishingOnboardingPreservesSelectedAvatar() {
        for sex in [AvatarSex.male, .female] {
            let selected = OnboardingAvatarSelection.config(for: sex)
            let profile = AvatarProfile(Avatar())
            profile.apply(selected)

            #expect(!OnboardingAvatarSelection.shouldResetAfterEditorDismissal(isFinishing: true))
            #expect(profile.config == selected)
            #expect(profile.config.sex == sex)
        }
    }

    @Test("Onboarding mode defaults to Easy and saves the existing Strict setting")
    func onboardingModeSelection() {
        let defaults = UserDefaults(suiteName: "FirstJourneyTests.mode")!
        defaults.removePersistentDomain(forName: "FirstJourneyTests.mode")

        #expect(OnboardingModeChoice.defaultIsStrict == false)
        #expect(defaults.object(forKey: ReadingStrictMode.key) == nil)

        OnboardingModeChoice.save(isStrict: false, defaults: defaults)
        #expect(defaults.bool(forKey: ReadingStrictMode.key) == false)

        OnboardingModeChoice.save(isStrict: true, defaults: defaults)
        #expect(defaults.bool(forKey: ReadingStrictMode.key) == true)
    }

    @Test("Leaving the reader before counting returns to the Library spotlight")
    func readerClosedBeforeCountingReturnsToLibrary() {
        #expect(FirstJourneyTransition.readerClosedBeforeCounting(.reading) == .library)
        #expect(FirstJourneyTransition.readerClosedBeforeCounting(.library) == .library)
    }
}
