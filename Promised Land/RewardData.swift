import Foundation

// What learning adds beside a book's building. These are game rules, not content.

nonisolated enum RewardKind: String, Sendable {
    /// Passing a book's quiz raises a banner.
    case banner
    /// Memorising a book's verse lights a lantern, or grows a fruit tree (alternating by book).
    case lantern, fruitTree
}

enum RewardData {
    /// Quiz passed.
    static let quiz: RewardKind = .banner

    /// Verse memorised: half the books get a lantern, half a fruit tree, so plots differ.
    static func verse(for bookID: String) -> RewardKind {
        (BibleCatalog.books.firstIndex { $0.id == bookID } ?? 0) % 2 == 0 ? .lantern : .fruitTree
    }

    /// Plot slots the rewards use (the two nearest the front of the building); chapters follow.
    static let quizSlot = 0, verseSlot = 1, firstChapterSlot = 2
}

// MARK: - Extras for edit mode

extension RewardData {
    /// Small decorations earned by keeping a reading streak (and reading on many days). They're
    /// placed, moved and removed freely in edit mode's Extras tray. Game rules, not content.
    static func extrasEarned(longestStreak: Int, readingDays: Int) -> [ExtraKind: Int] {
        [
            .path: min(40, readingDays / 2),
            .tree: min(20, readingDays / 5),
            .fence: longestStreak >= 3 ? min(20, 2 + (longestStreak - 3) / 2) : 0,
            .bench: min(10, longestStreak / 5),
            .lamp: min(10, longestStreak / 7),
        ]
    }

    /// What earns the next of each extra (shown in the tray when none are left).
    static func extraHint(_ kind: ExtraKind) -> String {
        switch kind {
        case .path: "A path tile for every 2 days you read"
        case .tree: "A tree for every 5 days you read"
        case .fence: "Fences from a 3-day streak"
        case .bench: "A bench for every 5 days in a row"
        case .lamp: "A lamp for every 7 days in a row"
        }
    }
}
