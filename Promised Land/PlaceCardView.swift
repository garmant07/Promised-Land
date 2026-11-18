import SwiftUI

struct PlaceCardRoute: Identifiable {
    let book: Book
    let card: PlaceCard
    let read: Int

    var id: String { book.id }
}

struct PlaceCardView: View {
    let route: PlaceCardRoute
    let onRead: () -> Void
    let onShowOnIsland: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .topTrailing) {
                    PlaceTilePicture(book: route.book, faded: false)
                        .aspectRatio(660.0 / 560.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .accessibilityHidden(true)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.primaryBrown)
                            .frame(width: 44, height: 44)
                            .background(Color.cream.opacity(0.9), in: Circle())
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("Close")
                    .padding(10)
                }

                Text(route.card.name)
                    .font(.serifTitle(.largeTitle))
                    .foregroundStyle(Color.bodyText)

                Text("Built by reading \(route.book.name) · \(route.book.chapterCount) chapters")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)

                PlaceCardProgress(read: route.read, total: route.book.chapterCount)

                PlaceCardSection(title: "What it is", text: route.card.what)
                PlaceCardSection(title: "Why it's here", text: route.card.why)

                VStack(spacing: 10) {
                    Button {
                        onRead()
                        dismiss()
                    } label: {
                        Text("Read \(route.book.name)")
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if route.read > 0 {
                        Button {
                            onShowOnIsland()
                            dismiss()
                        } label: {
                            Label("Show on my island", systemImage: "mappin.and.ellipse")
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .themedScreen()
        .presentationDragIndicator(.visible)
    }
}

struct PlaceCardProgress: View {
    let read: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if read > 0 {
                ProgressView(value: Double(min(read, total)), total: Double(total))
                    .tint(Color.olive)
                Text("\(min(read, total)) of \(total) chapters read")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            } else {
                Text("Not started yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
            }
        }
    }
}

struct PlaceCardSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
            Text(text)
                .font(.body)
                .foregroundStyle(Color.bodyText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    PlaceCardView(
        route: PlaceCardRoute(
            book: BibleCatalog.book(id: "genesis")!,
            card: PlaceCardCatalog.cards[0],
            read: 3),
        onRead: {},
        onShowOnIsland: {})
}
