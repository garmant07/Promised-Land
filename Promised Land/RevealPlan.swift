import CoreGraphics
import Foundation

/// One beat of the "see it built" moment: the camera glides to a Place, the new piece rises
/// (or a field or village spreads), and a caption says what the chapter built.
struct RevealStep: Equatable, Identifiable {
    enum Kind: Equatable { case found, grow, complete, combined }

    /// An island item changing during this step: its growth goes from `from` to `to`
    /// (0 = not there yet, so it pops up; otherwise it spreads).
    struct Change: Equatable {
        let index: Int
        let from: CGFloat
        let to: CGFloat
    }

    let id: String
    let bookID: String
    let kind: Kind
    /// "Ruth 2: the barn is built".
    let caption: String
    /// "The Farmstead · 2 of 4 chapters".
    let progressLabel: String
    let progress: Double
    let changes: [Change]
    /// The item the camera looks at and the sparkles burst from.
    let focus: Int

    /// Seconds this beat lasts (founding and completing are a little bigger).
    var duration: Double {
        switch kind {
        case .grow: 2.8
        case .found, .complete: 3.4
        case .combined: 3.4
        }
    }
}

/// Works out the reveal after reading. Pure, so it's testable.
enum RevealPlanner {
    /// More than this many chapters at once play as one combined reveal.
    static let maxSequence = 3

    /// - Parameters:
    ///   - island: the island as it is now (with the new chapters built).
    ///   - before: distinct chapters per book when the island was last seen.
    ///   - chapterOrder: each book's distinct (checked) chapters, in the order first read.
    /// - Returns: the beats to play, and the growth every changing item should show before they start.
    static func plan(island: Island, before: [String: Int], chapterOrder: [String: [Int]]) -> (steps: [RevealStep], initial: [Int: CGFloat]) {
        var raw: [(book: String, step: Int)] = []
        for (bookID, growth) in island.growth.sorted(by: { $0.key < $1.key }) where growth.isFounded {
            let now = chapterOrder[bookID]?.count ?? 0
            let old = before[bookID] ?? 0
            guard now > old else { continue }
            for k in (old + 1)...now { raw.append((bookID, k)) }
        }
        guard !raw.isEmpty else { return ([], [:]) }
        // Steps play book by book, each book's chapters in the order they were read.
        var initial: [Int: CGFloat] = [:]
        for book in Set(raw.map(\.book)) {
            let first = raw.filter { $0.book == book }.map(\.step).min()!
            for change in changes(island: island, bookID: book, from: first - 1, to: chapterOrder[book]?.count ?? 0) {
                initial[change.index] = change.from
            }
        }
        if raw.count > maxSequence {
            return ([combined(island: island, raw: raw, chapterOrder: chapterOrder)], initial)
        }
        let steps = raw.compactMap { step(island: island, bookID: $0.book, k: $0.step, chapterOrder: chapterOrder) }
        return (steps, initial)
    }

    private static func step(island: Island, bookID: String, k: Int, chapterOrder: [String: [Int]]) -> RevealStep? {
        guard let book = BibleCatalog.book(id: bookID) else { return nil }
        let spec = PlaceData.spec(for: bookID)
        let after = PlaceGrowth.after(k, spec: spec, chapters: book.chapterCount)
        let diff = changes(island: island, bookID: bookID, from: k - 1, to: k)
        let arriving: Int? = diff.first(where: { $0.from == 0 })?.index
        let growing: Int? = diff.first?.index
        guard let focus = arriving ?? growing ?? island.placeIndex(bookID) else { return nil }
        let chapter = chapterOrder[bookID].flatMap { k - 1 < $0.count ? $0[k - 1] : nil } ?? k
        let what: String
        if after.lastPieces.isEmpty {
            what = "flowers bloom across \(spec.name)"
        } else if after.lastPieces.allSatisfy({ (PlaceGrowth.after(k - 1, spec: spec, chapters: book.chapterCount).pieces[$0]) == nil }) {
            what = after.lastPieces.map { spec.pieces[$0].caption }.joined(separator: ", and ")
        } else {
            what = after.lastPieces.map { spec.pieces[$0].growCaption ?? spec.pieces[$0].caption }.joined(separator: ", and ")
        }
        let kind: RevealStep.Kind = k == 1 ? .found : k == book.chapterCount ? .complete : .grow
        let caption = ContentGate.isVisible(spec) ? "\(book.name) \(chapter): \(what)" : "\(book.name) \(chapter): \(spec.name) grows"
        return RevealStep(id: "\(bookID)-\(k)", bookID: bookID, kind: kind, caption: caption,
                          progressLabel: "\(spec.name) · \(k) of \(book.chapterCount) \(book.chapterCount == 1 ? "chapter" : "chapters")",
                          progress: Double(k) / Double(book.chapterCount), changes: diff, focus: focus)
    }

    private static func combined(island: Island, raw: [(book: String, step: Int)], chapterOrder: [String: [Int]]) -> RevealStep {
        var all: [RevealStep.Change] = []
        let books = Array(Set(raw.map(\.book))).sorted()
        for book in books {
            let first = raw.filter { $0.book == book }.map(\.step).min()!
            all += changes(island: island, bookID: book, from: first - 1, to: chapterOrder[book]?.count ?? 0)
        }
        // Focus on the Place that grew the most.
        let main = books.max { a, b in raw.filter { $0.book == a }.count < raw.filter { $0.book == b }.count }!
        let book = BibleCatalog.book(id: main)
        let k = chapterOrder[main]?.count ?? 0
        let n = book?.chapterCount ?? 1
        let spec = PlaceData.spec(for: main)
        let focus = all.first { island.items.indices.contains($0.index) && island.items[$0.index].source.bookID == main }?.index
            ?? island.placeIndex(main) ?? 0
        let places = books.count == 1 ? spec.name : "\(books.count) Places"
        return RevealStep(id: "combined-\(raw.count)-\(main)", bookID: main, kind: .combined,
                          caption: "\(raw.count) chapters built: \(places) grew", progressLabel: "\(spec.name) · \(k) of \(n) chapters",
                          progress: Double(k) / Double(n), changes: all, focus: focus)
    }

    /// The items of a book's Place whose growth differs between `from` and `to` chapters read.
    static func changes(island: Island, bookID: String, from a: Int, to b: Int) -> [RevealStep.Change] {
        guard let book = BibleCatalog.book(id: bookID) else { return [] }
        let spec = PlaceData.spec(for: bookID)
        let old = PlaceGrowth.after(max(0, a), spec: spec, chapters: book.chapterCount)
        let new = PlaceGrowth.after(b, spec: spec, chapters: book.chapterCount)
        var out: [RevealStep.Change] = []
        for (index, item) in island.items.enumerated() {
            switch item.source {
            case .place(bookID, let piece):
                let f = CGFloat(old.pieces[piece] ?? 0), t = CGFloat(new.pieces[piece] ?? 0)
                if f != t { out.append(.init(index: index, from: f, to: t)) }
            case .flourish(bookID):
                let f = CGFloat(min(PlaceGrowth.flourishCap, old.flourish)), t = CGFloat(min(PlaceGrowth.flourishCap, new.flourish))
                if f != t { out.append(.init(index: index, from: f, to: t)) }
            default:
                continue
            }
        }
        return out
    }
}
