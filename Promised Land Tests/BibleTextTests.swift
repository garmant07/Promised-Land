import Testing
import Foundation
@testable import Promised_Land

// MARK: - Mocks

/// A BibleService the tests script: chapters it has, chapters that fail, and what's "cached".
@MainActor
final class MockBibleService: BibleService {
    var isLive = true
    var translations: [BibleTranslation] = [.niv, .csb]
    var unavailableTranslations: [BibleTranslation] = [.nlt]
    var chapters: [String: ChapterText] = [:]
    var cached: [String: ChapterText] = [:]
    /// Thrown by `chapter` (nil: answer from `chapters`).
    var failure: BibleError?
    private(set) var requests = 0

    static func key(_ book: String, _ chapter: Int) -> String { "\(book).\(chapter)" }

    func prepare() async {}

    func chapter(bookID: String, chapter: Int, translation: BibleTranslation?) async throws -> ChapterText {
        requests += 1
        if let failure { throw failure }
        guard let text = chapters[Self.key(bookID, chapter)] else { throw BibleError.noText }
        return text
    }

    func cachedChapter(bookID: String, chapter: Int, translation: BibleTranslation?) -> ChapterText? { cached[Self.key(bookID, chapter)] }
    func hasText(bookID: String, chapter: Int) -> Bool { isLive }
}

/// Answers requests from a script, and records them. Throws `URLError` to play "offline".
@MainActor
final class MockTransport: HTTPTransport {
    var offline = false
    /// Path suffix → (status, body, headers).
    var routes: [(suffix: String, status: Int, body: String, headers: [String: String])] = []
    private(set) var requests: [URLRequest] = []

    func route(_ suffix: String, status: Int = 200, body: String, headers: [String: String] = [:]) {
        routes.append((suffix, status, body, headers))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if offline { throw URLError(.notConnectedToInternet) }
        requests.append(request)
        let path = request.url!.path()
        guard let r = routes.last(where: { path.hasSuffix($0.suffix) }) else {
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        }
        return (Data(r.body.utf8), HTTPURLResponse(url: request.url!, statusCode: r.status, httpVersion: nil, headerFields: r.headers)!)
    }
}

@MainActor
private func text(_ book: String, _ chapter: Int, _ verses: [String], translation: String = "NIV", fetched: Date = .now) -> ChapterText {
    ChapterText(bookID: book, chapter: chapter, translation: translation,
                verses: verses.enumerated().map { Verse(number: $0.offset + 1, text: $0.element) },
                copyright: "© Test", fetched: fetched)
}

// MARK: - Live service (mock transport)

@MainActor
struct APIBibleServiceTests {
    static let bibles = """
    {"data":[
      {"id":"aaa-niv-01","abbreviation":"NIV","abbreviationLocal":"NIV","name":"New International Version"},
      {"id":"bbb-kjv-01","abbreviation":"engKJV","abbreviationLocal":"KJV","name":"King James Version"},
      {"id":"ccc-csb-01","abbreviation":"csb","abbreviationLocal":"CSB","name":"Christian Standard Bible"}
    ]}
    """
    static let john3 = """
    {"data":{"id":"JHN.3","content":"     [1] Now there was a Pharisee, a man named Nicodemus.\\n     [2] He came to Jesus at night. [16] For God so loved the world.","copyright":"THE HOLY BIBLE, NEW INTERNATIONAL VERSION®, NIV® Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc.®"},"meta":{"fums":""}}
    """

    struct Setup {
        let service: APIBibleService
        let transport: MockTransport
        let usage: APIUsage
        let clock: Clock
    }

    /// A settable "now".
    final class Clock { var now = Date(timeIntervalSince1970: 2_000_000_000) }

