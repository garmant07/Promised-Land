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

    /// Giving bread and fish together to the crowd is the "feeding the crowd" moment.
    static func isFeedingTheCrowd(_ gift: [ProduceKind: Int]) -> Bool {
        (gift[.bread] ?? 0) > 0 && (gift[.fish] ?? 0) > 0
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

    /// Gives produce away ("crowd", or "friend:<id>" to keep for a friend's island).
    func giveProduce(_ gift: [ProduceKind: Int], to recipient: String, date: Date = .now) {
        for (kind, amount) in gift where amount > 0 {
            insert(ProduceGift(kind: kind, amount: amount, recipient: recipient, date: date))
        }
        try? save()
    }
}
