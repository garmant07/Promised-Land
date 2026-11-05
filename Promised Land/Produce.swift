import Foundation
import SwiftData

/// Gentle produce: a complete Place yields one of its produce (fish, bread, grapes…) for each day
/// you read, from the day it was completed, up to a small cap. Nothing builds up on days without
/// reading, so it never becomes a chore. Pure, so it's testable.
enum ProduceRules {
    /// At most this many wait in a Place's basket.
    static let cap = 3

    /// The days (start of day) with at least one read.
    static func readingDays(_ dates: [Date], calendar: Calendar = .current) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }

    /// What waits in a Place's basket.
    /// - Parameters:
    ///   - completed: when the Place was completed (nil = not complete: nothing grows).
    ///   - lastCollected: when its basket was last emptied.
    static func ready(completed: Date?, lastCollected: Date?, readingDays: Set<Date>, calendar: Calendar = .current) -> Int {
        guard let completed else { return 0 }
        let from = calendar.startOfDay(for: completed)
        let after = lastCollected.map { calendar.startOfDay(for: $0) }
        let days = readingDays.filter { day in day >= from && (after.map { day > $0 } ?? true) }
        return min(cap, days.count)
    }

    /// What you have to give: everything collected, less everything given.
    static func inventory(collected: [(kind: ProduceKind, amount: Int)], given: [(kind: ProduceKind, amount: Int)]) -> [ProduceKind: Int] {
        var out: [ProduceKind: Int] = [:]
        for c in collected { out[c.kind, default: 0] += c.amount }
        for g in given { out[g.kind, default: 0] -= g.amount }
        return out.filter { $0.value > 0 }
    }

    /// What waits in every complete Place's basket (books with nothing waiting are left out).
    /// - Parameters:
    ///   - completed: when each complete Place was completed (`Island.completed`).
    ///   - readDates: the dates of checked reads (only those count as reading days).
    ///   - collections: every past collection, as (book, date).
    static func baskets(completed: [String: Date], readDates: [Date], collections: [(bookID: String, date: Date)],
                        calendar: Calendar = .current) -> [String: Int] {
        guard !completed.isEmpty else { return [:] }
        let days = readingDays(readDates, calendar: calendar)
        let last = Dictionary(collections.map { ($0.bookID, $0.date) }, uniquingKeysWith: max)
        var out: [String: Int] = [:]
        for (bookID, done) in completed {
            let n = ready(completed: done, lastCollected: last[bookID], readingDays: days, calendar: calendar)
            if n > 0 { out[bookID] = n }
        }
        return out
    }

    /// Giving bread and fish together to the crowd is the "feeding the crowd" moment.
    static func isFeedingTheCrowd(_ gift: [ProduceKind: Int]) -> Bool {
        (gift[.bread] ?? 0) > 0 && (gift[.fish] ?? 0) > 0
    }
}

/// Collect All: empties every basket on the island in one go. Pure, so it's testable.
enum CollectAll {
    struct Entry: Equatable {
        let bookID: String
        let kind: ProduceKind
        let amount: Int
    }

    /// One entry per Place with something waiting (in a stable order), and the totals by kind.
    static func plan(_ baskets: [String: Int], kind: (String) -> ProduceKind = { PlaceData.spec(for: $0).produce })
        -> (entries: [Entry], totals: [ProduceKind: Int]) {
        let entries = baskets.filter { $0.value > 0 }.sorted { $0.key < $1.key }
            .map { Entry(bookID: $0.key, kind: kind($0.key), amount: $0.value) }
        var totals: [ProduceKind: Int] = [:]
        for e in entries { totals[e.kind, default: 0] += e.amount }
        return (entries, totals)
    }

    /// "+3 fish, +2 bread, +1 grapes": most first, then in the produce's own order.
    static func summary(_ totals: [ProduceKind: Int]) -> String {
        let order = Dictionary(uniqueKeysWithValues: ProduceKind.allCases.enumerated().map { ($1, $0) })
        return totals.filter { $0.value > 0 }
            .sorted { ($1.value, order[$0.key] ?? 0) < ($0.value, order[$1.key] ?? 0) }
            .map { "+\($0.value) \($0.key.name.lowercased())" }
            .joined(separator: ", ")
    }

    /// The button shows only when something is ready and nothing else is going on.
    static func isButtonVisible(total: Int, editing: Bool, revealing: Bool, sheetOpen: Bool) -> Bool {
        total > 0 && !editing && !revealing && !sheetOpen
    }

    /// "Collect all, 6 items ready".
    static func accessibilityLabel(total: Int) -> String {
        "Collect all, \(total) \(total == 1 ? "item" : "items") ready"
    }
}

/// The words shown with the "feeding the crowd" moment. Content: unreviewed (see REVIEW.md).
struct FeedingTheCrowd: ReviewableContent {
    let quote = "There is a lad here, who hath five barley loaves, and two fishes: but what are these among so many?"
    let reference = "John 6:9"
    let source = "John 6:9 (ASV); the feeding of the crowd is told in Matthew 14:13–21, Mark 6:30–44, Luke 9:10–17 and John 6:1–14"
    let reviewed = false

    static let entry = FeedingTheCrowd()
}

extension ModelContext {
    /// Empties a Place's basket into your store of produce.
    func collectProduce(_ bookID: String, kind: ProduceKind, amount: Int, date: Date = .now) {
        guard amount > 0 else { return }
        insert(ProduceCollection(bookID: bookID, kind: kind, amount: amount, date: date))
        try? save()
    }

    /// Empties every basket at once (one save). Returns what was collected, by kind.
    @discardableResult
    func collectAllProduce(_ baskets: [String: Int], date: Date = .now) -> [ProduceKind: Int] {
        let plan = CollectAll.plan(baskets)
        guard !plan.entries.isEmpty else { return [:] }
        for e in plan.entries { insert(ProduceCollection(bookID: e.bookID, kind: e.kind, amount: e.amount, date: date)) }
        try? save()
        return plan.totals
    }

    /// Gives produce away ("crowd", or "friend:<id>" to keep for a friend's island).
    func giveProduce(_ gift: [ProduceKind: Int], to recipient: String, date: Date = .now) {
        for (kind, amount) in gift where amount > 0 {
            insert(ProduceGift(kind: kind, amount: amount, recipient: recipient, date: date))
        }
        try? save()
    }
}
