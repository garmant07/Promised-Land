import Foundation
import SwiftData

/// A record of casting crowns before the throne. Each cast starts a new cycle;
/// all world progress is kept.
@Model
final class CrownCasting {
    var date: Date
    /// The cycle that ended with this cast (0 for the first).
    var cycle: Int
    /// Crowns laid down per book.
    var perBook: [String: Int]

    init(cycle: Int, perBook: [String: Int], date: Date = .now) {
        self.date = date
        self.cycle = cycle
        self.perBook = perBook
    }
}

/// The verse behind casting crowns. Gated like all biblical content.
struct CrownVerse: ReviewableContent {
    let text: String
    let reference: String
    let source: String
    var reviewed = false
}

enum CrownData {
    // ASV wording of Revelation 4:10. Unreviewed.
    static let castingVerse = CrownVerse(
        text: "The four and twenty elders shall fall down before him that sitteth on the throne, and shall worship him that liveth for ever and ever, and shall cast their crowns before the throne.",
        reference: "Revelation 4:10", source: "Revelation 4 (ASV)")
}

extension GameProgress {
    /// The fewest times any chapter of a book has been read.
    func minimumReads(_ bookID: String) -> Int {
        guard let book = BibleCatalog.book(id: bookID) else { return 0 }
        return book.chapterNumbers.map { readCount(bookID, chapter: $0) }.min() ?? 0
    }

    /// One crown for each full reread of a book (every chapter read again).
    func crownsEarned(_ bookID: String) -> Int { max(0, minimumReads(bookID) - 1) }
    func crownsAvailable(_ bookID: String) -> Int { max(0, crownsEarned(bookID) - crownsCast(bookID)) }

    var totalCrownsEarned: Int { BibleCatalog.books.reduce(0) { $0 + crownsEarned($1.id) } }
    var totalCrownsAvailable: Int { BibleCatalog.books.reduce(0) { $0 + crownsAvailable($1.id) } }

    /// Every chapter read at least (cycle + 1) times.
    var bibleCompleteThisCycle: Bool {
        BibleCatalog.books.allSatisfy { minimumReads($0.id) >= cycle + 1 }
    }
    /// The throne room appears once the whole Bible has been read.
    var hasCompletedBible: Bool { cycle > 0 || bibleCompleteThisCycle }
}
