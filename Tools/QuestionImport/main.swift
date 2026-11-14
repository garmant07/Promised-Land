import Foundation

struct ParsedQuestion {
    let book: String
    let chapter: Int
    let format: String
    let prompt: String
    let options: [String]
    let answer: Int
    let lesson: String
    let difficulty: String
    let source: String
}

struct ImportReport {
    var questions: [ParsedQuestion] = []
    var chapters: [String: Set<Int>] = [:]
    var chapterCounts: [String: Int] = [:]
    var formats: [String: Int] = [:]
    var failures: [String] = []
    var warnings: [String] = []
    var unmapped: Set<String> = []
    var volumes: [(String, Int, Int)] = []
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("QuestionSource")
let textFiles = (try FileManager.default.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil))
    .filter { $0.pathExtension.lowercased() == "txt" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

let books: [(name: String, id: String)] = [
    ("Genesis", "genesis"), ("Exodus", "exodus"), ("Leviticus", "leviticus"), ("Numbers", "numbers"),
    ("Deuteronomy", "deuteronomy"), ("Joshua", "joshua"), ("Judges", "judges"), ("Ruth", "ruth"),
    ("1 Samuel", "1samuel"), ("2 Samuel", "2samuel"), ("1 Kings", "1kings"), ("2 Kings", "2kings"),
    ("1 Chronicles", "1chronicles"), ("2 Chronicles", "2chronicles"), ("Ezra", "ezra"), ("Nehemiah", "nehemiah"),
    ("Esther", "esther"), ("Job", "job"), ("Psalm", "psalms"), ("Psalms", "psalms"), ("Proverbs", "proverbs"),
    ("Ecclesiastes", "ecclesiastes"), ("Song of Solomon", "songofsongs"), ("Song of Songs", "songofsongs"),
    ("Isaiah", "isaiah"), ("Jeremiah", "jeremiah"), ("Lamentations", "lamentations"), ("Ezekiel", "ezekiel"),
    ("Daniel", "daniel"), ("Hosea", "hosea"), ("Joel", "joel"), ("Amos", "amos"), ("Obadiah", "obadiah"),
    ("Jonah", "jonah"), ("Micah", "micah"), ("Nahum", "nahum"), ("Habakkuk", "habakkuk"),
    ("Zephaniah", "zephaniah"), ("Haggai", "haggai"), ("Zechariah", "zechariah"), ("Malachi", "malachi"),
    ("Matthew", "matthew"), ("Mark", "mark"), ("Luke", "luke"), ("John", "john"), ("Acts", "acts"),
    ("Romans", "romans"), ("1 Corinthians", "1corinthians"), ("2 Corinthians", "2corinthians"),
    ("Galatians", "galatians"), ("Ephesians", "ephesians"), ("Philippians", "philippians"), ("Colossians", "colossians"),
    ("1 Thessalonians", "1thessalonians"), ("2 Thessalonians", "2thessalonians"), ("1 Timothy", "1timothy"),
    ("2 Timothy", "2timothy"), ("Titus", "titus"), ("Philemon", "philemon"), ("Hebrews", "hebrews"),
    ("James", "james"), ("1 Peter", "1peter"), ("2 Peter", "2peter"), ("1 John", "1john"), ("2 John", "2john"),
    ("3 John", "3john"), ("Jude", "jude"), ("Revelation", "revelation")
]

let bookMap = Dictionary(uniqueKeysWithValues: books.map { ($0.name, $0.id) })
let questionRegex = try! NSRegularExpression(pattern: #"^Q\d+\. (Multiple choice|True or false|Fill in the blank): (.*) (Easy|Medium|Hard)$"#)
let chapterRegex = try! NSRegularExpression(pattern: #"^(.+?) (\d+)$"#)
let optionRegex = try! NSRegularExpression(pattern: #"([A-D])\)\s+(.*?)(?=\s+[A-D]\)\s+|$)"#)

func cleaned(_ text: String) -> String {
    text.replacingOccurrences(of: #"\_"#, with: "_")
        .replacingOccurrences(of: #"\!"#, with: "!")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func match(_ regex: NSRegularExpression, _ line: String) -> [String]? {
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    guard let result = regex.firstMatch(in: line, range: range) else { return nil }
    return (0..<result.numberOfRanges).map { index in
        let valueRange = result.range(at: index)
        guard valueRange.location != NSNotFound, let swiftRange = Range(valueRange, in: line) else { return "" }
        return String(line[swiftRange])
    }
}

func answerAndLesson(_ answerLine: String) -> (String, String)? {
    guard answerLine.hasPrefix("Answer: ") else { return nil }
    let body = String(answerLine.dropFirst("Answer: ".count))
    guard let period = body.firstIndex(of: ".") else { return nil }
    let answer = String(body[..<period]).trimmingCharacters(in: .whitespaces)
    let restStart = body.index(after: period)
    let rest = body[restStart...].trimmingCharacters(in: .whitespaces)
    return (answer, rest)
}

func parseFile(_ url: URL, into report: inout ImportReport) {
    guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
        report.failures.append("\(url.lastPathComponent): unable to read as UTF-8")
        return
    }
    let lines = raw.components(separatedBy: .newlines).map(cleaned)
    var currentBook: String?
    var currentChapter: Int?
    var index = 0
    while index < lines.count {
        let line = lines[index]
        if let parts = match(chapterRegex, line), let chapter = Int(parts[2]), let bookID = bookMap[parts[1]] {
            currentBook = bookID
            currentChapter = chapter
            report.chapters[bookID, default: []].insert(chapter)
            index += 1
            continue
        } else if let parts = match(chapterRegex, line), Int(parts[2]) != nil, !line.hasPrefix("Q") {
            if !line.contains(" ") || parts[1].count < 2 { report.unmapped.insert(parts[1]) }
        }

        guard let qParts = match(questionRegex, line) else { index += 1; continue }
        guard let bookID = currentBook, let chapter = currentChapter else {
            report.failures.append("\(url.lastPathComponent):\(index + 1): \(line)")
            index += 1
            continue
        }
        let type = qParts[1]
        let prompt = cleaned(qParts[2]).replacingOccurrences(of: #"^True or false:\s*"#, with: "")
        let difficulty = qParts[3].lowercased()
        var options: [String] = []
        var answer = 0
        var lesson = ""
        var source = "\(url.lastPathComponent):\(index + 1)"
        var consumed = index

        if type == "Multiple choice" {
            guard index + 2 < lines.count, let optionParts = match(optionRegex, lines[index + 1]),
                  let answerParts = answerAndLesson(lines[index + 2]), answerParts.0.count == 1,
                  let answerValue = answerParts.0.first, ("A"..."D").contains(answerValue) else {
                report.failures.append("\(source): \(line)")
                index += 1
                continue
            }
            var optionIndex = 0
            while optionIndex < 4 {
                let marker = String(UnicodeScalar(65 + optionIndex)!)
                guard let markerRange = optionParts.firstIndex(of: marker) else { break }
                _ = markerRange
                optionIndex += 1
            }
            options = (0..<4).map { cleaned(optionParts[$0 + 2]) }
            answer = Int(answerValue.asciiValue! - Character("A").asciiValue!)
            let repeated = options[answer]
            let answerBody = String(lines[index + 2].dropFirst("Answer: ".count))
            let afterLetter = String(answerBody.dropFirst(3))
            let expectedPrefix = repeated + "."
            if afterLetter.hasPrefix(expectedPrefix) {
                lesson = String(afterLetter.dropFirst(expectedPrefix.count)).trimmingCharacters(in: .whitespaces)
            } else {
                lesson = afterLetter.trimmingCharacters(in: .whitespaces)
                report.warnings.append("\(source): repeated option does not exactly match option \(answerValue): \(lines[index + 2])")
            }
            consumed = index + 2
        } else if type == "True or false" {
            guard index + 1 < lines.count, let answerParts = answerAndLesson(lines[index + 1]),
                  answerParts.0 == "True" || answerParts.0 == "False" else {
                report.failures.append("\(source): \(line)")
                index += 1
                continue
            }
            options = ["True", "False"]
            answer = answerParts.0 == "True" ? 0 : 1
            lesson = answerParts.1
            consumed = index + 1
        } else {
            guard index + 1 < lines.count, let answerParts = answerAndLesson(lines[index + 1]) else {
                report.failures.append("\(source): \(line)")
                index += 1
                continue
            }
            let collapsedPrompt = prompt.replacingOccurrences(of: #"_{2,}(?:\s+_{2,})*"#, with: "____", options: .regularExpression)
            guard collapsedPrompt.components(separatedBy: "____").count == 2 else {
                report.failures.append("\(source): \(line)")
                index += 1
                continue
            }
            let answerText = answerParts.0.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            options = [answerText]
            answer = 0
            lesson = answerParts.1
            consumed = index + 1
        }

        let question = ParsedQuestion(book: bookID, chapter: chapter, format: type, prompt: type == "Fill in the blank" ? prompt.replacingOccurrences(of: #"_{2,}(?:\s+_{2,})*"#, with: "____", options: .regularExpression) : prompt, options: options, answer: answer, lesson: lesson, difficulty: difficulty, source: source)
        report.questions.append(question)
        report.formats[type, default: 0] += 1
        report.chapterCounts["\(bookID) \(chapter)", default: 0] += 1
        index = consumed + 1
    }
}

var report = ImportReport()
for file in textFiles { parseFile(file, into: &report) }

let oldFiles = textFiles.filter { $0.lastPathComponent.contains("Old Testament") }
let newFiles = textFiles.filter { $0.lastPathComponent.contains("New Testament") }
let oldQuestions = report.questions.filter { books.first { $0.id == $0.id } != nil && ["genesis", "malachi"].contains($0.book) == false }.count
_ = oldQuestions
let oldBookIDs = Set(books.prefix(39).map(\.id))
let newBookIDs = Set(books.suffix(27).map(\.id))
let oldCount = report.questions.filter { oldBookIDs.contains($0.book) }.count
let newCount = report.questions.filter { newBookIDs.contains($0.book) }.count
let oldChapters = Set(report.questions.filter { oldBookIDs.contains($0.book) }.map { "\($0.book) \($0.chapter)" }).count
let newChapters = Set(report.questions.filter { newBookIDs.contains($0.book) }.map { "\($0.book) \($0.chapter)" }).count

print("STAGE 0 QUESTION IMPORT DRY RUN")
print("Files: \(textFiles.count) text exports (\(oldFiles.count) OT, \(newFiles.count) NT)")
print("Old Testament: \(oldChapters) chapters, \(oldCount) questions; stated 929 chapters, 7432 questions")
print("New Testament: \(newChapters) chapters, \(newCount) questions; stated 431 chapters, 3448 questions")
print("Total: \(report.questions.count) questions")
print("Formats: \(report.formats.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")
let abnormal = report.chapterCounts.filter { $0.value != 8 }.sorted { $0.key < $1.key }
print("Chapters with count other than 8: \(abnormal.count)")
for item in abnormal { print("  \(item.key): \(item.value)") }
print("Parse failures: \(report.failures.count)")
for failure in report.failures.prefix(25) { print("  \(failure)") }
if report.failures.count > 25 { print("  ... plus \(report.failures.count - 25) more") }
print("Warnings: \(report.warnings.count)")
for warning in report.warnings.prefix(25) { print("  \(warning)") }
if report.warnings.count > 25 { print("  ... plus \(report.warnings.count - 25) more") }
print("Unmapped book names: \(report.unmapped.sorted().joined(separator: ", "))")
