import Foundation
import SwiftData
import SwiftUI

// MARK: - Stored records

@Model
final class ChapterRead {
    var bookID: String
    var chapterNumber: Int
    var date: Date

    init(bookID: String, chapterNumber: Int, date: Date = .now) {
        self.bookID = bookID
        self.chapterNumber = chapterNumber
        self.date = date
    }
}

@Model
final class QuizPass {
    var bookID: String
    var score: Int
    var date: Date
    /// Every attempt is recorded; only passed ones count. (Records from before this field
    /// existed were all passes, so the default is true.)
    var passed: Bool = true

    init(bookID: String, score: Int, passed: Bool = true, date: Date = .now) {
        self.bookID = bookID
        self.score = score
        self.passed = passed
        self.date = date
    }
}

@Model
final class VerseMemorised {
    var bookID: String
    var reference: String
    var date: Date

    init(bookID: String, reference: String, date: Date = .now) {
        self.bookID = bookID
        self.reference = reference
        self.date = date
    }
}

/// A book you've started: opening any of its chapters lays its foundations.
@Model
final class BookStarted {
    var bookID: String
    var date: Date

    init(bookID: String, date: Date = .now) {
        self.bookID = bookID
        self.date = date
    }
}

// MARK: - Derived progress

/// How far a landmark's building has got, from the share of its book's chapters read.
nonisolated enum BuildStage: Int, Comparable, CaseIterable, Sendable {
    case plot = 0        // nothing read: dashed outline under fog
    case foundations     // at least one chapter
    case rising          // at least half: scaffolding
    case complete        // every chapter

    static func < (lhs: BuildStage, rhs: BuildStage) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .plot: "Not started"
        case .foundations: "Foundations laid"
        case .rising: "Rising"
        case .complete: "Complete"
        }
    }
}

/// Extra flourish earned through quizzes and memorising.
nonisolated enum GrowthLevel: Int, Comparable, CaseIterable, Sendable {
    case base = 1        // just reading
    case growing = 2     // quiz passed: trees and decorations
    case flourishing = 3 // verse memorised: flag, glow, people

    static func < (lhs: GrowthLevel, rhs: GrowthLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .base: "Level 1"
        case .growing: "Growing"
        case .flourishing: "Flourishing"
        }
    }
}

/// A read-only snapshot of the player's progress, built from the stored records.
struct GameProgress: Equatable {
    static func == (lhs: GameProgress, rhs: GameProgress) -> Bool {
        lhs.readByBook == rhs.readByBook && lhs.countByChapter == rhs.countByChapter &&
            lhs.lastByChapter == rhs.lastByChapter && lhs.quizzes == rhs.quizzes && lhs.memorised == rhs.memorised &&
            lhs.castByBook == rhs.castByBook && lhs.cycle == rhs.cycle && lhs.started == rhs.started
    }

    private let readByBook: [String: Set<Int>]
    private let latestByBook: [String: Date]
    private let quizzes: Set<String>
    private let memorised: Set<String>
    private let readDates: [Date]
    /// Every read is kept (rereads included): counts and latest date per chapter.
    private let countByChapter: [String: Int]
    private let lastByChapter: [String: Date]
    private let thisYearByChapter: [String: Int]
    private let readsByBook: [String: Int]
    /// The most recent read of all: where the avatar heads after you finish a chapter.
    let latestRead: (bookID: String, chapter: Int, date: Date)?

    /// Crowns cast so far, per book, and which cycle of reading the whole Bible we're in.
    private let castByBook: [String: Int]
    let cycle: Int

    func crownsCast(_ bookID: String) -> Int { castByBook[bookID] ?? 0 }

    /// Books opened (foundations laid), even before any chapter is marked read.
    private let started: Set<String>

    func isStarted(_ bookID: String) -> Bool { started.contains(bookID) || chaptersRead(bookID) > 0 }

