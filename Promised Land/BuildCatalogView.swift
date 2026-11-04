import SwiftUI

/// "What can I build?": every book's building, the artifacts its chapters place, its story
/// objects, and the characters it helps bring to your island.
struct BuildCatalogView: View {
    @ProgressQuery private var progress: GameProgress
    @State private var testament: Testament = .old

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("Every book raises its own building. Each chapter places something on its plot, and finishing the book raises the building itself.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                Picker("Testament", selection: $testament) {
                    Text("Old Testament").tag(Testament.old)
                    Text("New Testament").tag(Testament.new)
                }
                .pickerStyle(.segmented)
                ForEach(BibleCatalog.books.filter { $0.testament == testament }) { book in
                    NavigationLink(value: book) {
                        BuildPreviewRow(book: book, read: progress.chaptersRead(book.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .themedScreen()
        .navigationTitle("What can I build?")
        .navigationBarTitleDisplayMode(.inline)
        .closeReadingButton()
    }
}

/// One book's building, artifacts and characters.
struct BuildPreviewRow: View {
    let book: Book
    let read: Int

    private var spec: BuildingSpec { BuildingData.spec(for: book.id) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InteriorHeaderArt(spec: spec, progress: book.chapterCount, total: book.chapterCount, fullReads: 1)
                .frame(width: 92, height: 80)
                .background(Earthy.groundLight.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(WorldData.landmark(bookID: book.id)?.name ?? book.name)
                    .font(.headline)
                    .foregroundStyle(Color.bodyText)
                Text("\(book.name) · \(read) of \(book.chapterCount) chapters")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                Text(BuildPreview.artifactLine(book.id))
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                if let stories = BuildPreview.storyLine(book.id) {
                    Text(stories).font(.footnote).foregroundStyle(Color.secondaryText)
                }
                if let who = BuildPreview.characterLine(book.id) {
                    Label(who, systemImage: "person.2.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.terracotta)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Words for what a book builds. Pure, so it's testable.
enum BuildPreview {
    static func artifactLine(_ bookID: String) -> String {
        var seen: [String] = []
        for kind in BuildingData.spec(for: bookID).theme {
            let name = InsightSubject.name(of: .artifact(kind))
            if !seen.contains(name) { seen.append(name) }
        }
        return "Chapters place: " + seen.joined(separator: ", ").lowercased().capitalizedFirst
    }

    static func storyLine(_ bookID: String) -> String? {
        let stories = ChapterLandmarks.visible.filter { $0.bookID == bookID }
        guard !stories.isEmpty else { return nil }
        return "Stories: " + stories.map { "\($0.name) (\($0.chapterLabel))" }.joined(separator: ", ")
    }

    static func characterLine(_ bookID: String) -> String? {
        let names = CharacterUnlocks.visible.filter { $0.books.contains(bookID) }.map(\.name)
        guard !names.isEmpty else { return nil }
        return "Helps welcome " + names.joined(separator: " and ")
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
