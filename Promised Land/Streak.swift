import SwiftUI

/// Reading streak, derived from the dates of `ChapterRead` records (nothing extra is stored).
enum Streak {
    /// Consecutive days with at least one chapter read, ending today — or yesterday,
    /// so the streak doesn't look broken before the user has read today.
    static func days(from dates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        guard var day = days.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today),
              days.contains(day) else { return 0 }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}

struct StreakPill: View {
    let days: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .foregroundStyle(days > 0 ? Color.terracotta : Color.secondaryText.opacity(0.5))
            Text("\(days)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.bodyText)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color.card, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reading streak: \(days) \(days == 1 ? "day" : "days")")
    }
}

#Preview {
    HStack { StreakPill(days: 0); StreakPill(days: 7) }
        .padding()
        .background(Color.cream)
}

extension Streak {
    /// The longest run of consecutive reading days ever.
    static func longest(from dates: [Date], calendar: Calendar = .current) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in days {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day { run += 1 } else { run = 1 }
            best = max(best, run)
            previous = day
        }
        return best
    }
}
