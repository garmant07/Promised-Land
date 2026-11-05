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
    private var spec: BuildingSpec { BuildingData.spec(for: bookID) }

    /// Reads per chapter.
    private var counts: [Int: Int] { Dictionary(reads.map { ($0.chapterNumber, 1) }, uniquingKeysWith: +) }
    /// Whole-book reads (0 until finished).
    private var fullReads: Int {
        guard let book, counts.count >= book.chapterCount else { return 0 }
        return (1...book.chapterCount).map { counts[$0] ?? 0 }.min() ?? 0
    }

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
                    charactersSection
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
            InteriorHeaderArt(spec: spec, progress: counts.count, total: book?.chapterCount ?? 1, fullReads: fullReads)
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
        var item = Island.Item(kind: .building(bookID), gx: 0, gy: 0, seed: 0)
        item.progress = counts.count
        item.total = book.chapterCount
        item.level = fullReads
        return InsightSubject.buildingText(item, book: book)
    }

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
                Text("Each chapter places something on the plot; rereads grow it. Tap a chapter to read it.")
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
                                     artwork: InteriorHeaderArt(spec: spec, progress: counts.count, total: book?.chapterCount ?? 1, fullReads: fullReads)
                                        .background(Earthy.groundLight),
                                     avatar: avatar, streak: progress.streak, chaptersThisYear: progress.chaptersReadThisYear)
        if let image { sharing = ShareImage(image: image) }
    }

    // MARK: Characters

    private var charactersSection: some View {
        let here = CharacterUnlocks.visible.filter { $0.books.contains(bookID) }
        let finished = Set(BibleCatalog.books.filter { progress.chaptersRead($0.id) >= $0.chapterCount }.map(\.id))
        let unlocked = Set(CharacterUnlocks.unlocked(finishedBooks: finished, completedJourneys: Set(progress.completedJourneys.map(\.id))).map(\.id))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Who lives here")
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
            if here.isEmpty {
                Text("No character is tied to this book yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
            ForEach(here) { c in
                let isHere = unlocked.contains(c.id)
                HStack(spacing: 12) {
                    CharacterFigure(id: c.id, look: c.look)
                        .frame(width: 54, height: 70)
                        .saturation(isHere ? 1 : 0)
                        .opacity(isHere ? 1 : 0.35)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(c.name).font(.headline).foregroundStyle(Color.bodyText)
                            Text(c.rarity.title).font(.caption2.weight(.bold)).foregroundStyle(Color.secondaryText)
                            DraftBadge(item: c)
                        }
                        Text(isHere ? c.line : c.unlockText + " to welcome them.")
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }
        }
        .cardStyle()
    }
}

/// The building, drawn large on its plot of sand, for the top of its inside page.
struct InteriorHeaderArt: View {
    let spec: BuildingSpec
    let progress: Int
    let total: Int
    let fullReads: Int

    var body: some View {
        Canvas { c, size in
            let u = min(size.width / 120, size.height / 82)
            let ground = CGPoint(x: size.width / 2, y: size.height * 0.68)
            var g = c
            g.translateBy(x: ground.x, y: ground.y)
            // A plot of sand with soft earth sides.
            let pen = IsoPen(c: g, u: u)
            let r: CGFloat = 1.05
            let corners = [pen.p(-r, -r), pen.p(r, -r), pen.p(r, r), pen.p(-r, r)]
            let down = 7 * u
            pen.fill([corners[3], corners[2], CGPoint(x: corners[2].x, y: corners[2].y + down), CGPoint(x: corners[3].x, y: corners[3].y + down)], Earthy.strataLeftTop, soft: 2)
            pen.fill([corners[2], corners[1], CGPoint(x: corners[1].x, y: corners[1].y + down), CGPoint(x: corners[2].x, y: corners[2].y + down)], Earthy.strataRightTop, soft: 2)
            pen.fill(corners, Earthy.ground, soft: 2)
            BuildingArt.draw(pen, spec: spec, progress: progress, total: total, extraFloors: max(0, fullReads - 1), seed: Island.hash(spec.bookID))
        }
    }
}

#Preview {
    InteriorView(bookID: "ruth") {}
        .modelContainer(PreviewData.container)
}
