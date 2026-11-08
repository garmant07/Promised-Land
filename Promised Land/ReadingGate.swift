import Foundation

/// How strictly a chapter has to be read before it counts (Settings → Reading).
enum ReadingStrictness: String, CaseIterable, Identifiable {
    /// Read to the end and answer the question; no timer.
    case relaxed
    /// Read to the end, a minimum reading time (the chapter's words at 200 a minute), and the question.
    case standard
    /// The same timer, and it also applies when reading in your own Bible.
    case strict

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relaxed: "Relaxed"
        case .standard: "Standard"
        case .strict: "Strict"
        }
    }

    var detail: String {
        switch self {
        case .relaxed: "Read to the end, then answer one easy question. No timer."
        case .standard: "Read to the end and spend as long as reading it takes (about 200 words a minute), then the question."
        case .strict: "The same reading time, and it also applies when you read in your own Bible."
        }
    }

    /// Words a minute the timer assumes (nil: no timer).
    var wordsPerMinute: Double? { self == .relaxed ? nil : ReadingGate.wordsPerMinute }

    /// Kids accounts start Strict (a grown-up can change it); everyone else Standard.
    static func defaultFor(ageGroup: String) -> ReadingStrictness {
        ageGroup == AgeGroup.under13.rawValue ? .strict : .standard
    }

    /// The stored choice, or the default for the age group.
    static func current(stored: String, ageGroup: String) -> ReadingStrictness {
        ReadingStrictness(rawValue: stored) ?? defaultFor(ageGroup: ageGroup)
    }
}

/// The rules for when "Mark complete" unlocks. Pure, so it's testable.
enum ReadingGate {
    /// A typical chapter's length, used when the text isn't bundled (reading in your own Bible).
    static let typicalChapterWords = 650

    /// Words in a chapter's text on the device (cached or bundled), or a typical length. Never
    /// goes to the network.
    static func words(bookID: String, chapter: Int, service: any BibleService, translation: BibleTranslation? = nil) -> Int {
        service.cachedChapter(bookID: bookID, chapter: chapter, translation: translation)?.words ?? typicalChapterWords
    }

    /// Words in some verses.
    nonisolated static func words(_ verses: [Verse]) -> Int {
        verses.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
    }

    /// The reading pace the timer uses: the chapter's words at this many a minute.
    nonisolated static let wordsPerMinute: Double = 200
    /// The shortest and longest reading time (a few verses still take a moment; Psalm 119 isn't 13 minutes).
    nonisolated static let minimumFloor: Double = 30
    nonisolated static let minimumCap: Double = 12 * 60

    /// Seconds of reading needed before Finish unlocks (0 = no timer): the words at 200 a minute,
    /// between 30 seconds and 12 minutes.
    static func minimumSeconds(words: Int, strictness: ReadingStrictness) -> Double {
        guard let wpm = strictness.wordsPerMinute else { return 0 }
        return min(minimumCap, max(minimumFloor, Double(max(0, words)) / wpm * 60))
    }

    /// Does the timer apply? In-app reading: unless Relaxed. Your own Bible: only when Strict.
    static func timerApplies(strictness: ReadingStrictness, ownBible: Bool) -> Bool {
        ownBible ? strictness == .strict : strictness != .relaxed
    }

    /// Finish unlocks once you've reached the end and enough time has passed.
    static func canFinish(reachedEnd: Bool, elapsed: Double, required: Double) -> Bool {
        reachedEnd && elapsed >= required
    }

    /// Progress for the ring on the Finish button (0…1).
    static func progress(reachedEnd: Bool, elapsed: Double, required: Double) -> Double {
        let time = required > 0 ? min(1, elapsed / required) : 1
        return reachedEnd ? time : min(time, 0.95)
    }
}

/// Reading time that only counts while the chapter is actually being read: started and stopped as
/// the text comes on and off screen (and the app goes to the background).
struct ReadingClock: Equatable {
    private(set) var banked: Double = 0
    private(set) var since: Date?

    var isRunning: Bool { since != nil }

    /// Starts or stops counting at `now` (no change if it's already in that state).
    mutating func set(running: Bool, at now: Date) {
        if running, since == nil { since = now }
        if !running, let start = since { banked += max(0, now.timeIntervalSince(start)); since = nil }
    }

    func elapsed(at now: Date) -> Double { banked + (since.map { max(0, now.timeIntervalSince($0)) } ?? 0) }

