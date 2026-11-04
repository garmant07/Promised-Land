import SwiftUI

/// Biblical, historical or geographical content that must be checked before it ships.
///
/// Every entry carries where it comes from and whether a person has reviewed it.
/// Release builds only ever show reviewed entries; Debug builds show everything,
/// marking unreviewed entries with a small "Draft" badge.
protocol ReviewableContent {
    /// Book / chapter / verse the entry is about, e.g. "John 15:1–8".
    var reference: String { get }
    /// Where the fact comes from, e.g. "John 15 (ASV)".
    var source: String { get }
    /// Set to true only after a person has checked the entry.
    var reviewed: Bool { get }
}

enum ContentGate {
    /// Whether unreviewed (draft) content may be shown in this build.
    static var showsDrafts: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static func isVisible(_ item: some ReviewableContent) -> Bool {
        item.reviewed || showsDrafts
    }

    static func visible<T: ReviewableContent>(_ items: [T]) -> [T] {
        items.filter { isVisible($0) }
    }
}

/// Small badge shown next to unreviewed content in Debug builds.
struct DraftBadge: View {
    let item: any ReviewableContent

    var body: some View {
        if !item.reviewed {
            Text("Draft")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.onPrimary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.terracotta, in: Capsule())
                .accessibilityLabel("Draft content, not yet reviewed")
        }
    }
}
