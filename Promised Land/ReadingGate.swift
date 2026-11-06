import Foundation

/// How strictly a chapter has to be read before it counts (Settings → Reading).
enum ReadingStrictness: String, CaseIterable, Identifiable {
    /// Read to the end and answer the question; no timer.
    case relaxed
    /// Read to the end, a minimum reading time (the chapter's words at 220 a minute), and the question.
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
        case .standard: "Read to the end and spend as long as reading it takes (220 words a minute), then the question."
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

/// The rules for when "Finish" unlocks. Pure, so it's testable.
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

    /// Seconds of reading needed before Finish unlocks (0 = no timer).
    /// The reading pace the timer uses: the chapter's words at this many a minute, nothing added
    /// or capped.
    nonisolated static let wordsPerMinute: Double = 220

    static func minimumSeconds(words: Int, strictness: ReadingStrictness) -> Double {
        guard let wpm = strictness.wordsPerMinute else { return 0 }
        return Double(max(0, words)) / wpm * 60
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
