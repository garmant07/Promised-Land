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

    init(bookID: String, score: Int, date: Date = .now) {
        self.bookID = bookID
        self.score = score
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

// MARK: - Derived progress

/// How far a landmark's building has got, from the share of its book's chapters read.
enum BuildStage: Int, Comparable, CaseIterable {
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
enum GrowthLevel: Int, Comparable, CaseIterable {
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
struct GameProgress {
    private let readByBook: [String: Set<Int>]
    private let latestByBook: [String: Date]
    private let quizzes: Set<String>
    private let memorised: Set<String>
    private let readDates: [Date]

    init(reads: [ChapterRead], quizzes: [QuizPass], memorised: [VerseMemorised]) {
        var byBook: [String: Set<Int>] = [:]
        var latest: [String: Date] = [:]
        for read in reads {
            byBook[read.bookID, default: []].insert(read.chapterNumber)
            latest[read.bookID] = max(latest[read.bookID] ?? .distantPast, read.date)
        }
        self.readByBook = byBook
        self.latestByBook = latest
        self.quizzes = Set(quizzes.map(\.bookID))
        self.memorised = Set(memorised.map(\.bookID))
        self.readDates = reads.map(\.date)
    }

    static let empty = GameProgress(reads: [], quizzes: [], memorised: [])

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
        if read == 0 { return .plot }
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
        WorldData.landmarks.contains { $0.regionID == regionID && chaptersRead($0.bookID) > 0 }
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

    init() {}

    var wrappedValue: GameProgress {
        GameProgress(reads: reads, quizzes: quizzes, memorised: memorised)
    }
}

// MARK: - Writing helpers

extension ModelContext {
    func markChapter(_ bookID: String, _ chapter: Int, read isRead: Bool) {
        let existing = (try? fetch(FetchDescriptor<ChapterRead>(
            predicate: #Predicate { $0.bookID == bookID && $0.chapterNumber == chapter }
        ))) ?? []
        if isRead {
            if existing.isEmpty { insert(ChapterRead(bookID: bookID, chapterNumber: chapter)) }
        } else {
            existing.forEach(delete)
        }
        try? save()
    }

    func resetAllProgress() {
        try? delete(model: ChapterRead.self)
        try? delete(model: QuizPass.self)
        try? delete(model: VerseMemorised.self)
        try? save()
    }

    func recordQuizPass(_ bookID: String, score: Int) {
        let existing = (try? fetch(FetchDescriptor<QuizPass>(
            predicate: #Predicate { $0.bookID == bookID }
        ))) ?? []
        if existing.isEmpty { insert(QuizPass(bookID: bookID, score: score)) }
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
