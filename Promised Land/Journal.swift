import Foundation
import SwiftData

/// A journal page: a reflection after reading, or a free entry. Stored only on this device.
@Model
final class JournalEntry {
    var id: UUID
    var created: Date
    var updated: Date
    /// The Bible book (and chapter) it's about, if any. Free entries have neither.
    var bookID: String?
    var chapter: Int?
    /// The reflection prompt it answers, if any.
    var prompt: String?
    var text: String

    init(bookID: String? = nil, chapter: Int? = nil, prompt: String? = nil, text: String, date: Date = .now) {
        self.id = UUID()
        self.created = date
        self.updated = date
        self.bookID = bookID
        self.chapter = chapter
        self.prompt = prompt
        self.text = text
    }

    var reference: String? {
        guard let bookID, let book = BibleCatalog.book(id: bookID) else { return nil }
        return chapter.map { "\(book.name) \($0)" } ?? book.name
    }
}

/// Every SwiftData model the app stores, registered once for the app and previews.
enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        ChapterRead.self, QuizPass.self, VerseMemorised.self, JournalEntry.self, AvatarProfile.self, CrownCasting.self,
    ]
}
