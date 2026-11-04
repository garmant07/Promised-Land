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
    static func all(island: Island, completedJourneys: [Journey]) -> [UnlockNotice] {
        var out: [UnlockNotice] = []
        for (index, item) in island.items.enumerated() {
            switch item.kind {
            case .building(let bookID):
                guard let book = BibleCatalog.book(id: bookID) else { continue }
                let name = WorldData.landmark(bookID: bookID)?.name ?? book.name
                let level = IslandPainter.buildingLevel(item)
                if level >= 1 {
                    out.append(UnlockNotice(id: "built:\(bookID)", title: "\(name) is built",
                                            detail: "You finished \(book.name). Tap the building to step inside.",
                                            symbol: "building.columns.fill", itemIndex: index))
                }
                if item.level >= 2 {
                    // One notice per extra floor (from full rereads).
                    for floor in 2...item.level {
                        out.append(UnlockNotice(id: "floor:\(bookID):\(floor)", title: "A new floor on \(name)",
                                                detail: "You read \(book.name) through again (\(floor) times).",
                                                symbol: "square.stack.3d.up.fill", itemIndex: index))
                    }
                }
            case .story(let id):
                guard let entry = ChapterLandmarks.entry(id: id) else { continue }
                out.append(UnlockNotice(id: "story:\(id)", title: "\(entry.name) appeared",
                                        detail: "From \(entry.chapterLabel). Tap it to see why it's here.",
                                        symbol: "sparkles", itemIndex: index))
            case .reward(let kind):
                guard let bookID = item.source.bookID, let book = BibleCatalog.book(id: bookID) else { continue }
                let (title, detail, symbol): (String, String, String) = switch kind {
                case .banner: ("A banner for \(book.name)", "You passed the \(book.name) quiz.", "flag.fill")
                case .lantern: ("A lantern is lit", "You memorised a verse from \(book.name).", "lamp.desk.fill")
                case .fruitTree: ("A fruit tree grew", "You memorised a verse from \(book.name).", "leaf.fill")
                }
                out.append(UnlockNotice(id: "reward:\(bookID):\(kind.rawValue)", title: title, detail: detail,
                                        symbol: symbol, itemIndex: index))
            case .library:
                out.append(UnlockNotice(id: "library", title: "The Library is open",
                                        detail: "Every book of the Bible is on its shelves. Walk in to read.",
                                        symbol: "books.vertical.fill", itemIndex: index))
            case .artifact:
                continue // every chapter adds one; the growth note covers these
            }
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