    func make(key: String? = "test-key") -> Setup {
        let defaults = UserDefaults(suiteName: "bible-tests-\(UUID().uuidString)")!
        let transport = MockTransport()
        transport.route("/bibles", body: Self.bibles)
        transport.route("/chapters/JHN.3", body: Self.john3)
        let usage = APIUsage(defaults: defaults)
        let cache = ChapterCache(folder: FileManager.default.temporaryDirectory.appending(path: "bible-cache-\(UUID().uuidString)"))
        let service = APIBibleService(key: key, transport: transport, cache: cache, usage: usage, defaults: defaults)
        let clock = Clock()
        service.now = { clock.now }
        return Setup(service: service, transport: transport, usage: usage, clock: clock)
    }

    @Test("A missing, empty or placeholder key means no live text")
    func keys() {
        #expect(APIBibleService.configuredKey(nil) == nil)
        #expect(APIBibleService.configuredKey("  ") == nil)
        #expect(APIBibleService.configuredKey("$(API_BIBLE_KEY)") == nil)
        #expect(APIBibleService.configuredKey("your-api-bible-key-here") == nil)
        #expect(APIBibleService.configuredKey("abc123") == "abc123")
        #expect(!APIBibleService(key: nil).isLive)
    }

    @Test("First run finds NIV, NLT and CSB by abbreviation; one that isn't on the plan is hidden")
    func lookUpTranslations() async throws {
        let s = make()
        await s.service.prepare()
        #expect(s.service.translations == [.niv, .csb])
        #expect(s.service.unavailableTranslations == [.nlt])
        #expect(s.service.directory?.ids[.csb] == "ccc-csb-01")
        let request = try #require(s.transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "api-key") == "test-key")
        #expect(request.url?.host() == "rest.api.bible")
        #expect(request.url?.path() == "/v1/bibles")
        // Saved: preparing again doesn't ask again.
        await s.service.prepare()
        #expect(s.transport.requests.count == 1)
    }

    @Test("A chapter is fetched once as plain text without notes, then read from the cache")
    func fetchThenCache() async throws {
        let s = make()
        let first = try await s.service.chapter(bookID: "john", chapter: 3, translation: .niv)
        #expect(first.origin == .live)
        #expect(first.verses.map(\.number) == [1, 2, 16])
        #expect(first.verses[0].text == "Now there was a Pharisee, a man named Nicodemus.")
        #expect(first.copyright.contains("Biblica"))
        let request = try #require(s.transport.requests.last)
        #expect(request.url?.path() == "/v1/bibles/aaa-niv-01/chapters/JHN.3")
        let query = Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            .queryItems!.map { ($0.name, $0.value ?? "") })
        #expect(query["content-type"] == "text")
        #expect(query["include-notes"] == "false")
        #expect(query["include-verse-numbers"] == "true")

