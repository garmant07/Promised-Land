import Testing
import SwiftData
import Foundation
@testable import Promised_Land

@MainActor
struct LibrarySummaryTests {
    @Test("Read summaries reuse unchanged data and refresh same-count edits, replacements and removals")
    func readInvalidation() throws {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let first = ChapterRead(bookID: "genesis", chapterNumber: 1, checked: false)
        context.insert(first)
        let cache = LibrarySummaryCache<ChapterRead, LibraryReadSummary>()
        var builds = 0
        func summary(_ reads: [ChapterRead]) -> LibraryReadSummary {
            cache.value(for: reads) { builds += 1; return LibraryReadSummary(reads: $0) }
        }
        #expect(summary([first]).volumes == 0)
        #expect(summary([first]).volumes == 0)
        #expect(builds == 1)
        first.checked = true
        #expect(summary([first]).volumes == 1)
        #expect(builds == 2)
        first.chapterNumber = 999
        #expect(summary([first]).volumes == 0)
        first.chapterNumber = 1
        first.bookID = "ruth"
        #expect(summary([first]).tally.distinct["ruth"] == 1)
        first.date = .distantPast
        #expect(summary([first]).tally.founded["ruth"] == .distantPast)
        let replacement = ChapterRead(bookID: "john", chapterNumber: 1)
        context.insert(replacement)
        #expect(summary([replacement]).tally.distinct["john"] == 1)
        #expect(summary([]).volumes == 0)
    }

    @Test("Read summaries preserve existing rules for rereads, unchecked reads, invalid chapters and tied dates")
    func readingRules() {
        let date = Date(timeIntervalSince1970: 1000)
        let reads = [
            ChapterRead(bookID: "genesis", chapterNumber: 1, date: date),
            ChapterRead(bookID: "genesis", chapterNumber: 1, date: date, checked: false),
            ChapterRead(bookID: "ruth", chapterNumber: 1, date: date),
            ChapterRead(bookID: "ruth", chapterNumber: 1, date: date.addingTimeInterval(1)),
            ChapterRead(bookID: "ruth", chapterNumber: 2, date: date, checked: false),
            ChapterRead(bookID: "ruth", chapterNumber: 999, date: date),
            ChapterRead(bookID: "unknown", chapterNumber: 1, date: date)
        ]
        let expected = ReadTally(chapters: reads.map { ($0.bookID, $0.chapterNumber, $0.date) },
                                 unchecked: reads.filter { !$0.checked }.map { ($0.bookID, $0.chapterNumber) })
        let actual = LibraryReadSummary(reads: reads).tally
        #expect(actual.distinct == expected.distinct)
        #expect(actual.total == expected.total)
        #expect(actual.booksInOrder == expected.booksInOrder)
        #expect(actual.founded == expected.founded)
        #expect(actual.completed == expected.completed)
        #expect(actual.forestChapters.map { "\($0.bookID)#\($0.chapter)" }
                == expected.forestChapters.map { "\($0.bookID)#\($0.chapter)" })
    }

    @Test("Journal groups preserve order and refresh membership without rebuilding for text edits")
    func journalInvalidation() throws {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let a = JournalEntry(bookID: "ruth", text: "First")
        let b = JournalEntry(bookID: "genesis", text: "Second")
        let c = JournalEntry(bookID: "ruth", text: "Third")
        let free = JournalEntry(text: "Free")
        for entry in [a, b, c, free] { context.insert(entry) }
        let cache = LibrarySummaryCache<JournalEntry, LibraryJournalSummary>()
        var builds = 0
        func summary(_ entries: [JournalEntry]) -> LibraryJournalSummary {
            cache.value(for: entries) { builds += 1; return LibraryJournalSummary(entries: $0) }
        }
        let entries = [a, b, c, free]
        #expect(summary(entries).volumes.map(\.id) == ["genesis", "ruth", "free"])
        #expect(summary(entries).entries(for: "ruth").map(\.id) == [a.id, c.id])
        #expect(builds == 1)
        a.text = "Edited"
        #expect(summary(entries).entries(for: "ruth").first?.text == "Edited")
        #expect(builds == 1)
        a.bookID = nil
        #expect(summary(entries).free.map(\.id) == [a.id, free.id])
        #expect(builds == 2)
        #expect(summary([c, b, a, free]).free.map(\.id) == [a.id, free.id])
        #expect(builds == 3)
        #expect(summary([b, a, free]).entries(for: "ruth").isEmpty)
        #expect(summary([]).volumes.isEmpty)
    }

    @Test("Timing does no collection while disabled and still returns the operation's result")
    func timingSwitch() {
        #if DEBUG
        let enabled = PerfProbe.enabled
        let totals = PerfProbe.totals
        defer { PerfProbe.enabled = enabled; PerfProbe.totals = totals }
        PerfProbe.enabled = false
        PerfProbe.totals = [:]
        #expect(PerfProbe.measure("summary-check") { 42 } == 42)
        #expect(PerfProbe.totals.isEmpty)
        PerfProbe.enabled = true
        #expect(PerfProbe.measure("summary-check") { 43 } == 43)
        #expect(PerfProbe.totals["summary-check"]?.calls == 1)
        PerfProbe.enabled = false
        _ = PerfProbe.measure("summary-check") { 44 }
        #expect(PerfProbe.totals["summary-check"]?.calls == 1)
        #endif
    }
}
