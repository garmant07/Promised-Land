import Foundation

/// What a tapped object on your island is.
struct InsightSubject: Identifiable, Equatable {
    let id: String
    let title: String
    let region: String
    let description: String
    let bookID: String
    /// The chapters behind it. Empty for book-level objects (a fruit tree, a lantern, a finished book).
    let chapters: [Int]

    var isBookLevel: Bool { chapters.isEmpty }
    var book: Book? { BibleCatalog.book(id: bookID) }

    /// "John 15", "Genesis 6–9", or the book name for book-level objects.
    var chapterLabel: String {
        let name = book?.name ?? bookID
        guard let first = chapters.min(), let last = chapters.max() else { return name }
        return first == last ? "\(name) \(first)" : "\(name) \(first)–\(last)"
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    // MARK: Island items

    static func island(_ item: Island.Item) -> InsightSubject? {
        guard let bookID = item.source.bookID, let book = BibleCatalog.book(id: bookID) else { return nil }
        let region = WorldData.landmark(bookID: bookID)?.region?.name ?? ""
        let id = "island-\(bookID)-\(item.seed)-\(item.gx)-\(item.gy)"
        switch item.source {
        case .place, .flourish:
            return InsightSubject(id: id, title: PlaceData.spec(for: bookID).name, region: region,
                                  description: placeText(bookID: bookID, read: item.progress, total: item.total, richness: item.level),
                                  bookID: bookID, chapters: [])
        case .forest(_, let chapter):
            let entry = ForestData.entry(bookID, chapter)
            let tree = entry.flatMap { ContentGate.isVisible($0) ? "\u{201C}\($0.tree)\u{201D} (\($0.reference)). " : nil } ?? ""
            return InsightSubject(id: id, title: "Forest tree", region: region,
                                  description: "\(tree)Grew when you read \(book.name) \(chapter). Every chapter with trees in it adds to the forest.",
                                  bookID: bookID, chapters: [chapter])
        case .quiz:
            return InsightSubject(id: id, title: "Banner", region: region,
                                  description: "Raised when you passed the \(book.name) quiz.",
                                  bookID: bookID, chapters: [])
        case .verse:
            return InsightSubject(id: id, title: name(of: item.kind), region: region,
                                  description: item.kind == .reward(.lantern)
                                    ? "Lit when you memorised a verse from \(book.name)."
                                    : "Grew when you memorised a verse from \(book.name).",
                                  bookID: bookID, chapters: [])
        case .feature, .extra:
            return nil
        }
    }

    /// What a Place's card says: how far it has grown, and how rich rereads have made it.
    static func placeText(bookID: String, read: Int, total: Int, richness: Int) -> String {
        let name = PlaceData.spec(for: bookID).name
        let book = BibleCatalog.book(id: bookID)?.name ?? bookID
        if read == 0 { return "Read a chapter of \(book) to found \(name)." }
        if read < total {
            let left = total - read
            return "\(name) is growing: \(read) of \(total) chapters read. Every chapter adds to it; \(left) more to complete it."
        }
        if richness <= 1 { return "Complete: you read all of \(book). Read it again to make \(name) richer." }
        return "Complete, and read through \(richness) times: richness \(min(5, richness)) of 5."
    }

    static func name(of kind: Island.Kind) -> String {
        switch kind {
        case .piece(let k): k.rawValue.capitalized
        case .flourish: "Flowers"
        case .reward(.banner): "Banner"
        case .reward(.lantern): "Lantern"
        case .reward(.fruitTree): "Fruit tree"
        case .tree: "Forest tree"
        case .extra(let k): k.name
        case .library: "Library"
        case .throne: "Throne room"
        }
    }

}

/// Everything the Insight Card shows, worked out from the stored records. Pure, so it's testable.
struct ObjectInsight {
    struct QuizResult: Equatable {
        let score: Int
        let total: Int?
        let date: Date
        let passed: Bool
    }

    struct Memorised: Equatable {
        let reference: String
        let text: String?
        let date: Date
    }

    var totalReads = 0
    var readsThisYear = 0
    var firstRead: Date?
    var lastRead: Date?
    /// 1...5 for chapter objects (each reread adds one); nil for book-level objects.
    var depth: Int?
    /// For book-level objects: distinct chapters read of the book.
    var chaptersRead = 0
    var latestQuiz: QuizResult?
    var memorised: Memorised?
    /// Newest first.
    var journal: [JournalEntry] = []

    static func make(_ subject: InsightSubject, reads: [ChapterRead], quizzes: [QuizPass],
                     verses: [VerseMemorised], journal: [JournalEntry], now: Date = .now,
                     calendar: Calendar = .current) -> ObjectInsight {
        var insight = ObjectInsight()
        let bookReads = reads.filter { $0.bookID == subject.bookID }
        let relevant = subject.isBookLevel ? bookReads : bookReads.filter { subject.chapters.contains($0.chapterNumber) }
        let year = calendar.component(.year, from: now)

        insight.totalReads = relevant.count
        insight.readsThisYear = relevant.filter { calendar.component(.year, from: $0.date) == year }.count
        insight.firstRead = relevant.map(\.date).min()
        insight.lastRead = relevant.map(\.date).max()
        insight.chaptersRead = Set(bookReads.map(\.chapterNumber)).count
        if !subject.isBookLevel, !relevant.isEmpty {
            let distinct = Set(relevant.map(\.chapterNumber)).count
            insight.depth = min(5, 1 + relevant.count - distinct)
        }

        if let latest = quizzes.filter({ $0.bookID == subject.bookID }).max(by: { $0.date < $1.date }) {
            insight.latestQuiz = QuizResult(score: latest.score,
                                            total: LearningData.forBook(subject.bookID)?.quiz.count,
                                            date: latest.date, passed: latest.passed)
        }
        if let verse = verses.filter({ $0.bookID == subject.bookID }).max(by: { $0.date < $1.date }) {
            let text = LearningData.forBook(subject.bookID)?.memoryVerse
            insight.memorised = Memorised(reference: text?.reference ?? verse.reference, text: text?.text, date: verse.date)
        }

        insight.journal = journal
            .filter { entry in
                guard entry.bookID == subject.bookID else { return false }
                if subject.isBookLevel { return true }
                return entry.chapter.map { subject.chapters.contains($0) } ?? false
            }
            .sorted { $0.created > $1.created }
        return insight
    }
}
