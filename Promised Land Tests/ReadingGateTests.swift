import Testing
import Foundation
import UIKit
@testable import Promised_Land

@MainActor
struct ReadingGateTests {
    @Test("Finish unlocks only after reaching the end AND the minimum time")
    func gate() {
        let need = ReadingGate.minimumSeconds(words: 1000, strictness: .standard)
        #expect(need == 300) // 1000 words at 200 a minute
        #expect(!ReadingGate.canFinish(reachedEnd: false, elapsed: 999, required: need))
        #expect(!ReadingGate.canFinish(reachedEnd: true, elapsed: 120, required: need))
        #expect(ReadingGate.canFinish(reachedEnd: true, elapsed: 300, required: need))
        #expect(ReadingGate.progress(reachedEnd: false, elapsed: 999, required: need) < 1)
    }

    @Test("The timer has a floor and a cap; Relaxed has none")
    func floorCap() {
        #expect(ReadingGate.minimumSeconds(words: 20, strictness: .standard) == ReadingStrictness.standard.floor)
        #expect(ReadingGate.minimumSeconds(words: 50_000, strictness: .standard) == ReadingStrictness.standard.cap)
        #expect(ReadingGate.minimumSeconds(words: 1000, strictness: .relaxed) == 0)
        #expect(ReadingGate.minimumSeconds(words: 1000, strictness: .strict) > ReadingGate.minimumSeconds(words: 1000, strictness: .standard))
        #expect(!ReadingGate.timerApplies(strictness: .relaxed, ownBible: false))
        #expect(ReadingGate.timerApplies(strictness: .standard, ownBible: false))
        #expect(!ReadingGate.timerApplies(strictness: .standard, ownBible: true))
        #expect(ReadingGate.timerApplies(strictness: .strict, ownBible: true))
    }

    @Test("Bundled chapters are timed by their words; others by a typical length")
    func words() {
        let bundled = BundledBibleService()
        #expect(ReadingGate.words(bookID: "john", chapter: 15, service: bundled) > 0)
        #expect(ReadingGate.words(bookID: "obadiah", chapter: 1, service: bundled) == ReadingGate.typicalChapterWords)
    }

    @Test("Kids accounts default to Strict; others to Standard; a saved choice wins")
    func defaults() {
        #expect(ReadingStrictness.current(stored: "", ageGroup: AgeGroup.under13.rawValue) == .strict)
        #expect(ReadingStrictness.current(stored: "", ageGroup: AgeGroup.adult.rawValue) == .standard)
        #expect(ReadingStrictness.current(stored: "", ageGroup: "") == .standard)
        #expect(ReadingStrictness.current(stored: "relaxed", ageGroup: AgeGroup.under13.rawValue) == .relaxed)
    }

    @Test("Questions are about real chapters, have one right answer, and are unreviewed")
    func questions() {
        for q in QuestionData.all {
            #expect(!q.reviewed)
            #expect(q.options.indices.contains(q.answer))
            #expect(Set(q.options).count == q.options.count)
            #expect(BibleCatalog.book(id: q.bookID).map { (1...$0.chapterCount).contains(q.chapter) } == true)
        }
        // Every chapter with bundled text has a question.
        for (book, chapters) in SampleText.chapters { for c in chapters { #expect(QuestionData.question(bookID: book, chapter: c.number) != nil, "\(book) \(c.number)") } }
        #expect(QuestionData.question(bookID: "obadiah", chapter: 1) == nil) // falls back to a reflection
    }
}

@MainActor
struct ChapterDetectorTests {
    func d(_ lines: [String]) -> ChapterDetector.Match? { ChapterDetector.detect(lines) }

    @Test("Reads common page headings", arguments: [
        ("JOHN 15", "john", 15), ("John 15:1", "john", 15), ("1 Samuel 17", "1samuel", 17),
        ("I SAMUEL 17:12–30", "1samuel", 17), ("1SAMUEL 17", "1samuel", 17), ("First Samuel 17", "1samuel", 17),
        ("Ps. 23", "psalms", 23), ("PSALM 119", "psalms", 119), ("SONG OF SOLOMON 2", "songofsongs", 2),
        ("1 John 4:7", "1john", 4), ("Revelation 21", "revelation", 21), ("Gen 1", "genesis", 1),
        ("THE GOSPEL ACCORDING TO MARK 4", "mark", 4), ("2 Cor. 5:17", "2corinthians", 5),
    ])
    func headings(line: String, book: String, chapter: Int) {
        #expect(d([line]) == .init(bookID: book, chapter: chapter))
    }

    @Test("Headers win over body text, and impossible chapters are ignored")
    func picking() {
        #expect(d(["JOHN 15", "1 I am the true vine, and my Father is the husbandman."]) == .init(bookID: "john", chapter: 15))
        #expect(d(["RUTH 9"]) == nil) // Ruth has 4 chapters
        #expect(d(["the quick brown fox"]) == nil)
    }

    @Test("A book name with the chapter number on the next line, and one-chapter books")
    func split() {
        #expect(d(["JOHN", "15"]) == .init(bookID: "john", chapter: 15))
        #expect(d(["JUDE", "1 Jude, a servant of Jesus Christ"]) == .init(bookID: "jude", chapter: 1))
    }
}

@MainActor
struct PageTextTests {
    @Test("Vision reads a page heading on this device, and the detector finds the chapter")
    func visionPipeline() async {
        let size = CGSize(width: 900, height: 600)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            ("JOHN 15" as NSString).draw(at: CGPoint(x: 330, y: 40), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 54)])
            ("1 I am the true vine, and my Father is the husbandman." as NSString)
                .draw(at: CGPoint(x: 40, y: 200), withAttributes: [.font: UIFont.systemFont(ofSize: 30)])
        }
        let lines = await PageText.lines(in: image)
        #expect(ChapterDetector.detect(lines) == .init(bookID: "john", chapter: 15), "Read: \(lines)")
    }
}