    /// Back to zero (after a read counts), running or not as before.
    mutating func reset(at now: Date) {
        banked = 0
        if since != nil { since = now }
    }
}

/// One chapter's reading session: the time spent on it, whether the last page has been reached,
/// and the time it needs. Lives outside the reader's views (in `ReadingSessions`), so page turns,
/// re-renders and sheets never recreate or reset it. Time comes from timestamps, so a missed tick
/// can't make it drift or stall; `tick` only refreshes what's shown and latches "time's up".
@MainActor @Observable
final class ReadingSession {
    let bookID: String
    let chapter: Int

    /// The chapter's words, counted once from its text (per translation).
    private(set) var words: Int?
    @ObservationIgnored private var wordsKey: String?
    private(set) var strictness: ReadingStrictness = .standard
    private(set) var reachedEnd = false
    /// The reading time is done (latched: once up it stays up until `reset`).
    private(set) var timeUp = false
    /// Whole seconds still to go (for the button; refreshed by `tick`).
    private(set) var secondsLeft = 0
    /// 0…1 for the ring (refreshed by `tick`).
    private(set) var progress: Double = 0
    @ObservationIgnored private var clock = ReadingClock()

    init(bookID: String, chapter: Int) {
        self.bookID = bookID
        self.chapter = chapter
    }

    var isRunning: Bool { clock.isRunning }
    /// Seconds needed (0 until the text's words are known, or with no timer).
    var requiredSeconds: Double { words.map { ReadingGate.minimumSeconds(words: $0, strictness: strictness) } ?? 0 }
    /// Mark complete is unlocked.
    var canFinish: Bool { reachedEnd && timeUp }

    func elapsed(at now: Date) -> Double { clock.elapsed(at: now) }

    /// The text being read. Counts its words only when it's new (a different translation).
    func setText(_ text: ChapterText, strictness: ReadingStrictness, at now: Date = .now) {
        let key = text.translation
        if key != wordsKey { wordsKey = key; words = text.words }
        self.strictness = strictness
        tick(at: now)
    }

    func setStrictness(_ strictness: ReadingStrictness, at now: Date = .now) {
        guard strictness != self.strictness else { return }
        self.strictness = strictness
        tick(at: now)
    }

    /// Counting runs only while the text is being read (on screen, nothing over it, app open).
    func setRunning(_ running: Bool, at now: Date = .now) {
        clock.set(running: running, at: now)
        tick(at: now)
    }

    func markReachedEnd(at now: Date = .now) {
        if !reachedEnd { reachedEnd = true }
        tick(at: now)
    }

    /// Refreshes the countdown and moves on once the time is up. Called about once a second
    /// while running, and on every change, so the gate always opens when the time reaches zero.
    func tick(at now: Date = .now) {
        guard words != nil else { return }
        let required = requiredSeconds
        let elapsed = clock.elapsed(at: now)
        let up = timeUp || elapsed >= required
        let left = up ? 0 : max(1, Int((required - elapsed).rounded(.up)))
        let ring = ReadingGate.progress(reachedEnd: reachedEnd, elapsed: up ? required : elapsed, required: required)
        if up != timeUp { timeUp = up }
        if left != secondsLeft { secondsLeft = left }
        if abs(ring - progress) > 0.0005 || (ring == 1 && progress != 1) { progress = ring }
    }

    /// Seconds until the next whole-second change of the countdown (for the ticker's sleep).
    func secondsToNextTick(at now: Date = .now) -> Double {
        guard words != nil else { return 1 }
        let remaining = requiredSeconds - clock.elapsed(at: now)
        guard remaining > 0 else { return 0 }
        let fraction = remaining - remaining.rounded(.down)
        return fraction > 0.01 ? fraction : 1
    }

    /// Back to zero after a read counts (a reread starts a fresh session).
    func reset(at now: Date = .now) {
        clock.reset(at: now)
        reachedEnd = false
        timeUp = false
        tick(at: now)
    }
}

/// Every chapter's reading session, kept for the life of the app (not in any view), so leaving a
/// page, turning pages or the reader being rebuilt picks up exactly where it was.
@MainActor
final class ReadingSessions {
    static let shared = ReadingSessions()
    private var sessions: [String: ReadingSession] = [:]

    func session(bookID: String, chapter: Int) -> ReadingSession {
        let key = "\(bookID) \(chapter)"
        if let s = sessions[key] { return s }
        let s = ReadingSession(bookID: bookID, chapter: chapter)
        sessions[key] = s
        return s
    }
}
