import SwiftUI

/// The single most useful next step, shown at the bottom of the World tab.
struct NextUnlock {
    let title: String
    let detail: String
    let place: Place

    static func suggest(from progress: GameProgress) -> NextUnlock? {
        // 1. A book already started: finish it.
        let started = Place.all.compactMap { place -> (Place, Book, Int)? in
            guard let book = place.book else { return nil }
            let read = progress.chaptersRead(in: book)
            return (read > 0 && read < book.chapters.count) ? (place, book, read) : nil
        }
        if let (place, book, read) = started.max(by: { $0.2 < $1.2 }) {
            let left = book.chapters.count - read
            return NextUnlock(title: place.name,
                              detail: "Read \(left) more \(left == 1 ? "chapter" : "chapters") of \(book.name) to unlock it.",
                              place: place)
        }
        // 2. A quiz or verse waiting.
        for place in Place.all {
            switch progress.level(of: place) {
            case .unlocked:
                return NextUnlock(title: place.name, detail: "Pass the \(place.book?.name ?? "") quiz to help it grow.", place: place)
            case .growing:
                return NextUnlock(title: place.name, detail: "Memorise \(place.memoryVerse.reference) to make it flourish.", place: place)
            default: continue
            }
        }
        // 3. Something new.
        if let place = Place.all.first(where: { progress.level(of: $0) == .locked }), let book = place.book {
            return NextUnlock(title: place.name, detail: "Start reading \(book.name) to begin building it.", place: place)
        }
        return nil
    }
}

struct NextUnlockCard: View {
    let next: NextUnlock
    @Binding var collapsed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(duration: 0.35)) { collapsed.toggle() }
            } label: {
                HStack {
                    Label("Next unlock", systemImage: "sparkle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.terracotta)
                    if collapsed {
                        Text(next.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.bodyText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: collapsed ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.secondaryText)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(collapsed ? "Show next unlock" : "Hide next unlock")

            if !collapsed {
                Text(next.title)
                    .font(.serifTitle(.title3))
                    .foregroundStyle(Color.bodyText)
                Text(next.detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                NavigationLink(value: next.place) {
                    Text("Open \(next.title)")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.primaryBrown.opacity(0.12), radius: 12, y: 4)
    }
}
