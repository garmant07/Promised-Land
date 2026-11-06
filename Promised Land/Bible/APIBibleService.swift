import Foundation
import Observation

// Live Bible text from API.Bible (docs.api.bible): https://rest.api.bible/v1, key in the
// `api-key` header. One chapter is fetched at a time, only when a reader opens it, and kept on
// the device (per translation) with the date it was fetched. A cached chapter is used as is for
// 30 days, then refreshed when online; offline, the cache is always shown. Whole Bibles are
// never downloaded.

/// Sends a request (URLSession in the app, a mock in tests).
@MainActor
protocol HTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionTransport: HTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

@MainActor @Observable
final class APIBibleService: BibleService {
    static let baseURL = URL(string: "https://rest.api.bible/v1")!

    /// The API key, or nil when none is configured (then only the bundled sample shows).
    let key: String?
    let cache: ChapterCache
    let usage: APIUsage
    @ObservationIgnored private let transport: HTTPTransport
    @ObservationIgnored private let fallback: any BibleService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var now: () -> Date = { .now }

    /// The translations' Bible ids, once looked up (saved, so this happens once).
    private(set) var directory: TranslationDirectory?
    @ObservationIgnored private var lookup: Task<BibleError?, Never>?

    static let directoryKey = "bible.directory"

    /// Nil arguments mean the app's own: URLSession, the cache folder, the shared counter and the bundled sample.
    init(key: String?, transport: HTTPTransport? = nil, cache: ChapterCache? = nil, usage: APIUsage? = nil,
         fallback: (any BibleService)? = nil, defaults: UserDefaults = .standard) {
        let key = key?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.key = (key?.isEmpty ?? true) ? nil : key
        self.transport = transport ?? URLSessionTransport()
        self.cache = cache ?? ChapterCache()
        self.usage = usage ?? .shared
        self.fallback = fallback ?? BundledBibleService()
        self.defaults = defaults
        directory = defaults.data(forKey: Self.directoryKey).flatMap { try? JSONDecoder().decode(TranslationDirectory.self, from: $0) }
    }

    /// The key from Info.plist (`APIBibleKey`, filled from API_BIBLE_KEY in Secrets.xcconfig).
    static func fromBundle(_ bundle: Bundle = .main) -> APIBibleService {
        APIBibleService(key: configuredKey(bundle.object(forInfoDictionaryKey: "APIBibleKey") as? String))
    }

    /// A usable key, or nil for an empty value, an unexpanded `$(…)` or the example placeholder.
    static func configuredKey(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              !raw.hasPrefix("$("), raw != "your-api-bible-key-here" else { return nil }
        return raw
    }

    // MARK: BibleService

    var isLive: Bool { key != nil }
    var translations: [BibleTranslation] { isLive ? directory?.available ?? [] : [] }
    var unavailableTranslations: [BibleTranslation] { isLive ? directory?.unavailable ?? [] : [] }

    func prepare() async {
        guard isLive else { return }
        if let directory, now().timeIntervalSince(directory.checked) < ChapterCache.maxAge { return }
        try? await lookUpTranslations()
    }

    func chapter(bookID: String, chapter: Int, translation: BibleTranslation?) async throws -> ChapterText {
        guard isLive else { return try await fallback.chapter(bookID: bookID, chapter: chapter, translation: nil) }
        let translation = translation ?? translations.first ?? .niv
        let cached = cache.load(translation: translation.abbreviation, bookID: bookID, chapter: chapter)
        if var cached, now().timeIntervalSince(cached.fetched) < ChapterCache.maxAge {
            cached.origin = .cache
            return cached
        }
        do {
            if directory == nil { try await lookUpTranslations() }
            guard let bibleID = directory?.ids[translation] else { throw BibleError.notOnPlan }
            let fresh = try await fetchChapter(bibleID: bibleID, translation: translation, bookID: bookID, chapter: chapter)
            cache.save(fresh)
            return fresh
        } catch let error as BibleError {
            if error == .notOnPlan { markUnavailable(translation) }
            // Offline (or any problem): an old copy is better than nothing.
            if var cached {
                cached.origin = .staleCache
                return cached
            }
            // Offline with nothing cached: the bundled sample if this chapter has one.
            if error == .offline, let bundled = fallback.cachedChapter(bookID: bookID, chapter: chapter, translation: nil) {
                return bundled
            }
            throw error
        }
    }

    func cachedChapter(bookID: String, chapter: Int, translation: BibleTranslation?) -> ChapterText? {
        // The chosen translation first, then any other one on the device, then the bundled sample.
        let order = (translation.map { [$0] } ?? []) + BibleTranslation.allCases.filter { $0 != translation }
        for t in order {
            if let text = cache.load(translation: t.abbreviation, bookID: bookID, chapter: chapter) { return text }
        }
        return fallback.cachedChapter(bookID: bookID, chapter: chapter, translation: nil)
    }

