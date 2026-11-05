import Foundation

/// Reads a book and chapter from the text on a photo of a Bible page: running headers such as
/// "JOHN 15", "John 15:1", "1 Samuel 17", "I SAMUEL 17:12–30", "Ps. 23" or "SONG OF SOLOMON 2".
/// Pure, so it's testable; the text itself comes from Apple's on-device Vision recognition.
enum ChapterDetector {
    struct Match: Equatable {
        let bookID: String
        let chapter: Int
    }

    /// The most likely chapter in some recognised lines (headers first: lines nearer the top win).
    static func detect(_ lines: [String]) -> Match? {
        for (i, line) in lines.enumerated() {
            if let m = parse(line) { return m }
            // A book name on its own line, with the chapter number on the next line.
            if let book = bookOnly(line) {
                if let next = lines.dropFirst(i + 1).prefix(2).compactMap({ Int($0.trimmingCharacters(in: .whitespaces)) }).first,
                   let b = BibleCatalog.book(id: book), (1...b.chapterCount).contains(next) {
                    return Match(bookID: book, chapter: next)
                }
                if BibleCatalog.book(id: book)?.chapterCount == 1 { return Match(bookID: book, chapter: 1) }
            }
        }
        return nil
    }

    /// One line: a book name followed by a chapter (and maybe a verse).
    static func parse(_ line: String) -> Match? {
        let words = tokens(line)
        guard !words.isEmpty else { return nil }
        // Try every start position, longest names first.
        for start in words.indices {
            for length in stride(from: min(4, words.count - start), through: 1, by: -1) {
                let name = words[start..<(start + length)].joined(separator: " ")
                guard let book = aliases[name] else { continue }
                let rest = words.dropFirst(start + length)
                if let chapter = rest.first.flatMap({ chapterNumber($0) }), let b = BibleCatalog.book(id: book), (1...b.chapterCount).contains(chapter) {
                    return Match(bookID: book, chapter: chapter)
                }
            }
        }
        return nil
    }

    /// A line that's just a book's name ("JUDE", "THE PSALMS").
    private static func bookOnly(_ line: String) -> String? {
        let words = tokens(line).filter { $0 != "THE" }
        return aliases[words.joined(separator: " ")]
    }

    /// "15", "15:1", "15:1-8" → 15.
    private static func chapterNumber(_ token: String) -> Int? {
        let digits = token.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 3 else { return nil }
        return Int(digits)
    }

    /// Upper-cased words, with numbers kept together ("15:1–8") and stray punctuation removed.
    static func tokens(_ line: String) -> [String] {
        let cleaned = line.uppercased()
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        var words = cleaned.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        // "1SAMUEL" → "1 SAMUEL", "JOHN15:1" → "JOHN 15:1".
        words = words.flatMap { word -> [String] in
            if let i = word.firstIndex(where: { $0.isLetter }), i != word.startIndex, word[..<i].allSatisfy(\.isNumber) {
                return [String(word[..<i]), String(word[i...])]
            }
            if let i = word.firstIndex(where: { $0.isNumber }), i != word.startIndex, word[..<i].allSatisfy(\.isLetter) {
                return [String(word[..<i]), String(word[i...])]
            }
            return [word]
        }
        // Ordinals: "I", "II", "III", "FIRST", "1ST" → "1", "2", "3".
        let ordinals = ["I": "1", "II": "2", "III": "3", "FIRST": "1", "SECOND": "2", "THIRD": "3", "1ST": "1", "2ND": "2", "3RD": "3"]
        return words.enumerated().map { i, w in
            // Only as a prefix to a book name, so "I" in a sentence isn't changed into a number.
            if let n = ordinals[w], i + 1 < words.count, words[i + 1].first?.isLetter == true { return n }
            return w
        }
    }

    /// Every name and common abbreviation, upper-cased, to a book id.
    static let aliases: [String: String] = {
        var out: [String: String] = [:]
        for book in BibleCatalog.books { out[book.name.uppercased()] = book.id }
        let extra: [String: [String]] = [
            "genesis": ["GEN", "GN"], "exodus": ["EXOD", "EX", "EXO"], "leviticus": ["LEV", "LV"], "numbers": ["NUM", "NUMB", "NM"],
            "deuteronomy": ["DEUT", "DT"], "joshua": ["JOSH", "JOS"], "judges": ["JUDG", "JDG"], "ruth": ["RU", "RTH"],
            "1samuel": ["1 SAM", "1 SA"], "2samuel": ["2 SAM", "2 SA"], "1kings": ["1 KGS", "1 KINGS", "1 KI"], "2kings": ["2 KGS", "2 KI"],
            "1chronicles": ["1 CHRON", "1 CHR"], "2chronicles": ["2 CHRON", "2 CHR"], "nehemiah": ["NEH"], "esther": ["ESTH", "EST"],
            "psalms": ["PSALM", "PS", "PSA", "PSS"], "proverbs": ["PROV", "PRV"], "ecclesiastes": ["ECCL", "ECC", "ECCLES", "QOHELETH"],
            "songofsongs": ["SONG OF SOLOMON", "SONG", "SOS", "CANTICLES", "SONG OF SONGS"], "isaiah": ["ISA"],
            "jeremiah": ["JER"], "lamentations": ["LAM"], "ezekiel": ["EZEK", "EZK"], "daniel": ["DAN", "DN"], "hosea": ["HOS"],
            "obadiah": ["OBAD"], "micah": ["MIC"], "nahum": ["NAH"], "habakkuk": ["HAB"], "zephaniah": ["ZEPH"], "haggai": ["HAG"],
            "zechariah": ["ZECH"], "malachi": ["MAL"], "matthew": ["MATT", "MT"], "mark": ["MK", "MRK"], "luke": ["LK", "LUK"],
            "john": ["JN", "JHN"], "acts": ["ACTS OF THE APOSTLES", "THE ACTS"], "romans": ["ROM", "RM"],
            "1corinthians": ["1 COR"], "2corinthians": ["2 COR"], "galatians": ["GAL"], "ephesians": ["EPH"], "philippians": ["PHIL", "PHP"],
            "colossians": ["COL"], "1thessalonians": ["1 THESS", "1 TH"], "2thessalonians": ["2 THESS", "2 TH"], "1timothy": ["1 TIM"],
            "2timothy": ["2 TIM"], "titus": ["TIT"], "philemon": ["PHLM", "PHILEM"], "hebrews": ["HEB"], "james": ["JAS", "JAM"],
            "1peter": ["1 PET", "1 PT"], "2peter": ["2 PET", "2 PT"], "1john": ["1 JN", "1 JOHN"], "2john": ["2 JN"], "3john": ["3 JN"],
            "revelation": ["REV", "REVELATIONS", "THE REVELATION", "APOCALYPSE"],
        ]
        for (id, names) in extra { for n in names { out[n] = id } }
        return out
    }()
}
