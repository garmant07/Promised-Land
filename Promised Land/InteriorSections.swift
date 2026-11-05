import SwiftUI
import SwiftData

/// Inside a building: your journal entries for its book (tap one to open it in the Library),
/// and a way to add a reflection.
struct InteriorJournalSection: View {
    let book: Book
    let entries: [JournalEntry]
    var onAddReflection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your journal")
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
            if entries.isEmpty {
                Text("Nothing written about \(book.name) yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
            ForEach(entries.prefix(6)) { entry in
                NavigationLink(value: JournalOpen(volume: JournalVolume(id: book.id, title: book.name, count: entries.count),
                                                  entryID: entry.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text([entry.chapter.map { "\(book.name) \($0)" }, entry.created.formatted(date: .abbreviated, time: .omitted)]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                        if let prompt = entry.prompt {
                            Text(prompt).font(.footnote).italic().foregroundStyle(Color.secondaryText)
                        }
                        Text(entry.text)
                            .font(.body)
                            .foregroundStyle(Color.bodyText)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this entry in the Library")
            }
            Button("Add a reflection", action: onAddReflection)
                .buttonStyle(SoftButtonStyle())
        }
        .cardStyle()
    }
}

/// Renders share images of the island or of one building, with your character and stats.
@MainActor
enum ShareRender {
    static func card(title: String, subtitle: String, artwork: some View, avatar: Avatar,
                     streak: Int, chaptersThisYear: Int) -> UIImage? {
        let art = ImageRenderer(content: artwork.frame(width: 900, height: 700))
        art.scale = 2
        return ShareCardView(title: title, subtitle: subtitle, artwork: art.uiImage, avatar: avatar,
                             streak: streak, chaptersThisYear: chaptersThisYear).render()
    }
}

/// The whole island drawn once, fitted to its frame (for share images).
struct IslandPicture: View {
    let island: Island

    var body: some View {
        Canvas { c, size in
            c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Earthy.sea))
            let layout = IslandLayout(island: island, size: size, insets: EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30))
            IslandPainter.drawTiles(&c, island: island, layout: layout)
            for item in island.items.sorted(by: { layout.depth($0.gx, $0.gy) < layout.depth($1.gx, $1.gy) }) {
                IslandPainter.drawItem(&c, item, layout: layout)
            }
        }
    }
}

#Preview("Journal section") {
    NavigationStack {
        InteriorJournalSection(book: BibleCatalog.book(id: "ruth")!, entries: [], onAddReflection: {})
            .padding()
    }
    .modelContainer(PreviewData.container)
}