        let again = try await s.service.chapter(bookID: "john", chapter: 3, translation: .niv)
        #expect(again.origin == .cache)
        #expect(again.verses == first.verses)
        // The bibles lookup and one chapter: nothing else was downloaded.
        #expect(s.transport.requests.count == 2)
        #expect(s.usage.calls(in: s.clock.now) == 2)
        #expect(s.service.cache.count == 1)
        #expect(s.service.cachedChapter(bookID: "john", chapter: 3, translation: .niv)?.verses.count == 3)
    }

    @Test("A cached chapter older than 30 days is refreshed when online, and kept when offline")
    func staleRefresh() async throws {
        let s = make()
        _ = try await s.service.chapter(bookID: "john", chapter: 3, translation: .niv)
        s.clock.now += 31 * 24 * 3600
        s.transport.offline = true
        let offline = try await s.service.chapter(bookID: "john", chapter: 3, translation: .niv)
        #expect(offline.origin == .staleCache)
        s.transport.offline = false
        let refreshed = try await s.service.chapter(bookID: "john", chapter: 3, translation: .niv)
        #expect(refreshed.origin == .live)
        #expect(refreshed.fetched == s.clock.now)
        // 29 days later it's still fresh: no request.
        let before = s.transport.requests.count
        s.clock.now += 29 * 24 * 3600
        #expect(try await s.service.chapter(bookID: "john", chapter: 3, translation: .niv).origin == .cache)
        #expect(s.transport.requests.count == before)
    }

    @Test("Offline with nothing cached: the bundled sample if there is one, otherwise 'offline'")
    func offlineNoCache() async throws {
        let s = make()
        await s.service.prepare()
        s.transport.offline = true
        let genesis = try await s.service.chapter(bookID: "genesis", chapter: 1, translation: .niv)
        #expect(genesis.origin == .bundled && genesis.translation == "ASV")
        await #expect(throws: BibleError.offline) {
            try await s.service.chapter(bookID: "obadiah", chapter: 1, translation: .niv)
        }
    }

    @Test("Rate limits, bad keys and translations not on the plan give clear errors")
    func httpErrors() async throws {
        let s = make()
        await s.service.prepare()
        s.transport.route("/chapters/JHN.3", status: 429, body: "{}", headers: ["Retry-After": "120"])
        await #expect(throws: BibleError.rateLimited(retryAfter: 120)) {
            try await s.service.chapter(bookID: "john", chapter: 3, translation: .niv)
        }
        s.transport.route("/chapters/JHN.3", status: 401, body: "{}")
        await #expect(throws: BibleError.badKey) {
            try await s.service.chapter(bookID: "john", chapter: 3, translation: .niv)
        }
        // What API.Bible really answers for a wrong key (checked against the live API): a 403.
        s.transport.route("/chapters/JHN.3", status: 403,
                          body: #"{"statusCode": 403, "error": "Forbidden", "message": "Invalid API key"}"#)
        await #expect(throws: BibleError.badKey) {
            try await s.service.chapter(bookID: "john", chapter: 3, translation: .niv)
        }
        #expect(s.service.translations == [.niv, .csb])
        s.transport.route("/chapters/JHN.3", status: 403,
                          body: #"{"statusCode": 403, "error": "Forbidden", "message": "Bible not available on your plan"}"#)
        await #expect(throws: BibleError.notOnPlan) {
            try await s.service.chapter(bookID: "john", chapter: 3, translation: .csb)
        }
        // CSB isn't on this plan after all: it's hidden.
        #expect(s.service.translations == [.niv])
        #expect(BibleError.rateLimited(retryAfter: 120).message.contains("2 minutes"))
        #expect(BibleError.offline.title == "Connect to the internet to load this chapter")
        #expect(BibleError.offline.canRetry && !BibleError.badKey.canRetry)
    }

    @Test("A bad key shows as a bad key even when the first-run lookup is already under way")
    func badKeyDuringLookup() async {
        let s = make()
        s.transport.route("/bibles", status: 403, body: #"{"statusCode": 403, "error": "Forbidden", "message": "Invalid API key"}"#)
        async let first: Void = s.service.prepare()
        await #expect(throws: BibleError.badKey) {
            try await s.service.chapter(bookID: "john", chapter: 3, translation: nil)
        }
        await first
        #expect(s.service.translations.isEmpty)
    }

    @Test("Without a key, the bundled sample is used and nothing is requested")
    func noKey() async throws {
        let s = make(key: nil)
        let genesis = try await s.service.chapter(bookID: "genesis", chapter: 1, translation: nil)
        #expect(genesis.translation == "ASV")
        await #expect(throws: BibleError.noText) {
            try await s.service.chapter(bookID: "obadiah", chapter: 1, translation: nil)
        }
        #expect(s.transport.requests.isEmpty)
        #expect(s.service.translations.isEmpty)
    }

    @Test("Text output is split into numbered verses")
    func parser() {
        let verses = ChapterParser.verses(fromText: "The Beginning\n     [1] In the beginning God created.\n\n[2]   Now the earth  was formless. [3] And God said.")
        #expect(verses.map(\.number) == [1, 2, 3])
        #expect(verses[1].text == "Now the earth was formless.")
        #expect(ChapterParser.verses(fromText: "no numbers here").isEmpty)
    }

    @Test("Every book has an API.Bible code")
    func usfm() {
        #expect(USFM.codes.count == BibleCatalog.books.count)
        #expect(USFM.code(for: "genesis") == "GEN")
        #expect(USFM.code(for: "1samuel") == "1SA")
        #expect(USFM.code(for: "songofsongs") == "SNG")
        #expect(USFM.code(for: "john") == "JHN")
        #expect(USFM.code(for: "revelation") == "REV")
    }

    @Test("The remembered translation is used if available, otherwise the first that is")
    func choice() {
        #expect(BibleTranslation.choose(stored: "CSB", available: [.niv, .csb]) == .csb)
        #expect(BibleTranslation.choose(stored: "NLT", available: [.niv, .csb]) == .niv)
        #expect(BibleTranslation.choose(stored: "NIV", available: []) == nil)
    }
}

