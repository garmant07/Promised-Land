#if DEBUG
import Foundation
import SwiftData

// TEMPORARY (DEBUG only): see NOTES.md, "Remove before release". Delete this folder to remove it.

/// A whole read Bible, in a separate in-memory store that is never the real one.
enum FullBiblePreviewData {
    /// Every chapter of all 66 books, read in canon order, one book a day, from a fixed date.
    static let reads: [(book: String, chapter: Int, date: Date)] = {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var out: [(book: String, chapter: Int, date: Date)] = []
        for (i, book) in BibleCatalog.books.enumerated() {
            for chapter in book.chapterNumbers {
                out.append((book.id, chapter, start.addingTimeInterval(Double(i) * 86_400 + Double(chapter) * 60)))
            }
        }
        return out
    }()

    /// An in-memory container holding a ReadingEvent (`ChapterRead`) for every chapter.
    /// It's created fresh each time and dropped when the preview closes.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let container = try ModelContainer(for: schema,
                                           configurations: ModelConfiguration("FullBiblePreview", schema: schema, isStoredInMemoryOnly: true))
        let context = container.mainContext
        for r in reads { context.insert(ChapterRead(bookID: r.book, chapterNumber: r.chapter, date: r.date)) }
        try context.save()
        return container
    }

    /// The reads of the first `books` books (for "Replay the build").
    static func reads(firstBooks books: Int) -> [(book: String, chapter: Int, date: Date)] {
        let ids = Set(BibleCatalog.books.prefix(books).map(\.id))
        return reads.filter { ids.contains($0.book) }
    }
}
#endif
