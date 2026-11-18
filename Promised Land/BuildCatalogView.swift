import SwiftUI

/// "What can I build?": the 66 Places in Bible order.
struct BuildCatalogView: View {
    @ProgressQuery private var progress: GameProgress

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                PlaceSectionHeader(title: "Old Testament")
                ForEach(BibleCatalog.books.filter { $0.testament == .old }) { book in
                    PlaceTile(book: book, card: PlaceCardCatalog.card(for: book),
                              read: progress.chaptersRead(book.id)) {
                        // Stage 3 supplies the prepared card payload.
                    }
                }
                PlaceSectionHeader(title: "New Testament")
                ForEach(BibleCatalog.books.filter { $0.testament == .new }) { book in
                    PlaceTile(book: book, card: PlaceCardCatalog.card(for: book),
                              read: progress.chaptersRead(book.id)) {
                        // Stage 3 supplies the prepared card payload.
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .themedScreen()
        .navigationTitle("What can I build?")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("Tap a place to see what it is")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color.cream)
        }
        .closeReadingButton()
    }
}

struct PlaceSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.serifTitle(.title3))
            .foregroundStyle(Color.bodyText)
            .gridCellColumns(2)
            .padding(.top, 8)
    }
}

struct PlaceTile: View {
    let book: Book
    let card: PlaceCard?
    let read: Int
    let onTap: () -> Void

    private var state: PlaceTileState {
        PlaceTileState.forRead(read, total: book.chapterCount)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                PlaceTilePicture(book: book, faded: state == .notStarted)
                    .aspectRatio(660.0 / 560.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)

                Text(card?.name ?? PlaceData.spec(for: book.id).name)
                    .font(.headline)
                    .foregroundStyle(Color.bodyText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                PlaceTileStatus(book: book, state: state)

                if case .inProgress(let chapters) = state {
                    ProgressView(value: Double(chapters), total: Double(book.chapterCount))
                        .tint(Color.olive)
                        .scaleEffect(y: 0.7)
                } else if state == .complete {
                    ProgressView(value: 1)
                        .tint(Color.olive)
                        .scaleEffect(y: 0.7)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(card?.name ?? book.name), \(PlaceTileState.accessibilityText(state, book: book))")
    }
}

struct PlaceTileStatus: View {
    let book: Book
    let state: PlaceTileState

    var body: some View {
        Group {
            switch state {
            case .notStarted:
                Label("Not started", systemImage: "lock.fill")
            case .inProgress(let chapters):
                Text("\(book.name) · \(chapters) of \(book.chapterCount)")
            case .complete:
                Text("\(book.name) · Complete")
            }
        }
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
        .lineLimit(1)
        .truncationMode(.tail)
    }
}

struct PlaceTilePicture: View {
    let book: Book
    let faded: Bool

    var body: some View {
        Group {
            if let art = ArtAssets.image(PlaceCardCatalog.finishedArtName(for: book)) {
                Image(decorative: art.image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                InteriorHeaderArt(bookID: book.id, distinct: book.chapterCount, totalReads: book.chapterCount)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Earthy.groundLight.opacity(0.6))
        .clipped()
        .saturation(faded ? 0 : 1)
        .opacity(faded ? 0.55 : 1)
    }
}

/// The three display states for a catalogue tile.
enum PlaceTileState: Equatable {
    case notStarted
    case inProgress(Int)
    case complete

    static func forRead(_ read: Int, total: Int) -> Self {
        let capped = min(max(0, read), max(0, total))
        if capped == 0 { return .notStarted }
        if capped >= total { return .complete }
        return .inProgress(capped)
    }

    static func accessibilityText(_ state: Self, book: Book) -> String {
        switch state {
        case .notStarted: "Not started"
        case .inProgress(let chapters): "\(book.name), \(chapters) of \(book.chapterCount) chapters read"
        case .complete: "Complete"
        }
    }
}

/// Words for what a book builds. Kept for existing previews and tests.
enum BuildPreview {
    static func artifactLine(_ bookID: String) -> String {
        let spec = PlaceData.spec(for: bookID)
        guard ContentGate.isVisible(spec) else { return "Grows with every chapter you read." }
        return "Grows: " + spec.pieces.map(\\.caption).joined(separator: ", then ").capitalizedFirst + "."
    }

    static func characterLine(_ bookID: String) -> String? {
        let names = CharacterJourneys.all.filter { journey in
            journey.required.contains { $0.bookID == bookID }
        }.map(\\.name)
        guard !names.isEmpty else { return nil }
        return "Counts toward " + names.map { "\($0)'s" }.joined(separator: ", ") +
            (names.count == 1 ? " journey" : " journeys")
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

#Preview {
    NavigationStack {
        BuildCatalogView()
    }
    .modelContainer(PreviewData.container)
}
