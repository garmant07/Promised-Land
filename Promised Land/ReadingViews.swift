import SwiftUI
import SwiftData

// MARK: - Library

struct LibraryView: View {
    @ProgressQuery private var progress: GameProgress
    /// Opens straight into this chapter (with its book underneath), if given.
    var startAt: ChapterRef? = nil
    /// Shown as a close button when reading is presented from the home page.
    var onClose: (() -> Void)? = nil
    /// Shows "Continue reading" at the top (in the Read sheet).
    var showsSuggestion = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Read")
                            .font(.serifTitle(.largeTitle))
                            .foregroundStyle(Color.bodyText)
                        Spacer()
                        StreakPill(days: progress.streak)
                        if let onClose {
                            Button(action: onClose) {
                                Image(systemName: "xmark")
                                    .font(.headline)
                                    .foregroundStyle(Color.primaryBrown)
                                    .frame(width: 44, height: 44)
                                    .background(Color.card, in: Circle())
                            }
                            .accessibilityLabel("Close reading")
                        }
                    }
                    .padding(.top, 8)
                    if showsSuggestion, let suggestion = ReadingSuggestion.make(from: progress) {
                        NavigationLink(value: suggestion.ref) { ReadingSuggestionCard(suggestion: suggestion) }
                            .buttonStyle(.plain)
                            .padding(.bottom, 4)
                    }
                    NavigationLink(value: CatalogLink()) {
                        HStack(spacing: 10) {
                            Image(systemName: "building.columns.fill")
                                .foregroundStyle(Color.terracotta)
                                .frame(width: 36, height: 36)
                                .background(Color.sand, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("What can I build?").font(.headline).foregroundStyle(Color.bodyText)
                                Text("Every book's building, artifacts and characters")
                                    .font(.footnote).foregroundStyle(Color.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Color.secondaryText)
                        }
                        .padding(12)
                        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Text("All 66 books, in any order. Each one builds a landmark in your world.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                        .padding(.bottom, 4)
                    ForEach(WorldData.regions) { region in
                        Text(region.name)
                            .font(.serifTitle(.title3))
                            .foregroundStyle(Color.bodyText)
                            .padding(.top, 12)
                        ForEach(WorldData.landmarks.filter { $0.regionID == region.id }) { landmark in
                            if let book = landmark.book {
                                NavigationLink(value: book) {
                                    BookRow(book: book, landmark: landmark, progress: progress)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .themedScreen()
            .navigationTitle("Read")
            .hiddenNavigationBar()
            .readingDestinations()
        }
        .environment(\.closeReading, onClose.map(CloseReadingAction.init))
        .onAppear {
            guard path.isEmpty, let startAt, let book = BibleCatalog.book(id: startAt.bookID) else { return }
            path.append(book)
            path.append(startAt)
        }
    }
}

extension View {
    /// Navigation destinations shared by every stack. Each screen gets a close button
    /// that leaves reading entirely, wherever you are.
    func readingDestinations() -> some View {
        self
            .navigationDestination(for: Book.self) { BookView(book: $0).closeReadingButton() }
            .navigationDestination(for: CatalogLink.self) { _ in BuildCatalogView() }
            .navigationDestination(for: Landmark.self) { PlaceDetailView(landmark: $0).closeReadingButton() }
            .navigationDestination(for: ChapterRef.self) { ref in
                if let book = BibleCatalog.book(id: ref.bookID) {
                    ChapterReaderView(book: book, chapter: ref.chapter).closeReadingButton()
                }
            }
    }

    /// Adds a ✕ that closes reading straight back to the home page (when reading was opened from there).
    func closeReadingButton() -> some View { modifier(CloseReadingButton()) }
}

/// Closes the whole reading area. Always compares equal, so passing it down
/// the environment doesn't cause extra redraws.
struct CloseReadingAction: Equatable {
    let action: () -> Void
    func callAsFunction() { action() }
    static func == (lhs: Self, rhs: Self) -> Bool { true }
}

extension EnvironmentValues {
    /// Closes the whole reading area, from any screen inside it.
    @Entry var closeReading: CloseReadingAction? = nil
}

private struct CloseReadingButton: ViewModifier {
    @Environment(\.closeReading) private var closeReading

    func body(content: Content) -> some View {
        content.toolbar {
            if let closeReading {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { closeReading() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primaryBrown)
                    }
                    .accessibilityLabel("Close reading")
                }
            }
        }
    }
}

/// Opens "What can I build?".
struct CatalogLink: Hashable {}

struct ChapterRef: Hashable, Identifiable {
    var id: String { "\(bookID)#\(chapter)" }
    let bookID: String
    let chapter: Int
}

struct BookRow: View {
    let book: Book
    let landmark: Landmark
    let progress: GameProgress

    var body: some View {
        let read = progress.chaptersRead(book.id)
        HStack(spacing: 14) {
            LandmarkArtView(landmark: landmark, stage: progress.stage(of: book.id),
                            level: progress.level(of: book.id), size: 52, read: read)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(book.name)
                        .font(.headline)
                        .foregroundStyle(Color.bodyText)
                    if book.hasSampleText {
                        Text("Sample text")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.primaryBrown)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.sand, in: Capsule())
                    }
                }
                Text(landmark.name)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                ProgressView(value: Double(read), total: Double(book.chapterCount))
                    .tint(Color.olive)
            }
            Text("\(read)/\(book.chapterCount)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Color.secondaryText)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText.opacity(0.6))
        }
        .padding(12)
        .frame(minHeight: 64)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Book

struct BookView: View {
    let book: Book
    @ProgressQuery private var progress: GameProgress

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // What reading this book builds.
                BuildPreviewRow(book: book, read: progress.chaptersRead(book.id))
                if let landmark = WorldData.landmark(bookID: book.id) {
                    NavigationLink(value: landmark) {
                        LandmarkRow(landmark: landmark, progress: progress)
                    }
                    .buttonStyle(.plain)
                }
                HStack {
                    Text("Chapters")
                        .font(.serifTitle(.title3))
                        .foregroundStyle(Color.bodyText)
                    Spacer()
                    Text("\(progress.chaptersRead(book.id)) of \(book.chapterCount) read")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(.top, 6)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(book.chapterNumbers), id: \.self) { number in
                        NavigationLink(value: ChapterRef(bookID: book.id, chapter: number)) {
                            chapterCell(number)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !book.hasSampleText {
                    Label("The text of \(book.name) is coming soon. You can still mark chapters as read from your own Bible.",
                          systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .themedScreen()
        .navigationTitle(book.name)
    }

    private func chapterCell(_ number: Int) -> some View {
        let isRead = progress.isRead(book.id, chapter: number)
        let hasText = SampleText.verses(book: book.id, chapter: number) != nil
        return Text("\(number)")
            .font(.headline.monospacedDigit())
            .foregroundStyle(isRead ? Color.onPrimary : Color.bodyText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isRead ? Color.olive : (hasText ? Color.sand : Color.card),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if hasText && !isRead {
                    Circle().fill(Color.terracotta).frame(width: 7, height: 7).padding(6)
                }
            }
            .accessibilityLabel("Chapter \(number), \(isRead ? "read" : "not read")\(hasText ? ", text available" : "")")
    }
}

// MARK: - Reader

struct ChapterReaderView: View {
    let book: Book
    let chapter: Int

    @Environment(\.modelContext) private var context
    @ProgressQuery private var progress: GameProgress
    @Query private var reads: [ChapterRead]
    @State private var celebration: Celebration?
    @State private var checking = false
    @State private var deepDive: (dive: DeepDive, text: String)?
    @State private var checkAfterCelebration = false
    @AppStorage(StorageKeys.offerReflection) private var offerCheck = true

    init(book: Book, chapter: Int) {
        self.book = book
        self.chapter = chapter
        let id = book.id
        _reads = Query(filter: #Predicate<ChapterRead> { $0.bookID == id && $0.chapterNumber == chapter },
                       sort: \ChapterRead.date, order: .reverse)
    }

    private var isRead: Bool { !reads.isEmpty }
    /// The latest read is waiting for its quick check.
    private var needsCheck: Bool { reads.first.map { !$0.checked } ?? false }

    var body: some View {
        Group {
            if let verses = SampleText.verses(book: book.id, chapter: chapter) {
                VStack(spacing: 4) {
                    PageReaderView(title: "\(book.name) \(chapter)", verses: verses,
                                   deepDive: { DeepDiveData.entry(bookID: book.id, chapter: chapter, verse: $0.number) },
                                   onDeepDive: { dive, verse in deepDive = (dive, verse.text) }) {
                        actions(compact: true)
                    }
                    Text("American Standard Version · sample verses")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                        .padding(.bottom, 4)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("\(book.name) \(chapter)")
                            .font(.serifTitle(.largeTitle))
                            .foregroundStyle(Color.bodyText)
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Text coming soon", systemImage: "book.closed")
                                .font(.headline)
                                .foregroundStyle(Color.primaryBrown)
                            Text("This chapter isn't bundled yet. Read it in your own Bible, then mark it as read to keep building.")
                                .foregroundStyle(Color.secondaryText)
                        }
                        .cardStyle()
                        actions(compact: false)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .themedScreen()
        .navigationTitle("Chapter \(chapter)")
        .navigationBarTitleDisplayMode(.inline)
        // Opening a chapter lays the book's foundations (no need to finish it first).
        .onAppear { context.recordBookStarted(book.id) }
        .sheet(item: $celebration, onDismiss: {
            if checkAfterCelebration { checkAfterCelebration = false; checking = true }
        }) { CelebrationView(celebration: $0) }
        .sheet(isPresented: $checking) { ReadingCheckView(book: book, chapter: chapter) }
        .sheet(isPresented: Binding(get: { deepDive != nil }, set: { if !$0 { deepDive = nil } })) {
            if let deepDive { DeepDiveSheet(dive: deepDive.dive, verseText: deepDive.text) }
        }
    }

    /// Mark as read (one tap), what's been read, the reading check, and the next chapter.
    @ViewBuilder
    private func actions(compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 10) {
            if isRead {
                let count = reads.count
                Label(count == 1 ? "You've read this chapter" : "You've read this chapter \(count) times",
                      systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.olive)
                    .frame(maxWidth: .infinity, minHeight: 32)
                if needsCheck {
                    Button { checking = true } label: {
                        Label("Quick check: count it toward the building", systemImage: "hammer")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Color.primaryBrown)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                HStack(spacing: 8) {
                    Button("Read again") { recordRead() }
                        .buttonStyle(SoftButtonStyle())
                    Button("Undo") { withAnimation { context.undoLastRead(book.id, chapter) } }
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                        .frame(minWidth: 64, minHeight: 44)
                }
            } else {
                Button("Mark as read") { recordRead() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            if chapter < book.chapterCount {
                NavigationLink(value: ChapterRef(bookID: book.id, chapter: chapter + 1)) {
                    Text("Next: chapter \(chapter + 1)")
                }
                .buttonStyle(SoftButtonStyle())
            }
        }
    }

    private func recordRead() {
        let before = progress.stage(of: book.id)
        let regionWasHidden = WorldData.landmark(bookID: book.id).map { !progress.isRegionRevealed($0.regionID) } ?? false
        let firstRead = !isRead
        // One tap records the read (its artifact appears); the quick check then counts it
        // toward the building.
        withAnimation { context.recordRead(book.id, chapter, checked: false) }
        defer {
            if offerCheck {
                if celebration != nil { checkAfterCelebration = true } else { checking = true }
            }
        }
        guard firstRead, let landmark = WorldData.landmark(bookID: book.id) else { return }

        // Predict the new stage without waiting for the query to refresh.
        let read = progress.chaptersRead(book.id) + 1
        let after: BuildStage = read >= book.chapterCount ? .complete : (read * 2 >= book.chapterCount ? .rising : .foundations)
        if after == .complete && before != .complete {
            celebration = Celebration(landmark: landmark, stage: .complete,
                                      message: "You finished \(book.name). Do the quick check to raise \(landmark.name)!")
        } else if regionWasHidden {
            celebration = Celebration(landmark: landmark, stage: after,
                                      message: "The fog lifts over \(landmark.region?.name ?? "a new region"). Foundations are laid for \(landmark.name).")
        }
    }
}

// MARK: - Celebration

struct Celebration: Identifiable {
    let landmark: Landmark
    let stage: BuildStage
    var level: GrowthLevel = .base
    let message: String
    var id: String { landmark.id + "\(stage.rawValue)\(level.rawValue)" }
}

struct CelebrationView: View {
    let celebration: Celebration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            LandmarkArtView(landmark: celebration.landmark, stage: celebration.stage,
                            level: celebration.level, size: 200)
            Text(celebration.landmark.name)
                .font(.serifTitle(.largeTitle))
                .foregroundStyle(Color.bodyText)
                .multilineTextAlignment(.center)
            Text(celebration.stage.title)
                .font(.headline)
                .foregroundStyle(Color.terracotta)
            Text(celebration.message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondaryText)
            Spacer()
            Button("Wonderful") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream.ignoresSafeArea())
    }
}

#Preview("Library") {
    LibraryView()
        .modelContainer(PreviewData.container)
}

#Preview("Reader") {
    NavigationStack {
        ChapterReaderView(book: BibleCatalog.book(id: "ruth")!, chapter: 1)
    }
    .modelContainer(PreviewData.container)
}

#Preview("Book") {
    NavigationStack {
        BookView(book: BibleCatalog.book(id: "genesis")!)
            .readingDestinations()
    }
    .modelContainer(PreviewData.container)
}
