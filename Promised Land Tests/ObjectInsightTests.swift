import Testing
import Foundation
import SwiftData
@testable import Promised_Land

@MainActor
struct ObjectInsightTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    /// Sample data in an in-memory store, the same way the app stores it. The container is
    /// kept for the whole test so its records stay alive.
    let container: ModelContainer
    let reads: [ChapterRead]
    let quizzes: [QuizPass]
    let verses: [VerseMemorised]
    let journal: [JournalEntry]

    init() throws {
        container = try ModelContainer(for: Schema(AppSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
            c.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
        }
        [ChapterRead(bookID: "john", chapterNumber: 15, date: date(2025, 12, 31)),
         ChapterRead(bookID: "john", chapterNumber: 15, date: date(2026, 3, 1)),
         ChapterRead(bookID: "john", chapterNumber: 15, date: date(2026, 6, 1)),
         ChapterRead(bookID: "john", chapterNumber: 1, date: date(2026, 2, 2)),
         ChapterRead(bookID: "ruth", chapterNumber: 1, date: date(2026, 2, 3))].forEach(context.insert)
        [QuizPass(bookID: "john", score: 1, passed: false, date: date(2026, 1, 5)),
         QuizPass(bookID: "john", score: 3, passed: true, date: date(2026, 2, 1)),
         QuizPass(bookID: "ruth", score: 2, passed: true, date: date(2026, 4, 1))].forEach(context.insert)
        context.insert(VerseMemorised(bookID: "john", reference: "John 3:16", date: date(2026, 2, 10)))
        [JournalEntry(bookID: "john", chapter: 15, prompt: nil, text: "Abide.\nSecond line", date: date(2026, 3, 1)),
         JournalEntry(bookID: "john", chapter: 15, prompt: nil, text: "The vine", date: date(2026, 6, 2)),
         JournalEntry(bookID: "john", chapter: 3, prompt: nil, text: "Nicodemus", date: date(2026, 5, 1)),
         JournalEntry(bookID: "ruth", chapter: 1, prompt: nil, text: "Loyalty", date: date(2026, 2, 3))].forEach(context.insert)
        try context.save()
        reads = try context.fetch(FetchDescriptor<ChapterRead>())
        quizzes = try context.fetch(FetchDescriptor<QuizPass>())
        verses = try context.fetch(FetchDescriptor<VerseMemorised>())
        journal = try context.fetch(FetchDescriptor<JournalEntry>())
    }

    func subject(chapters: [Int]) -> InsightSubject {
        InsightSubject(id: "t", title: "Test", region: "Galilee", description: "", bookID: "john",
                       chapters: chapters)
    }

    @Test func chapterObjectCountsAndDates() {
        let insight = ObjectInsight.make(subject(chapters: [15]), reads: reads, quizzes: quizzes, verses: verses,
                                         journal: journal, now: date(2026, 7, 1), calendar: calendar)
        #expect(insight.totalReads == 3)
        #expect(insight.readsThisYear == 2)
        #expect(insight.firstRead == date(2025, 12, 31))
        #expect(insight.lastRead == date(2026, 6, 1))
        #expect(insight.depth == 3)
    }

    @Test func latestQuizResultIsShown() {
        let insight = ObjectInsight.make(subject(chapters: [15]), reads: reads, quizzes: quizzes, verses: verses,
                                         journal: journal, now: date(2026, 7, 1), calendar: calendar)
        #expect(insight.latestQuiz == ObjectInsight.QuizResult(score: 3, total: 3, date: date(2026, 2, 1), passed: true))
        #expect(insight.memorised?.reference == "John 3:16")
        #expect(insight.memorised?.date == date(2026, 2, 10))
    }

    @Test func failedAttemptAfterAPassIsTheLatest() {
        let failed = QuizPass(bookID: "john", score: 0, passed: false, date: date(2026, 6, 20))
        container.mainContext.insert(failed)
        let insight = ObjectInsight.make(subject(chapters: [15]), reads: reads, quizzes: quizzes + [failed],
                                         verses: verses, journal: journal, now: date(2026, 7, 1), calendar: calendar)
        #expect(insight.latestQuiz?.passed == false)
        #expect(insight.latestQuiz?.score == 0)
    }

    @Test func journalForTheChapterNewestFirst() {
        let insight = ObjectInsight.make(subject(chapters: [15]), reads: reads, quizzes: quizzes, verses: verses,
                                         journal: journal, now: date(2026, 7, 1), calendar: calendar)
        #expect(insight.journal.map(\.text) == ["The vine", "Abide.\nSecond line"])
    }

    @Test func bookLevelObjectUsesTheWholeBook() {
        let insight = ObjectInsight.make(subject(chapters: []), reads: reads, quizzes: quizzes, verses: verses,
                                         journal: journal, now: date(2026, 7, 1), calendar: calendar)
        #expect(insight.totalReads == 4)
        #expect(insight.chaptersRead == 2)
        #expect(insight.depth == nil)
        #expect(insight.journal.map(\.text) == ["The vine", "Nicodemus", "Abide.\nSecond line"])
    }

    @Test func nothingReadMeansNoData() {
        let other = InsightSubject(id: "x", title: "X", region: "", description: "", bookID: "daniel",
                                   chapters: [6])
        let insight = ObjectInsight.make(other, reads: reads, quizzes: quizzes, verses: verses, journal: journal,
                                         now: date(2026, 7, 1), calendar: calendar)
        #expect(insight.totalReads == 0)
        #expect(insight.depth == nil)
        #expect(insight.latestQuiz == nil)
        #expect(insight.memorised == nil)
        #expect(insight.journal.isEmpty)
    }
}
