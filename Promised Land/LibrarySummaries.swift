import SwiftUI
import SwiftData
import Observation

/// Retains a derived value until query membership/order or a field used to build it changes.
/// The queries and their models belong to the main context, so their changes arrive on MainActor.
@MainActor @Observable
final class LibrarySummaryCache<Record: PersistentModel, Value> {
    @ObservationIgnored private var records: [Record] = []
    @ObservationIgnored private var cached: Value?
    @ObservationIgnored private var generation = 0
    private var revision = 0

    func value(for records: [Record], build: @MainActor ([Record]) -> Value) -> Value {
        _ = revision
        if self.records == records, let cached { return cached }
        self.records = records
        generation += 1
        let generation = generation
        let value = withObservationTracking {
            build(records)
        } onChange: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == generation else { return }
                self.cached = nil
                self.revision += 1
            }
        }
        cached = value
        return value
    }
}

/// Copies SwiftData fields in one pass; the existing tally sorts once and applies its unchanged rules.
struct LibraryReadSummary {
    let tally: ReadTally
    let volumes: Int

    init(reads: [ChapterRead]) {
        var chapters: [(book: String, chapter: Int, date: Date)] = []
        var unchecked: [(book: String, chapter: Int)] = []
        chapters.reserveCapacity(reads.count)
        for read in reads {
            let book = read.bookID
            let chapter = read.chapterNumber
            chapters.append((book, chapter, read.date))
            if !read.checked { unchecked.append((book, chapter)) }
        }
        tally = ReadTally(chapters: chapters, unchecked: unchecked)
        volumes = tally.distinct.values.reduce(0, +)
    }
}

/// Groups once, preserving the query's order within every book and the free-entry volume.
struct LibraryJournalSummary {
    let byBook: [String: [JournalEntry]]
    let free: [JournalEntry]
    let volumes: [JournalVolume]

    init(entries: [JournalEntry]) {
        var byBook: [String: [JournalEntry]] = [:]
        var free: [JournalEntry] = []
        for entry in entries {
            if let book = entry.bookID { byBook[book, default: []].append(entry) }
            else { free.append(entry) }
        }
        self.byBook = byBook
        self.free = free
        var volumes = BibleCatalog.books.compactMap { book -> JournalVolume? in
            guard let entries = byBook[book.id] else { return nil }
            return JournalVolume(id: book.id, title: book.name, count: entries.count)
        }
        if !free.isEmpty { volumes.append(JournalVolume(id: "free", title: "My notes", count: free.count)) }
        self.volumes = volumes
    }

    func entries(for bookID: String?) -> [JournalEntry] {
        if let bookID { return byBook[bookID] ?? [] }
        return free
    }
}
