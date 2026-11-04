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
            let times = item.level == 1 ? "once" : item.level == 2 ? "twice" : "\(item.level) times"
            let level = item.level >= 5 ? "Fully grown: level 5 of 5." : "Level \(item.level) of 5 (read \(times)). Reread it to grow it."
            return InsightSubject(id: id, title: name(of: item.kind), region: region,
                                  description: "Placed when you read \(book.name) \(chapter). \(level)",
                                  bookID: bookID, chapters: [chapter], draftReference: nil)
        case .story(let storyID, _):
            return ChapterLandmarks.entry(id: storyID).map { story($0) }
        case .quiz:
            return InsightSubject(id: id, title: "Banner", region: region,
                                  description: "Raised when you passed the \(book.name) quiz.",
                                  bookID: bookID, chapters: [], draftReference: nil)
        case .verse:
            return InsightSubject(id: id, title: name(of: item.kind), region: region,
                                  description: item.kind == .reward(.lantern)
                                    ? "Lit when you memorised a verse from \(book.name)."
                                    : "Grew when you memorised a verse from \(book.name).",
                                  bookID: bookID, chapters: [], draftReference: nil)
        case .book:
            let name = WorldData.landmark(bookID: bookID)?.name ?? book.name
            return InsightSubject(id: id, title: name, region: region, description: buildingText(item, book: book),
                                  bookID: bookID, chapters: [], draftReference: nil)
        case .feature:
            return nil
        }
    }

    /// What a building's card says: foundations, walls going up, built, or extra floors.
    static func buildingText(_ item: Island.Item, book: Book) -> String {
        if item.progress == 0 {
            return "Foundations laid when you opened \(book.name). Each chapter you read places something on the plot; finish all \(item.total) to raise the building."
        }
        if item.progress < item.total {
            let left = item.total - item.progress
            return "The walls are going up: \(item.progress) of \(item.total) chapters read. \(left) more to raise the building."
        }
        if item.level <= 1 {
            return "Built when you finished reading \(book.name). Read it all again to add a floor."
        }
        let floors = item.level - 1
        return "Built when you finished \(book.name), and read through \(item.level) times: \(floors) extra \(floors == 1 ? "floor" : "floors")."
    }

    static func story(_ entry: ChapterLandmark) -> InsightSubject {
        InsightSubject(id: "story-\(entry.id)", title: entry.name,
                       region: WorldData.landmark(bookID: entry.bookID)?.region?.name ?? "",
                       description: entry.summary, bookID: entry.bookID,
                       chapters: Array(entry.chapters), draftReference: entry)
    }

    static func name(of kind: Island.Kind) -> String {
        switch kind {
        case .artifact(let k):
            switch k {
            case .olive: "Olive tree"
            case .palm: "Palm"
            case .cypress: "Cypress"
            case .bush: "Bush"
            case .flowers: "Flowers"
            case .sheep: "Sheep"
            case .tent: "Tent"
            case .well: "Well"
            case .scroll: "Scroll"
            case .jar: "Clay jar"
            case .stele: "Standing stone"
            case .altar: "Altar"
            case .boat: "Boat"
            case .fishBasket: "Basket of fish"
            case .wheat: "Wheat"
            case .vine: "Vine"
            case .oilLamp: "Oil lamp"
            case .harp: "Harp"
            case .domedHouse: "House"
            }
        case .reward(.banner): "Banner"
        case .reward(.lantern): "Lantern"
        case .reward(.fruitTree): "Fruit tree"
        case .story(let id): ChapterLandmarks.entry(id: id)?.name ?? "Story"
        case .building: "Building"
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
