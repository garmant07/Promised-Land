import SwiftUI
import SwiftData

/// Inside a book's building: the chapters that built it, its quiz and verse, your journal
/// entries, and the characters who belong there. Opened by tapping a building on the island
/// (your character walks to the door first).
struct InteriorView: View {
    let bookID: String
    var onClose: () -> Void

    @Query private var reads: [ChapterRead]
    @Query private var quizzes: [QuizPass]
    @Query private var verses: [VerseMemorised]
    @Query private var journal: [JournalEntry]
    @ProgressQuery private var progress: GameProgress
    @State private var reading: ChapterRef?
    @State private var learningScreen: LearningScreen?
    @State private var reflecting = false
    @State private var sharing: ShareImage?
    @CurrentAvatar private var avatar: Avatar

    private enum LearningScreen: String, Identifiable {
        case quiz, memorise
        var id: String { rawValue }
    }

    init(bookID: String, onClose: @escaping () -> Void) {
        self.bookID = bookID
        self.onClose = onClose
        _reads = Query(filter: #Predicate<ChapterRead> { $0.bookID == bookID })
        _quizzes = Query(filter: #Predicate<QuizPass> { $0.bookID == bookID })
        _verses = Query(filter: #Predicate<VerseMemorised> { $0.bookID == bookID })
        _journal = Query(filter: #Predicate<JournalEntry> { $0.bookID == bookID }, sort: \JournalEntry.created, order: .reverse)
    }

    private var book: Book? { BibleCatalog.book(id: bookID) }
    private var landmark: Landmark? { WorldData.landmark(bookID: bookID) }

    /// Reads per chapter.
    private var counts: [Int: Int] { Dictionary(reads.map { ($0.chapterNumber, 1) }, uniquingKeysWith: +) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    chaptersSection
                    learningSection
                    if let book {
                        InteriorJournalSection(book: book, entries: journal) { reflecting = true }
                    }
                    InteriorCharactersSection(bookID: bookID)
                }
                .padding(16)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .themedScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { share() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                        .tint(Color.primaryBrown)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { onClose() } label: { Label("Back to the island", systemImage: "chevron.backward") }
                        .tint(Color.primaryBrown)
                }
            }
            .navigationDestination(for: JournalOpen.self) { open in
                JournalBookView(volume: open.volume, startAt: open.entryID)
            }
            .sheet(isPresented: $reflecting) {
                if let book { ReflectionCard(book: book, chapter: latestChapter) }
            }
            .sheet(item: $sharing) { SharePreviewSheet(image: $0.image) }
            .sheet(item: $reading) { ref in
                LibraryView(startAt: ref, onClose: { reading = nil })
                    .readingSizing(true)
            }
            .sheet(item: $learningScreen) { screen in
                if let landmark, let learning = LearningData.forBook(bookID) {
                    NavigationStack {
                        Group {
                            switch screen {
                            case .quiz: QuizView(landmark: landmark, learning: learning)
                            case .memorise: MemoriseView(landmark: landmark, learning: learning)
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("Done") { learningScreen = nil }.tint(Color.primaryBrown) }
                        }
                    }
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            InteriorHeaderArt(bookID: bookID, distinct: counts.count, totalReads: totalChecked)
                .frame(height: 230)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [Earthy.sky, Earthy.groundLight], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityHidden(true)
            if let region = landmark?.region?.name {
                Text(region.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.terracotta)
            }
            Text(landmark?.name ?? book?.name ?? bookID)
                .font(.serifTitle(.largeTitle))
                .foregroundStyle(Color.bodyText)
                .multilineTextAlignment(.center)
            if let book {
                Text(statusText(book))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statusText(_ book: Book) -> String {
        InsightSubject.placeText(bookID: bookID, read: counts.count, total: book.chapterCount,
                                 richness: PlaceGrowth.richness(totalReads: totalChecked, chapters: book.chapterCount))
    }

    /// Checked reads of this book (the ones that build).
    private var totalChecked: Int { reads.filter(\.checked).count }

    // MARK: Chapters

    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The chapters that built it")
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
            if let book {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
                    ForEach(1...book.chapterCount, id: \.self) { chapter in
                        let n = counts[chapter] ?? 0
                        Button { reading = ChapterRef(bookID: bookID, chapter: chapter) } label: {
                            VStack(spacing: 2) {
                                Text("\(chapter)").font(.headline.monospacedDigit())
                                Text(n == 0 ? "Read" : n == 1 ? "read" : "×\(n)")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(n > 0 ? Color.primaryBrown : Color.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(n > 0 ? Color.wheat.opacity(0.45) : Color.card,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(n == 0 ? "Read chapter \(chapter)" : "Chapter \(chapter), read \(n) \(n == 1 ? "time" : "times"). Read again")
                    }
                }
                Text("Every chapter adds something to this Place; rereads make it richer. Tap a chapter to read it.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .cardStyle()
    }

    // MARK: Quiz and verse

    private var learningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quiz and verse")
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
            if let learning = LearningData.forBook(bookID) {
                let latest = quizzes.max { $0.date < $1.date }
                statusRow(icon: "flag.fill",
                          title: latest == nil ? "Quiz not taken yet" : latest!.passed ? "Quiz passed: a banner flies here" : "Quiz tried, not passed yet",
                          detail: latest.map { "\($0.score) of \(learning.quiz.count) · \($0.date.formatted(date: .abbreviated, time: .omitted))" },
                          action: latest?.passed == true ? "Retake" : "Take the quiz") { learningScreen = .quiz }
                let memo = verses.max { $0.date < $1.date }
                statusRow(icon: RewardData.verse(for: bookID) == .lantern ? "lamp.desk.fill" : "leaf.fill",
                          title: memo == nil ? "Verse not memorised yet" : "Verse memorised",
                          detail: learning.memoryVerse.reference,
                          action: memo == nil ? "Memorise" : "Practise") { learningScreen = .memorise }
            } else {
                Text("No quiz or verse for this book yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .cardStyle()
    }

    private func statusRow(icon: String, title: String, detail: String?, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.terracotta)
                .frame(width: 32, height: 32)
                .background(Color.sand, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.bodyText)
                if let detail { Text(detail).font(.footnote).foregroundStyle(Color.secondaryText) }
            }
            Spacer(minLength: 8)
            Button(action, action: perform)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primaryBrown)
                .frame(minHeight: 44)
        }
    }

    // MARK: Journal

    /// The chapter most recently read (for a new reflection), or the first.
    private var latestChapter: Int { reads.max { $0.date < $1.date }?.chapterNumber ?? 1 }

    private func share() {
        let name = landmark?.name ?? book?.name ?? bookID
        let subtitle = book.map { counts.count >= $0.chapterCount ? "Built by reading \($0.name)" : "\(counts.count) of \($0.chapterCount) chapters of \($0.name)" } ?? ""
        let image = ShareRender.card(title: name, subtitle: subtitle,
                                     artwork: InteriorHeaderArt(bookID: bookID, distinct: counts.count, totalReads: totalChecked)
                                        .background(Earthy.groundLight),
                                     avatar: avatar, streak: progress.streak, chaptersThisYear: progress.chaptersReadThisYear)
        if let image { sharing = ShareImage(image: image) }
    }

}

/// The Place, drawn large on its own patch of land, for the top of its inside page.
struct InteriorHeaderArt: View {
    let bookID: String
    let distinct: Int
    let totalReads: Int

    var body: some View {
        // Hand-made interior art (`int_<bookID>`) replaces the drawing when present.
        if let art = ArtAssets.image("int_\(bookID)") {
            Image(decorative: art.image, scale: 1).resizable().scaledToFit()
        } else {
            IslandPicture(island: .single(bookID: bookID, distinct: max(1, distinct), totalReads: totalReads))
        }
    }
}

#Preview {
    InteriorView(bookID: "ruth") {}
        .modelContainer(PreviewData.container)
}