    func hasText(bookID: String, chapter: Int) -> Bool {
        isLive || fallback.hasText(bookID: bookID, chapter: chapter)
    }

    // MARK: Network

    /// Finds the translations' Bible ids by abbreviation (one call to the bibles endpoint). Callers
    /// that arrive while a lookup is under way share its result, failure included.
    func lookUpTranslations() async throws {
        let task: Task<BibleError?, Never>
        if let lookup {
            task = lookup
        } else {
            task = Task { @MainActor in
                do {
                    let response: BiblesResponse = try await get("bibles", query: [URLQueryItem(name: "language", value: "eng")])
                    let found = TranslationDirectory.match(response.data, checked: now())
                    directory = found
                    if let data = try? JSONEncoder().encode(found) { defaults.set(data, forKey: Self.directoryKey) }
                    return nil
                } catch let error as BibleError {
                    return error
                } catch {
                    return .unreadable
                }
            }
            lookup = task
        }
        let failure = await task.value
        if lookup == task { lookup = nil }
        if let failure { throw failure }
    }

    private func fetchChapter(bibleID: String, translation: BibleTranslation, bookID: String, chapter: Int) async throws -> ChapterText {
        guard let code = USFM.code(for: bookID) else { throw BibleError.notFound }
        let response: ChapterResponse = try await get("bibles/\(bibleID)/chapters/\(code).\(chapter)", query: [
            URLQueryItem(name: "content-type", value: "text"),
            URLQueryItem(name: "include-notes", value: "false"),
            URLQueryItem(name: "include-titles", value: "false"),
            URLQueryItem(name: "include-chapter-numbers", value: "false"),
            URLQueryItem(name: "include-verse-numbers", value: "true"),
            URLQueryItem(name: "include-verse-spans", value: "false"),
        ])
        let verses = ChapterParser.verses(fromText: response.data.content)
        guard !verses.isEmpty else { throw BibleError.unreadable }
        let copyright = response.data.copyright?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ChapterText(bookID: bookID, chapter: chapter, translation: translation.abbreviation, verses: verses,
                           copyright: copyright.isEmpty ? "Scripture from the \(translation.name)." : copyright,
                           fetched: now(), origin: .live)
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        guard let key else { throw BibleError.badKey }
        var components = URLComponents(url: Self.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        var request = URLRequest(url: components.url!, timeoutInterval: 20)
        request.setValue(key, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data, response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch let error as URLError {
            throw Self.error(for: error)
        } catch {
            throw BibleError.offline
        }
        // Every answer from API.Bible counts towards the monthly limit.
        usage.record(now())
        guard let http = response as? HTTPURLResponse else { throw BibleError.unreadable }
        switch http.statusCode {
        case 200..<300:
            do { return try JSONDecoder().decode(T.self, from: data) } catch { throw BibleError.unreadable }
        case 401: throw BibleError.badKey
        case 403:
            // A wrong key is a 403 too ({"statusCode":403,"error":"Forbidden","message":"Invalid API key"});
            // otherwise 403 means this Bible isn't on the plan.
            let message = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.message ?? ""
            throw message.localizedCaseInsensitiveContains("key") ? BibleError.badKey : BibleError.notOnPlan
        case 404: throw BibleError.notFound
        case 429: throw BibleError.rateLimited(retryAfter: http.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) })
        default: throw BibleError.server(http.statusCode)
        }
    }

    /// Connection problems all read as "offline".
    static func error(for error: URLError) -> BibleError {
        switch error.code {
        case .badServerResponse, .cannotDecodeContentData, .cannotParseResponse: .unreadable
        default: .offline
        }
    }

    /// The API said this translation isn't on the plan: hide it.
    private func markUnavailable(_ translation: BibleTranslation) {
        guard var directory, directory.ids[translation] != nil else { return }
        directory.ids[translation] = nil
        self.directory = directory
        if let data = try? JSONEncoder().encode(directory) { defaults.set(data, forKey: Self.directoryKey) }
    }
}

// MARK: - Translations

/// The Bible ids found for each translation on this API plan.
nonisolated struct TranslationDirectory: Codable, Equatable, Sendable {
    var ids: [BibleTranslation: String]
    let checked: Date

    var available: [BibleTranslation] { BibleTranslation.allCases.filter { ids[$0] != nil } }
    var unavailable: [BibleTranslation] { BibleTranslation.allCases.filter { ids[$0] == nil } }

    /// Picks each translation from the bibles list: by abbreviation first, then by full name.
    static func match(_ bibles: [BibleSummary], checked: Date) -> TranslationDirectory {
        func clean(_ s: String?) -> String { (s ?? "").uppercased().filter { $0.isLetter || $0.isNumber } }
        var ids: [BibleTranslation: String] = [:]
        for t in BibleTranslation.allCases {
            let byAbbreviation = bibles.first { clean($0.abbreviation) == t.abbreviation || clean($0.abbreviationLocal) == t.abbreviation }
            let byName = bibles.first { $0.name.localizedCaseInsensitiveContains(t.name) }
            if let bible = byAbbreviation ?? byName { ids[t] = bible.id }
        }
        return TranslationDirectory(ids: ids, checked: checked)
    }
}

