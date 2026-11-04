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

/// A read-only snapshot of the player's progress, built from the stored records.
struct GameProgress {
    private let read: Set<String>
    private let quizzes: Set<String>
    private let memorised: Set<String>

    init(reads: [ChapterRead], quizzes: [QuizPass], memorised: [VerseMemorised]) {
        self.read = Set(reads.map { Self.key($0.bookID, $0.chapterNumber) })
        self.quizzes = Set(quizzes.map(\.bookID))
        self.memorised = Set(memorised.map(\.bookID))
    }

    private static func key(_ bookID: String, _ chapter: Int) -> String { "\(bookID)#\(chapter)" }

    func isRead(_ bookID: String, chapter: Int) -> Bool {
        read.contains(Self.key(bookID, chapter))
    }

    func chaptersRead(in book: Book) -> Int {
        book.chapters.filter { isRead(book.id, chapter: $0.number) }.count
    }

    func isComplete(_ book: Book) -> Bool {
        chaptersRead(in: book) == book.chapters.count
    }

    func level(of place: Place) -> GrowthLevel {
        guard let book = place.book, isComplete(book) else { return .locked }
        guard quizzes.contains(place.bookID) else { return .unlocked }
        guard memorised.contains(place.bookID) else { return .growing }
        return .flourishing
    }

    var totalChaptersRead: Int {
        BibleData.books.reduce(0) { $0 + chaptersRead(in: $1) }
    }

    var totalChapters: Int {
        BibleData.books.reduce(0) { $0 + $1.chapters.count }
    }
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
