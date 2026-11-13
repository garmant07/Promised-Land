import SwiftUI

/// "What can I build?": every book's Place, what its chapters add to it, and the characters it
/// helps bring to your island.
struct BuildCatalogView: View {
    @ProgressQuery private var progress: GameProgress
    @State private var testament: Testament = .old

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("Every book builds one Place on your island. Its first chapter founds it, every chapter adds something, and rereads make it richer.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                Picker("Testament", selection: $testament) {
                    Text("Old Testament").tag(Testament.old)
                    Text("New Testament").tag(Testament.new)
                }
                .pickerStyle(.segmented)
                .tint(Color.primaryBrown)
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

/// One book's Place, what grows there, and its characters.
struct BuildPreviewRow: View {
    let book: Book
    let read: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InteriorHeaderArt(bookID: book.id, distinct: book.chapterCount, totalReads: book.chapterCount)
                .frame(width: 92, height: 80)
                .background(Earthy.groundLight.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(PlaceData.spec(for: book.id).name)
                    .font(.headline)
                    .foregroundStyle(Color.bodyText)
                Text("\(book.name) · \(read) of \(book.chapterCount) chapters")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                Text(BuildPreview.artifactLine(book.id))
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
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
    /// What grows in a book's Place, in order (plain wording in Release until reviewed).
    static func artifactLine(_ bookID: String) -> String {
        let spec = PlaceData.spec(for: bookID)
        guard ContentGate.isVisible(spec) else { return "Grows with every chapter you read." }
        return "Grows: " + spec.pieces.map(\.caption).joined(separator: ", then ").capitalizedFirst + "."
    }

    static func characterLine(_ bookID: String) -> String? {
        let names = CharacterJourneys.all.filter { j in j.required.contains { $0.bookID == bookID } }.map(\.name)
        guard !names.isEmpty else { return nil }
        return "Counts toward " + names.map { "\($0)'s" }.joined(separator: ", ") + (names.count == 1 ? " journey" : " journeys")
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
