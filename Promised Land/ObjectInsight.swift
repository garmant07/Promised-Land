import Foundation

/// What a tapped object is: either something on your island, or a story object on the world map.
struct InsightSubject: Identifiable, Equatable {
    let id: String
    let title: String
    let region: String
    let description: String
    let bookID: String
    /// The chapters behind it. Empty for book-level objects (a fruit tree, a lantern, a finished book).
    let chapters: [Int]
    /// The reviewable content behind it, if any (world-map story objects).
    let draftReference: ChapterLandmark?

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
        case .chapter(_, let chapter):
            return InsightSubject(id: id, title: name(of: item.kind), region: region,
                                  description: "Grew when you read \(book.name) \(chapter).",
                                  bookID: bookID, chapters: [chapter], draftReference: nil)
        case .quiz:
            return InsightSubject(id: id, title: "Fruit tree", region: region,
                                  description: "Grew when you passed the \(book.name) quiz.",
                                  bookID: bookID, chapters: [], draftReference: nil)
        case .verse:
            return InsightSubject(id: id, title: "Lantern", region: region,
                                  description: "Lit when you memorised a verse from \(book.name).",
                                  bookID: bookID, chapters: [], draftReference: nil)
        case .finished:
            let name = WorldData.landmark(bookID: bookID)?.name ?? book.name
            return InsightSubject(id: id, title: name, region: region,
                                  description: "Built when you finished reading \(book.name).",
                                  bookID: bookID, chapters: [], draftReference: nil)
        case .feature:
            return nil
        }
    }

    static func story(_ entry: ChapterLandmark) -> InsightSubject {
        InsightSubject(id: "story-\(entry.id)", title: entry.name,
                       region: WorldData.landmark(bookID: entry.bookID)?.region?.name ?? "",
                       description: entry.summary, bookID: entry.bookID,
                       chapters: Array(entry.chapters), draftReference: entry)
    }

    static func name(of kind: Island.Kind) -> String {
        switch kind {
        case .tuft: "Grass tuft"
        case .flower: "Flower"
        case .flowers: "Flowers"
        case .bush: "Bush"
        case .rock: "Stone"
        case .olive: "Olive tree"
        case .cypress: "Cypress"
        case .palm: "Palm"
        case .sheep: "Sheep"
        case .tent: "Tent"
        case .well: "Well"
        case .house: "House"
        case .fruitTree: "Fruit tree"
        case .lantern: "Lantern"
        case .landmark: "Landmark"
        case .library: "Library"
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