    init(reads: [ChapterRead], quizzes: [QuizPass], memorised: [VerseMemorised], castings: [CrownCasting] = [],
         started: [BookStarted] = [], now: Date = .now) {
        self.started = Set(started.map(\.bookID))
        self.castByBook = castings.reduce(into: [:]) { result, cast in
            for (book, n) in cast.perBook { result[book, default: 0] += n }
        }
        self.cycle = castings.count
        var byBook: [String: Set<Int>] = [:]
        var latest: [String: Date] = [:]
        var counts: [String: Int] = [:], last: [String: Date] = [:], thisYear: [String: Int] = [:], perBook: [String: Int] = [:]
        var newest: (bookID: String, chapter: Int, date: Date)?
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        for read in reads {
            byBook[read.bookID, default: []].insert(read.chapterNumber)
            latest[read.bookID] = max(latest[read.bookID] ?? .distantPast, read.date)
            let key = Self.key(read.bookID, read.chapterNumber)
            counts[key, default: 0] += 1
            last[key] = max(last[key] ?? .distantPast, read.date)
            if calendar.component(.year, from: read.date) == year { thisYear[key, default: 0] += 1 }
            perBook[read.bookID, default: 0] += 1
            if read.date >= (newest?.date ?? .distantPast) { newest = (read.bookID, read.chapterNumber, read.date) }
        }
        self.latestRead = newest
        self.readByBook = byBook
        self.latestByBook = latest
        self.countByChapter = counts
        self.lastByChapter = last
        self.thisYearByChapter = thisYear
        self.readsByBook = perBook
        self.quizzes = Set(quizzes.filter(\.passed).map(\.bookID))
        self.memorised = Set(memorised.map(\.bookID))
        self.readDates = reads.map(\.date)
    }

    static let empty = GameProgress(reads: [], quizzes: [], memorised: [])

    private static func key(_ bookID: String, _ chapter: Int) -> String { "\(bookID)#\(chapter)" }

    // MARK: Rereads & history

    /// How many times a chapter has been read (rereads count).
    func readCount(_ bookID: String, chapter: Int) -> Int { countByChapter[Self.key(bookID, chapter)] ?? 0 }
    func lastRead(_ bookID: String, chapter: Int) -> Date? { lastByChapter[Self.key(bookID, chapter)] }
    func readsThisYear(_ bookID: String, chapter: Int) -> Int { thisYearByChapter[Self.key(bookID, chapter)] ?? 0 }

    /// Every read this calendar year, rereads included.
    var totalReadsThisYear: Int { thisYearByChapter.values.reduce(0, +) }
    /// Distinct chapters read at least once this year.
    var chaptersReadThisYear: Int { thisYearByChapter.count }
    var totalReads: Int { countByChapter.values.reduce(0, +) }
    /// Reads beyond the first of each chapter.
    var rereads: Int { totalReads - countByChapter.count }
    var overallFraction: Double { Double(totalChaptersRead) / Double(max(1, totalChapters)) }

    /// Books ordered by how many reads they've had.
    var mostReadBooks: [(book: Book, reads: Int)] {
        readsByBook.compactMap { id, n in BibleCatalog.book(id: id).map { ($0, n) } }
            .sorted { ($0.reads, $1.book.id) > ($1.reads, $0.book.id) }
    }

    /// A story object's depth: 0 until any of its chapters is read, then 1 + rereads, up to 5.
    func depth(of object: ChapterLandmark) -> Int {
        let counts = object.chapters.map { readCount(object.bookID, chapter: $0) }
        let distinct = counts.filter { $0 > 0 }.count
        guard distinct > 0 else { return 0 }
        return min(5, 1 + counts.reduce(0, +) - distinct)
    }

    /// Reads, most recent date and this year's reads across a story object's chapters.
    func history(of object: ChapterLandmark) -> (reads: Int, last: Date?, thisYear: Int) {
        let chapters = Array(object.chapters)
        return (chapters.reduce(0) { $0 + readCount(object.bookID, chapter: $1) },
                chapters.compactMap { lastRead(object.bookID, chapter: $0) }.max(),
                chapters.reduce(0) { $0 + readsThisYear(object.bookID, chapter: $1) })
    }

    // MARK: Books

    func isRead(_ bookID: String, chapter: Int) -> Bool {
        readByBook[bookID]?.contains(chapter) ?? false
    }

    func chaptersRead(_ bookID: String) -> Int {
        guard let book = BibleCatalog.book(id: bookID), let read = readByBook[bookID] else { return 0 }
        return read.filter { book.chapterNumbers.contains($0) }.count
    }

    func fraction(_ bookID: String) -> Double {
        guard let book = BibleCatalog.book(id: bookID) else { return 0 }
        return Double(chaptersRead(bookID)) / Double(book.chapterCount)
    }

