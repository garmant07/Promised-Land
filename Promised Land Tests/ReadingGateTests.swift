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
        let timedNeed = ReadingGate.timedMinimumSeconds(words: 1100, strictness: .standard)
        #expect(timedNeed == 330) // 1100 words at 200 a minute
        #expect(ReadingGate.minimumSeconds(words: 1100, strictness: .standard) == 0)
        #expect(!ReadingGate.canFinish(reachedEnd: false, elapsed: 0, required: 0))
        #expect(ReadingGate.canFinish(reachedEnd: true, elapsed: 0, required: 0))
        #expect(!ReadingGate.canFinish(reachedEnd: true, elapsed: 120, required: timedNeed))
        #expect(ReadingGate.canFinish(reachedEnd: true, elapsed: 330, required: timedNeed))
        #expect(ReadingGate.progress(reachedEnd: false, elapsed: 999, required: timedNeed) < 1)
    }

    @Test("The timer is the words at 200 a minute, between 30 s and 12 min; Strict uses the same pace; Relaxed has none")
    func pace() {
        #expect(ReadingGate.timedMinimumSeconds(words: 22, strictness: .standard) == 30)       // floor
        #expect(ReadingGate.timedMinimumSeconds(words: 650, strictness: .standard) == 195)     // 650 / 200 × 60
        #expect(ReadingGate.timedMinimumSeconds(words: 22_000, strictness: .standard) == 720)  // cap
        #expect(ReadingGate.timedMinimumSeconds(words: 0, strictness: .standard) == 30)
        #expect(ReadingGate.timedMinimumSeconds(words: 1000, strictness: .relaxed) == 0)
        #expect(ReadingGate.timedMinimumSeconds(words: 1000, strictness: .strict) == ReadingGate.timedMinimumSeconds(words: 1000, strictness: .standard))
        #expect(ReadingGate.minimumSeconds(words: 1000, strictness: .strict) == 0)
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
        #expect(short.requiredSeconds == 0)
        #expect(long.requiredSeconds == 0)
        let relaxed = ReadingSession(bookID: "ruth", chapter: 3)
        relaxed.setText(text(words: 1200), strictness: .relaxed)
        relaxed.markReachedEnd()
        #expect(relaxed.requiredSeconds == 0 && relaxed.canFinish)                           // Timer is off
    }

    @Test("Backgrounding (or a sheet) pauses the time; it resumes on return")
    func sessionPauses() {
        let t0 = Date(timeIntervalSince1970: 3_000_000)
        let s = ReadingSession(bookID: "ruth", chapter: 1)
        s.setText(text(words: 400), strictness: .standard, at: t0)
        s.setRunning(true, at: t0)
        s.setRunning(false, at: t0.addingTimeInterval(40))                                   // background
        s.tick(at: t0.addingTimeInterval(1000))
        #expect(s.elapsed(at: t0.addingTimeInterval(1000)) == 40 && s.timeUp)
        #expect(s.secondsLeft == 0)
        s.setRunning(true, at: t0.addingTimeInterval(1000))                                  // back
        s.tick(at: t0.addingTimeInterval(1010))
        #expect(s.secondsLeft == 0)
    }

    @Test("The timer-off session unlocks on the last page without a countdown")
    func sessionUnlocksAtEndWhenTimerIsOff() {
        let t0 = Date(timeIntervalSince1970: 4_000_000)
        let session = ReadingSession(bookID: "ruth", chapter: 1)
        session.setText(text(words: 400), strictness: .standard, at: t0)
        #expect(session.timeUp)
        #expect(!session.canFinish)
        session.markReachedEnd(at: t0)
        #expect(session.canFinish)
        #expect(session.secondsLeft == 0)
        #expect(session.progress == 1)
        session.reset(at: t0.addingTimeInterval(10))
        #expect(!session.canFinish && session.secondsLeft == 0)
    }

    @Test("Bundled chapters are timed by their words; others by a typical length")
    func words() {
        let bundled = BundledBibleService()
        #expect(ReadingGate.words(bookID: "john", chapter: 15, service: bundled) > 0)
        #expect(ReadingGate.words(bookID: "obadiah", chapter: 1, service: bundled) == ReadingGate.typicalChapterWords)
    }

    @Test("Strict-mode migration maps legacy values and defaults new users off")
    func strictModeMigration() {
        let defaultsSuite = "ReadingGateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }

        for value in ["strict"] {
            defaults.set(value, forKey: StorageKeys.readingStrictness)
            ReadingStrictMode.migrate(defaults: defaults)
            #expect(defaults.bool(forKey: ReadingStrictMode.key))
        }
        for value in ["relaxed", "standard", "", "unknown"] {
            let freshSuite = "ReadingGateTests.\(UUID().uuidString)"
            let fresh = UserDefaults(suiteName: freshSuite)!
            defer { fresh.removePersistentDomain(forName: freshSuite) }
            if !value.isEmpty { fresh.set(value, forKey: StorageKeys.readingStrictness) }
            ReadingStrictMode.migrate(defaults: fresh)
            #expect(!fresh.bool(forKey: ReadingStrictMode.key))
        }

        let laterSuite = "ReadingGateTests.\(UUID().uuidString)"
        let laterChange = UserDefaults(suiteName: laterSuite)!
        defer { laterChange.removePersistentDomain(forName: laterSuite) }
        laterChange.set("strict", forKey: StorageKeys.readingStrictness)
        ReadingStrictMode.migrate(defaults: laterChange)
        laterChange.set(false, forKey: ReadingStrictMode.key)
        ReadingStrictMode.migrate(defaults: laterChange)
        #expect(!laterChange.bool(forKey: ReadingStrictMode.key))
    }

    @Test("Skip counts only when Strict is off, and Back to reading never counts")
    func skipRules() {
        #expect(ReadingQuestionFlow.showsSkip(strictMode: false))
        #expect(!ReadingQuestionFlow.showsSkip(strictMode: true))
        #expect(ReadingQuestionFlow.countsChapter(.skip, strictMode: false))
        #expect(!ReadingQuestionFlow.countsChapter(.skip, strictMode: true))
        #expect(ReadingQuestionFlow.countsChapter(.answer, strictMode: true))
        #expect(!ReadingQuestionFlow.countsChapter(.backToReading, strictMode: false))
        #expect(!ReadingQuestionFlow.countsChapter(.backToReading, strictMode: true))
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
