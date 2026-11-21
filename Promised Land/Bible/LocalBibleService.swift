import Foundation

/// Full public-domain Bibles stored as one JSON resource per book. `NSCache` retains recently read
/// books and automatically discards them under memory pressure.
@MainActor
final class LocalBibleService: BibleService {
    static let shared = LocalBibleService()

    private let bundle: Bundle
    private let books = NSCache<NSString, LocalBookBox>()

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        books.countLimit = 3
    }

    var isLive: Bool { false }
    var translations: [BibleTranslation] { TranslationCatalog.builtIn }
    var unavailableTranslations: [BibleTranslation] { [] }
    func prepare() async {}

    func chapter(bookID: String, chapter: Int, translation: BibleTranslation?) async throws -> ChapterText {
        guard let translation = localTranslation(translation),
              let text = loadChapter(bookID: bookID, chapter: chapter, translation: translation, loadsBook: true) else {
            throw BibleError.noText
        }
        return text
    }

    func cachedChapter(bookID: String, chapter: Int, translation: BibleTranslation?) -> ChapterText? {
        guard let translation = localTranslation(translation) else { return nil }
        return loadChapter(bookID: bookID, chapter: chapter, translation: translation, loadsBook: false)
    }

    func hasText(bookID: String, chapter: Int) -> Bool {
        guard let book = BibleCatalog.book(id: bookID) else { return false }
        return book.chapterNumbers.contains(chapter) && !TranslationCatalog.builtIn.isEmpty
    }

    private func localTranslation(_ translation: BibleTranslation?) -> BibleTranslation? {
        let candidate = translation ?? TranslationCatalog.builtIn.first
        return candidate?.isBuiltIn == true ? candidate : nil
    }

    private func loadChapter(bookID: String, chapter: Int, translation: BibleTranslation, loadsBook: Bool) -> ChapterText? {
        guard case .bundled(let folder) = translation.source,
              let code = USFM.code(for: bookID),
              let book = loadsBook ? loadBook(code: code, folder: folder, translation: translation) : cachedBook(code: code, translation: translation),
              let localChapter = book.chapters[String(chapter)] else { return nil }
        return ChapterText(bookID: bookID, chapter: chapter, translation: translation.abbreviation,
                           verses: localChapter.verses.map { Verse(number: $0.n, text: $0.t) },
                           copyright: translation.chapterNotice, fetched: .distantPast, origin: .bundled)
    }

    private func loadBook(code: String, folder: String, translation: BibleTranslation) -> LocalBook? {
        let key = "\(translation.abbreviation)/\(code)" as NSString
        if let cached = books.object(forKey: key) { return cached.book }
        // Xcode flattens synchronized resources, so the translation prefix prevents collisions.
        let resourceName = "\(translation.abbreviation)_\(code)"
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let book = try? JSONDecoder().decode(LocalBook.self, from: data) else { return nil }
        books.setObject(LocalBookBox(book), forKey: key)
        return book
    }

    private func cachedBook(code: String, translation: BibleTranslation) -> LocalBook? {
        books.object(forKey: "\(translation.abbreviation)/\(code)" as NSString)?.book
    }
}

@MainActor
final class RoutedBibleService: BibleService {
    private let local: LocalBibleService
    let api: APIBibleService

    init(local: LocalBibleService, api: APIBibleService) {
        self.local = local
        self.api = api
    }

    static func fromBundle(_ bundle: Bundle = .main) -> RoutedBibleService {
        let local = LocalBibleService(bundle: bundle)
        return RoutedBibleService(local: local, api: APIBibleService.fromBundle(bundle, fallback: local))
    }

    var isLive: Bool { api.isLive }
    var translations: [BibleTranslation] { local.translations + api.translations }
    var unavailableTranslations: [BibleTranslation] { api.unavailableTranslations }
    func prepare() async { await api.prepare() }

    func chapter(bookID: String, chapter: Int, translation: BibleTranslation?) async throws -> ChapterText {
        let selected = translation ?? translations.first ?? .asv
        if selected.isBuiltIn {
            return try await local.chapter(bookID: bookID, chapter: chapter, translation: selected)
        }
        return try await api.chapter(bookID: bookID, chapter: chapter, translation: selected)
    }

    func cachedChapter(bookID: String, chapter: Int, translation: BibleTranslation?) -> ChapterText? {
        let selected = translation ?? translations.first ?? .asv
        if selected.isBuiltIn {
            return local.cachedChapter(bookID: bookID, chapter: chapter, translation: selected)
        }
        return api.cachedChapter(bookID: bookID, chapter: chapter, translation: selected)
    }

    func hasText(bookID: String, chapter: Int) -> Bool { local.hasText(bookID: bookID, chapter: chapter) || api.hasText(bookID: bookID, chapter: chapter) }
}

private final class LocalBookBox {
    let book: LocalBook
    init(_ book: LocalBook) { self.book = book }
}

private struct LocalBook: Decodable {
    let chapters: [String: LocalChapter]
}

private struct LocalChapter: Decodable {
    let title: String?
    let verses: [LocalVerse]
}

private struct LocalVerse: Decodable {
    let n: Int
    let t: String
}
