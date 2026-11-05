import SwiftUI

/// Something new on your island worth telling you about.
struct UnlockNotice: Identifiable, Equatable {
    /// Stable key, so each unlock is announced once.
    let id: String
    let title: String
    let detail: String
    let symbol: String
    /// The island item to show when you tap "See it", if there is one.
    var itemIndex: Int?
}

/// Works out what's been unlocked. Pure, so it's testable: compare against the keys already
/// announced to find what's new.
enum UnlockNotices {
    /// - Parameter crowns: crowns earned per book (each full reread after the first).
    static func all(island: Island, completedJourneys: [Journey], crowns: [String: Int] = [:]) -> [UnlockNotice] {
        var out: [UnlockNotice] = []
        for (bookID, count) in crowns.sorted(by: { $0.key < $1.key }) where count > 0 {
            let name = BibleCatalog.book(id: bookID)?.name ?? bookID
            for n in 1...count {
                out.append(UnlockNotice(id: "crown:\(bookID):\(n)", title: "A crown for \(name)",
                                        detail: "You read \(name) all the way through again.", symbol: "crown.fill",
                                        itemIndex: island.placeIndex(bookID)))
            }
        }
        // Each Place: founded, completed, and each richer level from rereads.
        for (bookID, growth) in island.growth.sorted(by: { $0.key < $1.key }) where growth.isFounded {
            guard let book = BibleCatalog.book(id: bookID), let index = island.placeIndex(bookID) else { continue }
            let item = island.items[index]
            let name = PlaceData.spec(for: bookID).name
            if item.progress >= item.total {
                out.append(UnlockNotice(id: "built:\(bookID)", title: "\(name) is complete",
                                        detail: "You finished \(book.name). Villagers are moving in.",
                                        symbol: "building.columns.fill", itemIndex: index))
                if item.level >= 2 {
                    for level in 2...item.level {
                        out.append(UnlockNotice(id: "floor:\(bookID):\(level)", title: "\(name) grows richer",
                                                detail: "You read \(book.name) through again (richness \(level) of 5).",
                                                symbol: "sparkles", itemIndex: index))
                    }
                }
            }
        }
        for (index, item) in island.items.enumerated() {
            switch item.kind {
            case .reward(let kind):
                guard let bookID = item.source.bookID, let book = BibleCatalog.book(id: bookID) else { continue }
                let (title, detail, symbol): (String, String, String) = switch kind {
                case .banner: ("A banner for \(book.name)", "You passed the \(book.name) quiz.", "flag.fill")
                case .lantern: ("A lantern is lit", "You memorised a verse from \(book.name).", "lamp.desk.fill")
                case .fruitTree: ("A fruit tree grew", "You memorised a verse from \(book.name).", "leaf.fill")
                }
                out.append(UnlockNotice(id: "reward:\(bookID):\(kind.rawValue)", title: title, detail: detail,
                                        symbol: symbol, itemIndex: index))
            case .throne:
                out.append(UnlockNotice(id: "throne", title: "The throne room has appeared",
                                        detail: "You've read the whole Bible. Walk in to lay down your crowns.",
                                        symbol: "crown.fill", itemIndex: index))
            case .library:
                out.append(UnlockNotice(id: "library", title: "The Library is open",
                                        detail: "Every book of the Bible is on its shelves. Walk in to read.",
                                        symbol: "books.vertical.fill", itemIndex: index))
            default:
                continue // growth itself is shown by the "see it built" moment
            }
        }
        if let forest = island.index(of: .forest) ?? island.items.firstIndex(where: { $0.kind == .tree }) {
            out.append(UnlockNotice(id: "forest", title: "A forest begins", detail: "Chapters with trees in them grow a forest at the island's edge.",
                                    symbol: "tree.fill", itemIndex: forest))
        }
        for journey in completedJourneys {
            out.append(UnlockNotice(id: "journey:\(journey.id)", title: "\(journey.name) complete",
                                    detail: "Every stop is lit. Its badge is yours.", symbol: "map.fill"))
        }
        return out
    }
}

/// The banner at the top of the island announcing an unlock.
struct UnlockBanner: View {
    let notice: UnlockNotice
    /// How many more are waiting after this one.
    var more = 0
    var onSee: (() -> Void)?
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notice.symbol)
                .font(.title3)
                .foregroundStyle(Color.terracotta)
                .frame(width: 44, height: 44)
                .background(Color.sand, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("NEW ON YOUR ISLAND" + (more > 0 ? " · \(more) MORE" : ""))
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Color.terracotta)
                Text(notice.title)
                    .font(.headline)
                    .foregroundStyle(Color.bodyText)
                    .lineLimit(2)
                Text(notice.detail)
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            if let onSee {
                Button("See it", action: onSee)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primaryBrown)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Color.card, in: Capsule())
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.secondaryText)
                    .frame(width: 32, height: 44)
            }
            .accessibilityLabel(more > 0 ? "Next" : "Dismiss")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .background(Color.cream.opacity(0.97), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.primaryBrown.opacity(0.16), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("New on your island: \(notice.title). \(notice.detail)")
    }
}
