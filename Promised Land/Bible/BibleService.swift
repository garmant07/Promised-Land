import SwiftUI

// Bible text. Views ask a `BibleService` for a chapter and never fetch, parse or cache anything
// themselves. `RoutedBibleService` sends built-in translations to `LocalBibleService` and the
// licensed translations to API.Bible. Reading progress and all other app data stay on the device.

/// One translation. Add a public-domain Bible by importing its files and adding one catalog entry.
nonisolated struct BibleTranslation: RawRepresentable, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    enum Source: Hashable, Sendable { case bundled(folder: String), apiBible }

    let rawValue: String

    init?(rawValue: String) {
        guard TranslationCatalog.entries.contains(where: { $0.abbreviation == rawValue }) else { return nil }
        self.rawValue = rawValue
    }

    private init(known rawValue: String) { self.rawValue = rawValue }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        guard let value = BibleTranslation(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Unknown Bible translation")
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static let asv = BibleTranslation(known: "ASV")
    static let niv = BibleTranslation(known: "NIV")
    static let nlt = BibleTranslation(known: "NLT")
    static let csb = BibleTranslation(known: "CSB")
    static var allCases: [BibleTranslation] { TranslationCatalog.entries.map { BibleTranslation(known: $0.abbreviation) } }

    var id: String { rawValue }
    var abbreviation: String { rawValue }
    var name: String { definition.name }
    var source: Source { definition.source }
    var chapterNotice: String { definition.chapterNotice }
    var isBuiltIn: Bool { if case .bundled = source { true } else { false } }

    private var definition: TranslationCatalog.Entry {
        TranslationCatalog.entries.first { $0.abbreviation == rawValue }!
    }

    /// The stored choice if it's available, otherwise the first one that is (nil: none are).
    static func choose(stored: String, available: [BibleTranslation]) -> BibleTranslation? {
        BibleTranslation(rawValue: stored).flatMap { available.contains($0) ? $0 : nil } ?? available.first
    }
}

nonisolated enum TranslationCatalog {
    struct Entry: Sendable {
        let name: String
        let abbreviation: String
        let source: BibleTranslation.Source
        let chapterNotice: String
    }

    static let entries: [Entry] = [
        Entry(name: "American Standard Version", abbreviation: "ASV", source: .bundled(folder: "ASV"),
              chapterNotice: "American Standard Version (1901). Public domain."),
        Entry(name: "New International Version", abbreviation: "NIV", source: .apiBible, chapterNotice: ""),
        Entry(name: "New Living Translation", abbreviation: "NLT", source: .apiBible, chapterNotice: ""),
        Entry(name: "Christian Standard Bible", abbreviation: "CSB", source: .apiBible, chapterNotice: ""),
    ]

    static var builtIn: [BibleTranslation] { BibleTranslation.allCases.filter(\.isBuiltIn) }
    static var apiBible: [BibleTranslation] { BibleTranslation.allCases.filter { $0.source == .apiBible } }
}

/// One chapter's text, as shown in the reader.
nonisolated struct ChapterText: Codable, Equatable, Sendable {
    let bookID: String
    let chapter: Int
    /// The translation abbreviation.
    let translation: String
    let verses: [Verse]
    /// Shown at the bottom of the chapter (from the API response for live text).
    let copyright: String
    /// When it was downloaded (cached chapters older than `ChapterCache.maxAge` are refreshed).
    let fetched: Date
    /// Where this copy came from (not stored; set when it's handed out).
    var origin: Origin = .live

    nonisolated enum Origin: String, Codable, Sendable {
        /// Just downloaded.
        case live
        /// From the cache, recent enough.
        case cache
        /// From the cache, older than 30 days: it couldn't be refreshed (offline or an error).
        case staleCache
        /// Text bundled in the app (the full ASV or the retained small sample).
        case bundled
    }

    private enum CodingKeys: String, CodingKey { case bookID, chapter, translation, verses, copyright, fetched }

    var words: Int { ReadingGate.words(verses) }
}

