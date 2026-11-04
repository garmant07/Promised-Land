import SwiftUI
import SwiftData

/// Inside the Library: the reading hub. Every book of the Bible stands on its shelves (take
/// one down to read it), with the reading desk (where you left off) and a shelf for the rest
/// of reading: "What can I build?" and your journals.
struct LibraryHubView: View {
    var onClose: () -> Void

    @ProgressQuery private var progress: GameProgress
    @Query private var journal: [JournalEntry]
    @State private var path = NavigationPath()
    @State private var showingJournals = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    readingDesk
                    readingRoom
                    ForEach(BookSection.all) { section in
                        bookShelf(section)
                    }
                    Text("American Standard Version sample text for some chapters; mark any chapter as read from your own Bible.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(16)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background(LibraryBackdrop().ignoresSafeArea())
            .navigationTitle("The Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onClose() } label: { Label("Back to the island", systemImage: "chevron.backward") }
                        .tint(Color.primaryBrown)
                }
                // The page has its own big title; keep the bar clear.
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
            }
            .readingDestinations()
            .sheet(isPresented: $showingJournals) { LibraryShelfView() }
        }
        .environment(\.closeReading, CloseReadingAction(action: onClose))
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("The Library")
                    .font(.serifTitle(.largeTitle))
                    .foregroundStyle(Color.bodyText)
                Spacer()
                StreakPill(days: progress.streak)
            }
            Text("Every book of the Bible is on these shelves. Take one down to read; each builds its own place on your island.")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
        }
    }

    @ViewBuilder
    private var readingDesk: some View {
        if let suggestion = ReadingSuggestion.make(from: progress) {
            VStack(alignment: .leading, spacing: 8) {
                shelfTitle("On the reading desk", systemImage: "book.pages")
                NavigationLink(value: suggestion.ref) { ReadingSuggestionCard(suggestion: suggestion) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var readingRoom: some View {
        VStack(alignment: .leading, spacing: 8) {
            shelfTitle("The reading room", systemImage: "lamp.table")
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 12) {
                    NavigationLink(value: CatalogLink()) {
                        RoomObject(title: "What can I build?", detail: "Every book's building", symbol: "building.columns.fill",
                                   color: Color.terracotta)
                    }
                    .buttonStyle(.plain)
                    Button { showingJournals = true } label: {
                        RoomObject(title: "Your journals", detail: journal.isEmpty ? "None yet" : "\(journal.count) \(journal.count == 1 ? "entry" : "entries")",
                                   symbol: "books.vertical.fill", color: Color.lavender)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                Plank()
            }
        }
    }

    private func bookShelf(_ section: BookSection) -> some View {
        let books = section.books
        let read = books.reduce(0) { $0 + progress.chaptersRead($1.id) }
        let total = books.reduce(0) { $0 + $1.chapterCount }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                shelfTitle(section.name, systemImage: nil)
                Spacer()
                Text("\(read) of \(total) chapters")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.secondaryText)
            }
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(books) { book in
                            NavigationLink(value: book) {
                                BookSpine(book: book, read: progress.chaptersRead(book.id), color: section.color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                }
                Plank()
            }
        }
    }

    private func shelfTitle(_ title: String, systemImage: String?) -> some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).foregroundStyle(Color.terracotta) }
            Text(title)
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
        }
    }
}

/// The parts of the Bible, each with its own shelf and spine colour.
struct BookSection: Identifiable {
    let id: String
    let name: String
    let range: Range<Int>
    let color: Color

    var books: [Book] { Array(BibleCatalog.books[range]) }

    static let all: [BookSection] = [
        BookSection(id: "law", name: "The Law", range: 0..<5, color: Color.terracotta),
        BookSection(id: "history", name: "History", range: 5..<17, color: Color(hex: "#C98F6E")),
        BookSection(id: "wisdom", name: "Poetry & Wisdom", range: 17..<22, color: Color.lavender),
        BookSection(id: "prophets", name: "The Prophets", range: 22..<39, color: Color.olive),
        BookSection(id: "gospels", name: "The Gospels", range: 39..<43, color: Color(hex: "#E1B067")),
        BookSection(id: "letters", name: "Acts & the Letters", range: 43..<65, color: Color(hex: "#93AECF")),
        BookSection(id: "revelation", name: "Revelation", range: 65..<66, color: Color(hex: "#A792C4")),
    ]
}

/// A book on the shelf: taller for longer books, filling up from the bottom as you read,
/// with a gold band once it's finished.
struct BookSpine: View {
    let book: Book
    let read: Int
    let color: Color

    private var fraction: CGFloat { CGFloat(min(read, book.chapterCount)) / CGFloat(max(1, book.chapterCount)) }
    private var height: CGFloat { 118 + CGFloat(min(book.chapterCount, 50)) * 0.9 }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color.opacity(0.38))
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color)
                .frame(height: height * fraction)
            VStack(spacing: 0) {
                if read >= book.chapterCount {
                    Rectangle().fill(Earthy.gold).frame(height: 6).padding(.top, 10)
                } else {
                    Rectangle().fill(Color.primaryBrown.opacity(0.18)).frame(height: 2).padding(.top, 12)
                }
                Spacer(minLength: 0)
                Text(book.name)
                    .font(.system(.caption, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.bodyText)
                    .lineLimit(1)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .frame(width: 20, height: height - 54)
                Spacer(minLength: 0)
                Text(read >= book.chapterCount ? "✓" : "\(book.chapterCount)")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.bodyText.opacity(0.7))
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 40, height: height)
        .shadow(color: Color.primaryBrown.opacity(0.12), radius: 1.5, x: 1, y: 0)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.name), \(read) of \(book.chapterCount) chapters read")
        .accessibilityHint("Opens the book")
    }
}

/// Something standing on the reading-room shelf.
private struct RoomObject: View {
    let title: String
    let detail: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(Color.cream, in: Circle())
            Text(title).font(.headline).foregroundStyle(Color.bodyText)
            Text(detail).font(.footnote).foregroundStyle(Color.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .bottomLeading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// A wooden shelf board.
private struct Plank: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: "#CFA474"), Color(hex: "#B98A5C")], startPoint: .top, endPoint: .bottom))
            .frame(height: 12)
            .shadow(color: Color.primaryBrown.opacity(0.22), radius: 3, y: 3)
    }
}

/// Warm library walls behind the shelves.
private struct LibraryBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: "#F6EAD4"), Color(hex: "#EFDDBE")], startPoint: .top, endPoint: .bottom)
    }
}
