import Testing
import Foundation
@testable import Promised_Land

@MainActor
struct ReadingGateTests {
    @Test("The button says Keep reading until the chapter is done, then Mark complete (again, if read before)")
    func buttonTitle() {
        #expect(FinishButton.title(readBefore: false) == "Mark complete")
        #expect(FinishButton.title(readBefore: true) == "Mark complete again")
        // While reading: the time left, counting down.
        #expect(FinishButton.label(enabled: false, remaining: 161, readBefore: false) == "Keep reading \u{00B7} 2:41")
        #expect(FinishButton.label(enabled: false, remaining: 9.2, readBefore: true) == "Keep reading \u{00B7} 0:10")
        #expect(FinishButton.label(enabled: false, remaining: 0, readBefore: false) == "Keep reading")
        #expect(FinishButton.label(enabled: true, remaining: 0, readBefore: true) == "Mark complete again")
        #expect(FinishButton.spokenTimeLeft(161) == "2 minutes 41 seconds left")
        #expect(FinishButton.spokenTimeLeft(60) == "1 minute left")
        #expect(FinishButton.spokenTimeLeft(5) == "5 seconds left")
    }

    @Test("Reading time counts only while the chapter is on screen, and picks up where it left off")
    func clockPauses() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        var clock = ReadingClock()
        #expect(clock.elapsed(at: t0.addingTimeInterval(50)) == 0)       // not started: loading, or not on screen
        clock.set(running: true, at: t0)
        #expect(clock.elapsed(at: t0.addingTimeInterval(30)) == 30)
        clock.set(running: false, at: t0.addingTimeInterval(30))          // a sheet covers it / next chapter / background
        #expect(clock.elapsed(at: t0.addingTimeInterval(500)) == 30)      // no time passes while away
        clock.set(running: true, at: t0.addingTimeInterval(500))
        clock.set(running: true, at: t0.addingTimeInterval(510))          // already running: no change
        #expect(clock.elapsed(at: t0.addingTimeInterval(520)) == 50)
        clock.reset(at: t0.addingTimeInterval(520))
        #expect(clock.elapsed(at: t0.addingTimeInterval(525)) == 5 && clock.isRunning)
    }

    @Test("Mark complete unlocks only after reaching the end AND the minimum time")
    func gate() {
        let need = ReadingGate.minimumSeconds(words: 1100, strictness: .standard)
        #expect(need == 330) // 1100 words at 200 a minute
        #expect(!ReadingGate.canFinish(reachedEnd: false, elapsed: 999, required: need))
        #expect(!ReadingGate.canFinish(reachedEnd: true, elapsed: 120, required: need))
        #expect(ReadingGate.canFinish(reachedEnd: true, elapsed: 330, required: need))
        #expect(ReadingGate.progress(reachedEnd: false, elapsed: 999, required: need) < 1)
    }

    @Test("The timer is the words at 200 a minute, between 30 s and 12 min; Strict uses the same pace; Relaxed has none")
    func pace() {
        #expect(ReadingGate.minimumSeconds(words: 22, strictness: .standard) == 30)       // floor
        #expect(ReadingGate.minimumSeconds(words: 650, strictness: .standard) == 195)     // 650 / 200 × 60
        #expect(ReadingGate.minimumSeconds(words: 22_000, strictness: .standard) == 720)  // cap
        #expect(ReadingGate.minimumSeconds(words: 0, strictness: .standard) == 30)
        #expect(ReadingGate.minimumSeconds(words: 1000, strictness: .relaxed) == 0)
        #expect(ReadingGate.minimumSeconds(words: 1000, strictness: .strict) == ReadingGate.minimumSeconds(words: 1000, strictness: .standard))
        #expect(!ReadingGate.timerApplies(strictness: .relaxed, ownBible: false))
        #expect(ReadingGate.timerApplies(strictness: .standard, ownBible: false))
        #expect(!ReadingGate.timerApplies(strictness: .standard, ownBible: true))
        #expect(ReadingGate.timerApplies(strictness: .strict, ownBible: true))
    }

    // MARK: Reading session

    private func text(words: Int, translation: String = "ASV") -> ChapterText {
        let verse = Verse(number: 1, text: Array(repeating: "word", count: words).joined(separator: " "))
        return ChapterText(bookID: "ruth", chapter: 1, translation: translation, verses: [verse], copyright: "", fetched: .now)
    }

    @Test("Turning pages, re-rendering and covering the text don't reset the session")
    func sessionSurvivesPageTurns() {
        let t0 = Date(timeIntervalSince1970: 2_000_000)
        let a = ReadingSessions.shared.session(bookID: "test-pages", chapter: 1)
        a.setText(text(words: 1000), strictness: .standard, at: t0)
        a.setRunning(true, at: t0)
        a.tick(at: t0.addingTimeInterval(60))
        // The reader is rebuilt (a re-render, a page turn, back from the next chapter): same session.
        let b = ReadingSessions.shared.session(bookID: "test-pages", chapter: 1)
        #expect(a === b)
        b.setText(text(words: 1000), strictness: .standard, at: t0.addingTimeInterval(61)) // text set again
        b.markReachedEnd(at: t0.addingTimeInterval(62))                                     // last page shown
        b.setRunning(true, at: t0.addingTimeInterval(63))                                   // already running
        #expect(b.elapsed(at: t0.addingTimeInterval(90)) == 90)
        #expect(b.words == 1000)
        #expect(ReadingSessions.shared.session(bookID: "test-pages", chapter: 2) !== a)     // chapters apart
    }

    @Test("The required time scales with the chapter's words")
    func sessionScalesWithWords() {
        let short = ReadingSession(bookID: "ruth", chapter: 1), long = ReadingSession(bookID: "ruth", chapter: 2)
        short.setText(text(words: 400), strictness: .standard)
        long.setText(text(words: 1200), strictness: .standard)
        #expect(short.requiredSeconds == 120)
        #expect(long.requiredSeconds == 360)
        let relaxed = ReadingSession(bookID: "ruth", chapter: 3)
        relaxed.setText(text(words: 1200), strictness: .relaxed)
        relaxed.markReachedEnd()
        #expect(relaxed.requiredSeconds == 0 && relaxed.canFinish)                           // Relaxed: no timer
    }

    @Test("Backgrounding (or a sheet) pauses the time; it resumes on return")
    func sessionPauses() {
        let t0 = Date(timeIntervalSince1970: 3_000_000)
        let s = ReadingSession(bookID: "ruth", chapter: 1)
        s.setText(text(words: 400), strictness: .standard, at: t0)
        s.setRunning(true, at: t0)
        s.setRunning(false, at: t0.addingTimeInterval(40))                                   // background
        s.tick(at: t0.addingTimeInterval(1000))
        #expect(s.elapsed(at: t0.addingTimeInterval(1000)) == 40 && !s.timeUp)
        #expect(s.secondsLeft == 80)
        s.setRunning(true, at: t0.addingTimeInterval(1000))                                  // back
        s.tick(at: t0.addingTimeInterval(1010))
        #expect(s.secondsLeft == 70)
    }

    @Test("The gate unlocks when the time reaches zero, however the last tick lands")
    func sessionUnlocksAtZero() {
        let t0 = Date(timeIntervalSince1970: 4_000_000)
        // Ticks at exactly zero, past zero after a long gap, and a pause right at zero.
        for (offset, pauseFirst) in [(120.0, false), (500.0, false), (120.0, true)] {
            let s = ReadingSession(bookID: "ruth", chapter: 1)
            s.setText(text(words: 400), strictness: .standard, at: t0)                       // 120 s
            s.markReachedEnd(at: t0)
            s.setRunning(true, at: t0)
            s.tick(at: t0.addingTimeInterval(119.5))
            #expect(!s.canFinish && s.secondsLeft == 1)
            if pauseFirst { s.setRunning(false, at: t0.addingTimeInterval(offset)) } else { s.tick(at: t0.addingTimeInterval(offset)) }
            #expect(s.canFinish && s.timeUp && s.secondsLeft == 0 && s.progress == 1)
            #expect(s.secondsToNextTick(at: t0.addingTimeInterval(offset)) == 0)
            s.setRunning(false, at: t0.addingTimeInterval(offset + 1))
            #expect(s.canFinish)                                                             // stays unlocked
        }
        // Reaching the end after the time is up unlocks straight away.
        let late = ReadingSession(bookID: "ruth", chapter: 1)
        late.setText(text(words: 400), strictness: .standard, at: t0)
        late.setRunning(true, at: t0)
        late.tick(at: t0.addingTimeInterval(200))
        #expect(late.timeUp && !late.canFinish)
        late.markReachedEnd(at: t0.addingTimeInterval(201))
        #expect(late.canFinish)
        // After a read counts, a reread starts over.
        late.reset(at: t0.addingTimeInterval(202))
        #expect(!late.canFinish && late.secondsLeft == 120)
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

    @Test("Legacy questions are about real chapters and have one right answer")
    func questions() {
        for q in QuestionData.all {
            #expect(!q.reviewed)
            #expect(q.options.indices.contains(q.answer))
            #expect(Set(q.options).count == q.options.count)
            #expect(BibleCatalog.book(id: q.bookID).map { (1...$0.chapterCount).contains(q.chapter) } == true)
        }
        // Every chapter with bundled text has a question.
        for (book, chapters) in SampleText.chapters { for c in chapters { #expect(QuestionData.question(bookID: book, chapter: c.number) != nil, "\(book) \(c.number)") } }
        #expect(QuestionData.questions(bookID: "obadiah", chapter: 1).count == 8)
    }
}