// MARK: - Through the BibleService protocol (mock service)

@MainActor
struct BibleServiceClientTests {
    @Test("The reader shows the text, or why not, and Retry loads it")
    func loader() async {
        let mock = MockBibleService()
        mock.chapters[MockBibleService.key("john", 3)] = text("john", 3, ["For God so loved the world."])
        let loader = ChapterLoader()

        mock.failure = .offline
        await loader.load(mock, bookID: "john", chapter: 3, translation: .niv)
        #expect(loader.state == .failed(.offline))

        mock.failure = nil  // back online: Retry
        await loader.load(mock, bookID: "john", chapter: 3, translation: .niv)
        #expect(loader.text?.verses.first?.text == "For God so loved the world.")

        await loader.load(mock, bookID: "obadiah", chapter: 1, translation: .niv)
        #expect(loader.state == .ownBible)
    }

    @Test("Reading time comes from the cached text's words, or a typical length")
    func wordCounts() {
        let mock = MockBibleService()
        mock.cached[MockBibleService.key("ruth", 1)] = text("ruth", 1, ["one two three", "four five"])
        #expect(ReadingGate.words(bookID: "ruth", chapter: 1, service: mock) == 5)
        #expect(ReadingGate.words(bookID: "ruth", chapter: 2, service: mock) == ReadingGate.typicalChapterWords)
    }

    @Test("A chapter without a written question gets one made from its cached text")
    func questionsFromText() throws {
        let mock = MockBibleService()
        // Obadiah 1 has no written question.
        mock.cached[MockBibleService.key("obadiah", 1)] = text("obadiah", 1, [
            "The vision of Obadiah concerning Edom and the messengers among the nations.",
            "See, I will make you small among the nations; you will be utterly despised.",
            "The pride of your heart has deceived you, you who live in the clefts of the rocks.",
        ])
        let q = try #require(QuestionData.question(bookID: "obadiah", chapter: 1, service: mock, translation: .niv))
        #expect(q.options.count == 3)
        #expect(Set(q.options.map { $0.lowercased() }).count == 3)
        #expect(q.prompt.contains(TextQuestion.blank))
        #expect(!q.prompt.contains(q.options[q.answer]))
        #expect(q.reference.hasPrefix("Obadiah 1:"))
        #expect(q.source.hasSuffix("(NIV)"))
        // The same chapter always gets the same question.
        #expect(QuestionData.question(bookID: "obadiah", chapter: 1, service: mock, translation: .niv) == q)

        // A written question still wins; nothing cached means no made-up question.
        mock.cached[MockBibleService.key("john", 3)] = text("john", 3, ["A long enough verse about Nicodemus coming at night to see Jesus."])
        #expect(QuestionData.question(bookID: "john", chapter: 3, service: mock, translation: .niv)?.prompt == "Who came to Jesus by night?")
        #expect(QuestionData.question(bookID: "nahum", chapter: 1, service: mock, translation: .niv) == nil)
    }
}
