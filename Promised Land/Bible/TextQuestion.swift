import Foundation

/// A quick question made from a chapter's own text when it has no hand-written one: a verse with
/// one word missing, and three words to choose from (the missing one and two others from the
/// same chapter). Only text already on the device is used (cached or bundled). The same chapter
/// always gets the same question.
enum TextQuestion {
    static let blank = "_____"

    static func make(from text: ChapterText, bookName: String) -> ChapterQuestion? {
        let seed = stableSeed("\(text.bookID).\(text.chapter)")
        // Verses long enough to make a fair question.
        let candidates = text.verses.filter { words($0.text).count >= 8 }
        guard !candidates.isEmpty else { return nil }
        let verse = candidates[seed % candidates.count]

        // The answer: the longest distinctive word in the verse.
        let tokens = words(verse.text)
        guard let answer = tokens.filter({ isDistinctive($0) }).max(by: { $0.count < $1.count }) else { return nil }

        // Two other distinctive words from the rest of the chapter, closest in length.
        var seen: Set<String> = [answer.lowercased()]
        var others: [String] = []
        for v in text.verses where v.number != verse.number {
            for w in words(v.text) where isDistinctive(w) && seen.insert(w.lowercased()).inserted { others.append(w) }
        }
        let distractors = others.sorted { (abs($0.count - answer.count), $0) < (abs($1.count - answer.count), $1) }.prefix(2)
        guard distractors.count == 2 else { return nil }

        // The answer's place among the options moves from chapter to chapter.
        var options = Array(distractors)
        let index = seed % 3
        options.insert(answer, at: index)

        guard let range = verse.text.range(of: answer) else { return nil }
        let clue = verse.text.replacingCharacters(in: range, with: blank)
        return ChapterQuestion(bookID: text.bookID, chapter: text.chapter,
                               prompt: "Which word is missing? \u{201C}\(clue)\u{201D}",
                               options: options, answer: index,
                               reference: "\(bookName) \(text.chapter):\(verse.number)",
                               translation: text.translation,
                               // Made mechanically from the Bible text itself, so there's nothing to review.
                               reviewed: true)
    }

    /// Words with their punctuation trimmed.
    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: .punctuationCharacters.union(.symbols)) }
            .filter { !$0.isEmpty }
    }

    /// Long enough, only letters, and not a little everyday word.
    static func isDistinctive(_ word: String) -> Bool {
        word.count >= 5 && word.allSatisfy(\.isLetter) && !common.contains(word.lowercased())
    }

    static let common: Set<String> = ["there", "their", "which", "would", "could", "should", "these", "those", "about", "after",
                                      "again", "where", "while", "shall", "unto", "every", "other", "being", "before", "because",
                                      "through", "against", "said", "saying", "thing", "things", "never", "whose", "whom",
                                      "might", "until", "under", "above", "among", "always", "rather", "behold", "therefore"]

    /// The same number for the same text on every launch (unlike `Hasher`).
    static func stableSeed(_ s: String) -> Int {
        var h: UInt64 = 5381
        for b in s.utf8 { h = (h &* 33) &+ UInt64(b) }
        return Int(h % 1_000_003)
    }
}
