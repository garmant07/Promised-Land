import SwiftUI
import SwiftData

/// Inside the Library: the reading hub. Every book of the Bible stands on its shelves (take
/// one down to read it), with the reading desk (where you left off) and a shelf for the rest
/// of reading: "What can I build?" and your journals.
struct LibraryHubView: View {
    var onClose: () -> Void

    @ProgressQuery private var progress: GameProgress
    @Query private var journal: [JournalEntry]
    @Query private var reads: [ChapterRead]
    @State private var readSummary = LibrarySummaryCache<ChapterRead, LibraryReadSummary>()
    @State private var journalSummary = LibrarySummaryCache<JournalEntry, LibraryJournalSummary>()
    @State private var path = NavigationPath()
    @State private var showingJournals = false
    @Environment(\.bibleService) private var bible

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    header
                    LibraryStageCard(growth: growth)
                    readingDesk
                    readingRoom
                    volumesShelf
                    ForEach(BookSection.all) { section in
                        bookShelf(section)
                    }
                    Text(bible.isLive
                         ? "Chapters load as you open them and are kept for reading offline. In any chapter, choose “I read this in my own Bible” and answer a quick question or reflection to count your reading."
                         : "American Standard Version sample text is available for some chapters. Every chapter also has “I read this in my own Bible”, followed by a quick question or reflection.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(16)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background(LibraryBackdrop().ignoresSafeArea())
            .debugOpenTiming("Library")
            .debugOpenBook($path)
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
                LibraryShelfLabel(title: "On the reading desk", systemImage: "book.pages")
                NavigationLink(value: suggestion.ref) { ReadingSuggestionCard(suggestion: suggestion) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var readingRoom: some View {
        VStack(alignment: .leading, spacing: 8) {
            LibraryShelfLabel(title: "The reading room", systemImage: "lamp.table")
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
                LibraryPlank()
            }
        }
    }

    private func bookShelf(_ section: BookSection) -> some View {
        let books = section.books
        let read = books.reduce(0) { $0 + progress.chaptersRead($1.id) }
        let total = books.reduce(0) { $0 + $1.chapterCount }
        let notesByBook = journalSummary.value(for: journal, build: { LibraryJournalSummary(entries: $0) }).byBook
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                LibraryShelfLabel(title: section.name, systemImage: nil)
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
                                BookSpine(book: book, read: progress.chaptersRead(book.id), color: section.color,
                                          notes: notesByBook[book.id]?.count ?? 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                }
                LibraryPlank()
            }
        }
    }

    /// How grown the Library is: the same count the island uses (distinct checked chapters, and
    /// every journal entry).
    private var growth: LibraryGrowth {
        let summary = readSummary.value(for: reads, build: { LibraryReadSummary(reads: $0) })
        return LibraryGrowth(volumes: summary.volumes, notes: journal.count)
    }

    /// The Library's own shelves: a thin spine for every chapter read, in its part's colour.
    private var volumesShelf: some View {
        let counts = BookSection.all.map { section in
            (section.color, section.books.reduce(0) { $0 + progress.chaptersRead($1.id) })
        }
        let total = counts.reduce(0) { $0 + $1.1 }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                LibraryShelfLabel(title: "Volumes", systemImage: "books.vertical")
                Spacer()
                Text("\(total) of \(BibleCatalog.totalChapters)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.secondaryText)
            }
            VStack(spacing: 0) {
                VolumeSpines(counts: counts)
                    .frame(height: VolumeSpines.height(for: total))
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                LibraryPlank()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(total) volumes on the Library's shelves, one for every chapter read")
        }
    }

}

#Preview("Library hub") {
    LibraryHubView(onClose: {})
        .modelContainer(PreviewData.container)
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
    /// Journal entries about this book: shown as handwritten notes tucked into its top.
    var notes = 0

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
        .overlay(alignment: .top) {
            if notes > 0 { TuckedNotes(count: notes).offset(y: -12) }
        }
        .padding(.top, notes > 0 ? 12 : 0)
        .shadow(color: Color.primaryBrown.opacity(0.12), radius: 1.5, x: 1, y: 0)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.name), \(read) of \(book.chapterCount) chapters read"
            + (notes > 0 ? ", \(notes) \(notes == 1 ? "note" : "notes") tucked in" : ""))
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

/// Handwritten notes tucked into the top of a book: one slip per journal entry (up to three).
private struct TuckedNotes: View {
    let count: Int

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(0..<min(3, count), id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color(hex: i % 2 == 0 ? "#FFFBF1" : "#FBF3DF"))
                    .overlay(alignment: .top) {
                        VStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                Capsule().fill(Color.primaryBrown.opacity(0.35)).frame(width: 9, height: 1)
                            }
                        }
                        .padding(.top, 3)
                    }
                    .frame(width: 14, height: 20)
                    .rotationEffect(.degrees(Double(i - 1) * 9))
                    .offset(x: CGFloat(i - 1) * 6)
                    .shadow(color: Color.primaryBrown.opacity(0.15), radius: 0.8, y: 0.5)
            }
            if count > 3 {
                Text("+\(count - 3)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.primaryBrown)
                    .offset(x: 14, y: -6)
            }
        }
    }
}

/// The Library's stage, what it's made of, and how far to the next.
struct LibraryStageCard: View {
    let growth: LibraryGrowth

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "building.columns.fill")
                    .font(.title3)
                    .foregroundStyle(Color.lavender)
                    .frame(width: 40, height: 40)
                    .background(Color.cream, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(growth.stage.name).font(.headline).foregroundStyle(Color.bodyText)
                    Text("\(growth.volumes) \(growth.volumes == 1 ? "volume" : "volumes") · \(growth.notes) \(growth.notes == 1 ? "note" : "notes")")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.secondaryText)
                }
            }
            if let next = growth.stage.next, let left = growth.pointsToNext {
                ProgressView(value: growth.progressToNext).tint(Color.olive)
                Text("\(next.name) in \(left) more: each chapter read adds a volume, each journal entry adds two.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            } else {
                Text("The grand central library: the heart of your island.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// One thin spine per chapter read, rows of them, in each part's colour (drawn in one Canvas).
private struct VolumeSpines: View {
    let counts: [(Color, Int)]
    static let perRow = 60

    static func height(for total: Int) -> CGFloat {
        let rows = max(1, Int(ceil(Double(total) / Double(perRow))))
        return CGFloat(min(rows, 20)) * 26
    }

    var body: some View {
        Canvas { c, size in
            let w = size.width / CGFloat(Self.perRow)
            var n = 0
            for (colour, count) in counts {
                for k in 0..<count {
                    let row = n / Self.perRow, col = n % Self.perRow
                    guard row < 20 else { return }
                    let h: CGFloat = 18 + CGFloat((n * 7 + k) % 5)
                    let rect = CGRect(x: CGFloat(col) * w + 0.5, y: CGFloat(row) * 26 + (24 - h), width: max(1, w - 1), height: h)
                    c.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(colour.opacity(0.75 + Double((n % 3)) * 0.08)))
                    n += 1
                }
            }
        }
    }
}
