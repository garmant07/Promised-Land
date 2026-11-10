import SwiftUI

// Bible text. Views ask a `BibleService` for a chapter and never fetch, parse or cache anything
// themselves. The app's service is `APIBibleService` (live text from API.Bible, cached per chapter
// on the device) with the bundled ASV sample (`BundledBibleService`) as its fallback. Only Bible
// TEXT comes from the network; reading progress, the island, journeys and everything else stay
// on the device and work offline.

/// The translations the app offers from API.Bible. Their Bible ids are looked up on first run
/// (never hard-coded); one that isn't on the API plan is simply hidden.
nonisolated enum BibleTranslation: String, CaseIterable, Identifiable, Codable, Sendable {
    case niv = "NIV"
    case nlt = "NLT"
    case csb = "CSB"

    var id: String { rawValue }
    var abbreviation: String { rawValue }

    var name: String {
        switch self {
        case .niv: "New International Version"
        case .nlt: "New Living Translation"
        case .csb: "Christian Standard Bible"
        }
    }

    /// The stored choice if it's available, otherwise the first one that is (nil: none are).
    static func choose(stored: String, available: [BibleTranslation]) -> BibleTranslation? {
        BibleTranslation(rawValue: stored).flatMap { available.contains($0) ? $0 : nil } ?? available.first
    }
}

/// One chapter's text, as shown in the reader.
nonisolated struct ChapterText: Codable, Equatable, Sendable {
    let bookID: String
    let chapter: Int
    /// "NIV", "NLT", "CSB", or "ASV" for the bundled sample.
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
        /// The bundled ASV sample (no API key, or offline with nothing cached).
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
    /// Translations that can be picked now (empty: only the bundled sample).
    var translations: [BibleTranslation] { get }
    /// Translations looked for but not on the API plan.
    var unavailableTranslations: [BibleTranslation] { get }
    /// First run: looks up the Bible ids of the translations (no-op once known).
    func prepare() async
    /// A chapter, from the cache, the network or the bundled sample.
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
    static let shared: any BibleService = APIBibleService.fromBundle()
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
    /// The chosen translation ("NIV", "NLT" or "CSB").
    static let bibleTranslation = "bible.translation"
}