/// What can go wrong getting a chapter, in words a reader understands.
nonisolated enum BibleError: Error, Equatable, Sendable {
    /// No text for this chapter: no API key, and nothing bundled (the own-Bible question remains available).
    case noText
    /// No connection, and the chapter isn't cached.
    case offline
    /// API.Bible said too many requests (429).
    case rateLimited(retryAfter: Int?)
    /// The API key was missing or rejected (401).
    case badKey
    /// The translation isn't included in the API plan (403).
    case notOnPlan
    /// The chapter or Bible doesn't exist (404).
    case notFound
    /// Any other server answer.
    case server(Int)
    /// The answer couldn't be read.
    case unreadable

    var title: String {
        switch self {
        case .noText: "This chapter’s text isn’t available"
        case .offline: "Connect to the internet to load this chapter"
        case .rateLimited: "Too many requests right now"
        case .badKey: "The Bible text service isn't set up"
        case .notOnPlan: "This translation isn't available"
        case .notFound: "This chapter couldn't be found"
        case .server, .unreadable: "This chapter couldn't load"
        }
    }

    var message: String {
        switch self {
        case .noText:
            "This chapter's text isn't in the app yet."
        case .offline:
            "Once it's loaded it's kept on this device, so you can read it offline next time. Your island, journeys and marking chapters as read all keep working offline."
        case .rateLimited(let after):
            "The Bible text service has had a lot of requests. " + (after.map { "Try again in \(max(1, ($0 + 59) / 60)) minute\($0 > 60 ? "s" : "")." } ?? "Try again in a few minutes.")
        case .badKey:
            #if DEBUG
            "API.Bible rejected the API key. Check API_BIBLE_KEY in Secrets.xcconfig (see README), then rebuild."
            #else
            "Bible text can't be loaded at the moment. Please try again later."
            #endif
        case .notOnPlan:
            "Pick another translation in the reader or in Settings."
        case .notFound:
            "Try another translation, or choose “I read this in my own Bible” after reading the chapter in your Bible."
        case .server(let code):
            "The Bible text service had a problem (\(code)). Please try again."
        case .unreadable:
            "The text came back in a form the app couldn't read. Please try again."
        }
    }

    /// Worth a Retry button.
    var canRetry: Bool {
        switch self {
        case .offline, .rateLimited, .server, .unreadable: true
        default: false
        }
    }
}

/// Where Bible text comes from. Views use only this (through `\.bibleService`).
@MainActor
protocol BibleService: AnyObject, Sendable {
    /// Live text is set up (an API key is configured).
    var isLive: Bool { get }
    /// Translations that can be picked now.
    var translations: [BibleTranslation] { get }
    /// Translations looked for but not on the API plan.
    var unavailableTranslations: [BibleTranslation] { get }
    /// First run: looks up the Bible ids of the translations (no-op once known).
    func prepare() async
    /// A chapter, from a built-in resource, the cache or the network.
    func chapter(bookID: String, chapter: Int, translation: BibleTranslation?) async throws -> ChapterText
    /// A chapter already on the device, without touching the network (for word counts and questions).
    func cachedChapter(bookID: String, chapter: Int, translation: BibleTranslation?) -> ChapterText?
    /// Whether opening this chapter can show text (live text, or bundled).
    func hasText(bookID: String, chapter: Int) -> Bool
}

/// The bundled ASV sample (a few chapters of six books): the fallback when there's no key, or
/// when offline with nothing cached.
@MainActor
final class BundledBibleService: BibleService {
    static let copyright = "American Standard Version (1901), public domain. Sample verses."

    var isLive: Bool { false }
    var translations: [BibleTranslation] { [] }
    var unavailableTranslations: [BibleTranslation] { [] }
    func prepare() async {}

    func chapter(bookID: String, chapter: Int, translation: BibleTranslation?) async throws -> ChapterText {
        guard let text = cachedChapter(bookID: bookID, chapter: chapter, translation: translation) else { throw BibleError.noText }
        return text
    }

    func cachedChapter(bookID: String, chapter: Int, translation: BibleTranslation?) -> ChapterText? {
        guard let verses = SampleText.verses(book: bookID, chapter: chapter) else { return nil }
        return ChapterText(bookID: bookID, chapter: chapter, translation: "ASV", verses: verses, copyright: Self.copyright,
                           fetched: .distantPast, origin: .bundled)
    }

    func hasText(bookID: String, chapter: Int) -> Bool { SampleText.verses(book: bookID, chapter: chapter) != nil }
}

/// The app's one Bible service.
@MainActor
enum BibleServices {
    static let shared: any BibleService = RoutedBibleService.fromBundle()
}

extension EnvironmentValues {
    /// A service put in by a preview or test (nil: the app's own).
    @Entry var injectedBibleService: (any BibleService)? = nil

    /// Where views get Bible text.
    var bibleService: any BibleService {
        get { injectedBibleService ?? BibleServices.shared }
        set { injectedBibleService = newValue }
    }
}

extension StorageKeys {
    /// The chosen translation, using its abbreviation. This storage key is intentionally unchanged.
    static let bibleTranslation = "bible.translation"
}
