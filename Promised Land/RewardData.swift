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
