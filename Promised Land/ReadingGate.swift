import Foundation

/// How strictly a chapter has to be read before it counts (Settings → Reading).
enum ReadingStrictness: String, CaseIterable, Identifiable {
    /// Read to the end and answer the question; no timer.
    case relaxed
    /// Read to the end, a minimum reading time (about 200 words a minute), and the question.
    case standard
    /// A slower reading pace, and the timer also applies when reading in your own Bible.
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
        case .standard: "Read to the end and spend a little time on it (about 200 words a minute), then the question."
        case .strict: "A slower reading pace, and the timer also applies when you read in your own Bible."
        }
    }

    /// Words a minute the timer assumes (nil: no timer).
    var wordsPerMinute: Double? {
        switch self {
        case .relaxed: nil
        case .standard: 200
        case .strict: 160
        }
    }

    /// The shortest and longest the timer ever asks for, in seconds.
    var floor: Double { self == .strict ? 90 : 45 }
    var cap: Double { self == .strict ? 600 : 480 }

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

    /// Words in a chapter's bundled text, or a typical length.
    static func words(bookID: String, chapter: Int) -> Int {
        guard let verses = SampleText.verses(book: bookID, chapter: chapter) else { return typicalChapterWords }
        return verses.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
    }

    /// Seconds of reading needed before Finish unlocks (0 = no timer).
    static func minimumSeconds(words: Int, strictness: ReadingStrictness) -> Double {
        guard let wpm = strictness.wordsPerMinute else { return 0 }
        return min(strictness.cap, max(strictness.floor, Double(words) / wpm * 60))
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
