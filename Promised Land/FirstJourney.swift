import Foundation

enum FirstJourneyName {
    static let maximumLength = 20

    static func normalized(_ value: String) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumLength))
    }
}

enum FirstJourneyLibraryTap {
    static func isAllowed(_ source: Island.Source?) -> Bool {
        guard let source else { return false }
        guard case .feature(.library) = source else { return false }
        return true
    }
}

enum FirstJourneyStep: String, CaseIterable, Sendable {
    case notStarted
    case welcome
    case library
    case reading
    case reveal
    case done
}

enum FirstJourneyTransition {
    static func advance(_ step: FirstJourneyStep) -> FirstJourneyStep {
        switch step {
        case .notStarted: .welcome
        case .welcome: .library
        case .library: .reading
        case .reading: .reveal
        case .reveal: .done
        case .done: .done
        }
    }

    static func readerClosedBeforeCounting(_ step: FirstJourneyStep) -> FirstJourneyStep {
        step == .reading ? .library : step
    }
}

enum FirstJourneyStore {
    static let version = 1
    static let stepKey = "firstJourney.step"
    static let versionKey = "firstJourney.version"

    static var step: FirstJourneyStep {
        let raw = UserDefaults.standard.string(forKey: stepKey) ?? FirstJourneyStep.notStarted.rawValue
        return FirstJourneyStep(rawValue: raw) ?? .notStarted
    }

    static func bootstrap(hasOnboarded: Bool, defaults: UserDefaults = .standard) -> FirstJourneyStep {
        if defaults.integer(forKey: versionKey) != version {
            defaults.set(version, forKey: versionKey)
            defaults.set(FirstJourneyStep.notStarted.rawValue, forKey: stepKey)
        }

        let current = FirstJourneyStep(rawValue: defaults.string(forKey: stepKey) ?? "") ?? .notStarted
        if hasOnboarded, current != .done {
            set(.done, defaults: defaults)
        }

        return FirstJourneyStep(rawValue: defaults.string(forKey: stepKey) ?? "") ?? .notStarted
    }

    static func finishOnboarding(defaults: UserDefaults = .standard) {
        defaults.set(version, forKey: versionKey)
        set(.welcome, defaults: defaults)
    }

    static func advance(defaults: UserDefaults = .standard) {
        set(FirstJourneyTransition.advance(step), defaults: defaults)
    }

    static func returnToLibrary(defaults: UserDefaults = .standard) {
        set(FirstJourneyTransition.readerClosedBeforeCounting(step), defaults: defaults)
    }

    #if DEBUG
    static func replay(defaults: UserDefaults = .standard) {
        defaults.set(version, forKey: versionKey)
        set(.welcome, defaults: defaults)
    }
    #endif

    private static func set(_ step: FirstJourneyStep, defaults: UserDefaults) {
        defaults.set(version, forKey: versionKey)
        defaults.set(step.rawValue, forKey: stepKey)
    }
}
