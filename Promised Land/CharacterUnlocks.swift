import Foundation

// Characters are unlocked by completing their journeys (CharacterJourneys.swift). This file
// keeps the shared pieces: rarity, and which looks the avatar creator can start from.

nonisolated enum Rarity: String, Sendable, CaseIterable {
    case common, rare, legendary

    var title: String { rawValue.capitalized }
}

/// Which character looks can be used in the avatar creator ("Start from a character").
enum PresetAccess {
    static var ids: [String] { CharacterJourneys.all.map(\.characterId) }

    static func name(_ id: String) -> String {
        CharacterJourneys.all.first { $0.characterId == id }?.name ?? id.capitalized
    }

    /// A character's look is yours once their journey is complete.
    static func unlocked(_ progress: GameProgress) -> Set<String> {
        Set(progress.unlockedJourneys.map(\.characterId))
    }
}