    func stage(of bookID: String) -> BuildStage {
        guard let book = BibleCatalog.book(id: bookID) else { return .plot }
        let read = chaptersRead(bookID)
        if read == 0 { return started.contains(bookID) ? .foundations : .plot }
        if read >= book.chapterCount { return .complete }
        return read * 2 >= book.chapterCount ? .rising : .foundations
    }

    func level(of bookID: String) -> GrowthLevel {
        guard quizzes.contains(bookID) else { return .base }
        return memorised.contains(bookID) ? .flourishing : .growing
    }

    func hasPassedQuiz(_ bookID: String) -> Bool { quizzes.contains(bookID) }
    func hasMemorised(_ bookID: String) -> Bool { memorised.contains(bookID) }

    // MARK: World

    func isRegionRevealed(_ regionID: String) -> Bool {
        WorldData.landmarks.contains { $0.regionID == regionID && isStarted($0.bookID) }
    }

    var activeConnections: [Connection] {
        WorldData.connections.filter { chaptersRead($0.a) > 0 && chaptersRead($0.b) > 0 }
    }

    /// The book most recently read from — the camera's "recentre" target.
    var newestBookID: String? {
        latestByBook.max { $0.value < $1.value }?.key
    }

    var completedCount: Int { WorldData.landmarks.filter { stage(of: $0.bookID) == .complete }.count }
    var startedCount: Int { WorldData.landmarks.filter { stage(of: $0.bookID) > .plot }.count }

    /// Consecutive days of reading, ending today or yesterday.
    var streak: Int { Streak.days(from: readDates) }

    var totalChaptersRead: Int { BibleCatalog.books.reduce(0) { $0 + chaptersRead($1.id) } }
    var totalChapters: Int { BibleCatalog.totalChapters }
}

/// Convenience reader for views that need the current progress.
@propertyWrapper
struct ProgressQuery: DynamicProperty {
    @Query private var reads: [ChapterRead]
    @Query private var quizzes: [QuizPass]
    @Query private var memorised: [VerseMemorised]
    @Query private var castings: [CrownCasting]
    @Query private var started: [BookStarted]

    init() {}

    var wrappedValue: GameProgress {
        GameProgress(reads: reads, quizzes: quizzes, memorised: memorised, castings: castings, started: started)
    }
}

// MARK: - Writing helpers

extension ModelContext {
    /// Records one read of a chapter. Every read is kept, so rereads count.
    func recordRead(_ bookID: String, _ chapter: Int, date: Date = .now) {
        insert(ChapterRead(bookID: bookID, chapterNumber: chapter, date: date))
        try? save()
    }

    /// Lays a book's foundations the first time any of its chapters is opened.
    func recordBookStarted(_ bookID: String, date: Date = .now) {
        let existing = (try? fetch(FetchDescriptor<BookStarted>(predicate: #Predicate { $0.bookID == bookID }))) ?? []
        guard existing.isEmpty else { return }
        insert(BookStarted(bookID: bookID, date: date))
        try? save()
    }

    /// Removes the most recent read of a chapter (an "undo").
    func undoLastRead(_ bookID: String, _ chapter: Int) {
        var descriptor = FetchDescriptor<ChapterRead>(
            predicate: #Predicate { $0.bookID == bookID && $0.chapterNumber == chapter },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let latest = try? fetch(descriptor).first { delete(latest) }
        try? save()
    }

    func resetAllProgress() {
        try? delete(model: ChapterRead.self)
        try? delete(model: QuizPass.self)
        try? delete(model: VerseMemorised.self)
        try? delete(model: CrownCasting.self)
        try? delete(model: BookStarted.self)
        try? save()
    }

    /// Records a quiz attempt (passed or not). Every attempt is kept; levels count passes.
    func recordQuizAttempt(_ bookID: String, score: Int, passed: Bool, date: Date = .now) {
        insert(QuizPass(bookID: bookID, score: score, passed: passed, date: date))
        try? save()
    }

    func recordMemorised(_ bookID: String, reference: String) {
        let existing = (try? fetch(FetchDescriptor<VerseMemorised>(
            predicate: #Predicate { $0.bookID == bookID }
        ))) ?? []
        if existing.isEmpty { insert(VerseMemorised(bookID: bookID, reference: reference)) }
        try? save()
    }
}