/// One entry of `GET /bibles`.
nonisolated struct BibleSummary: Decodable, Sendable {
    let id: String
    let abbreviation: String?
    let abbreviationLocal: String?
    let name: String
}

/// API.Bible's error answer: {"statusCode": 403, "error": "Forbidden", "message": "Invalid API key"}.
nonisolated struct APIErrorBody: Decodable, Sendable {
    let statusCode: Int?
    let error: String?
    let message: String?
}

nonisolated struct BiblesResponse: Decodable, Sendable {
    let data: [BibleSummary]
}

/// `GET /bibles/{bibleId}/chapters/{chapterId}`.
nonisolated struct ChapterResponse: Decodable, Sendable {
    let data: Content
    struct Content: Decodable, Sendable {
        let id: String?
        let content: String
        let copyright: String?
    }
}

// MARK: - Parsing

nonisolated enum ChapterParser {
    /// Verses from `content-type=text`, where each verse starts with its number in brackets:
    /// "     [1] In the beginning God created… [2] Now the earth…". Whitespace and line breaks
    /// are folded into single spaces.
    static func verses(fromText content: String) -> [Verse] {
        let markers = content.matches(of: /\[(\d+)\]/)
        var out: [Verse] = []
        var seen: Set<Int> = []
        for (i, m) in markers.enumerated() {
            guard let number = Int(m.output.1) else { continue }
            let end = i + 1 < markers.count ? markers[i + 1].range.lowerBound : content.endIndex
            let text = content[m.range.upperBound..<end]
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !text.isEmpty, seen.insert(number).inserted else { continue }
            out.append(Verse(number: number, text: text))
        }
        return out
    }
}

/// API.Bible's book codes (USFM), in the catalogue's order.
nonisolated enum USFM {
    static let codes = ["GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI", "1CH", "2CH", "EZR",
                        "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO",
                        "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL",
                        "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH", "2TH", "1TI",
                        "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD", "REV"]

    @MainActor static func code(for bookID: String) -> String? {
        BibleCatalog.books.firstIndex { $0.id == bookID }.map { codes[$0] }
    }
}

// MARK: - Cache

/// Chapters on the device, one small file per chapter and translation, with the fetch date.
/// Only chapters someone opened are ever stored.
@MainActor
final class ChapterCache {
    /// A cached chapter older than this is refreshed when online (30 days).
    nonisolated static let maxAge: TimeInterval = 30 * 24 * 60 * 60

    let folder: URL

    init(folder: URL? = nil) {
        self.folder = folder ?? URL.applicationSupportDirectory.appending(path: "BibleText", directoryHint: .isDirectory)
    }

    private func file(translation: String, bookID: String, chapter: Int) -> URL {
        folder.appending(path: translation, directoryHint: .isDirectory).appending(path: "\(bookID).\(chapter).json")
    }

    func load(translation: String, bookID: String, chapter: Int) -> ChapterText? {
        guard let data = try? Data(contentsOf: file(translation: translation, bookID: bookID, chapter: chapter)),
              var text = try? JSONDecoder().decode(ChapterText.self, from: data) else { return nil }
        text.origin = .cache
        return text
    }

    func save(_ text: ChapterText) {
        let url = file(translation: text.translation, bookID: text.bookID, chapter: text.chapter)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(text) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// How many chapters are stored (for the DEBUG overlay).
    var count: Int {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return files.filter { $0.pathExtension == "json" }.count
    }

    func removeAll() { try? FileManager.default.removeItem(at: folder) }
}

// MARK: - Usage

/// API calls this month, to compare with the plan's monthly limit (DEBUG overlay).
@MainActor @Observable
final class APIUsage {
    static let shared = APIUsage()
    /// The Starter plan's monthly limit, for the overlay.
    static let monthlyLimit = 5_000

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey: String
    private(set) var counts: [String: Int]

    init(defaults: UserDefaults = .standard, storageKey: String = "bible.apiCalls") {
        self.defaults = defaults
        self.storageKey = storageKey
        counts = defaults.dictionary(forKey: storageKey) as? [String: Int] ?? [:]
    }

    static func month(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    func record(_ date: Date = .now) {
        counts[Self.month(date), default: 0] += 1
        defaults.set(counts, forKey: storageKey)
    }

    func calls(in date: Date = .now) -> Int { counts[Self.month(date)] ?? 0 }
}
