import SwiftUI
import SwiftData

/// The Object Insight Card: what a tapped object is, what built it, and what you can do next.
/// Sections only appear when they have something to show or an action to offer.
struct ObjectInsightCard: View {
    let subject: InsightSubject

    @Query private var reads: [ChapterRead]
    @Query private var quizzes: [QuizPass]
    @Query private var verses: [VerseMemorised]
    @Query private var journal: [JournalEntry]
    @Environment(\.dismiss) private var dismiss

    @State private var takingQuiz = false
    @State private var memorising = false
    @State private var reflecting = false
    @State private var writingNote = false

    init(subject: InsightSubject) {
        self.subject = subject
        let id = subject.bookID
        _reads = Query(filter: #Predicate<ChapterRead> { $0.bookID == id })
        _quizzes = Query(filter: #Predicate<QuizPass> { $0.bookID == id })
        _verses = Query(filter: #Predicate<VerseMemorised> { $0.bookID == id })
        _journal = Query(filter: #Predicate<JournalEntry> { $0.bookID == id })
    }

    private var insight: ObjectInsight {
        ObjectInsight.make(subject, reads: reads, quizzes: quizzes, verses: verses, journal: journal)
    }
    private var landmark: Landmark? { WorldData.landmark(bookID: subject.bookID) }
    private var learning: BookLearning? { LearningData.forBook(subject.bookID) }
    private var quizPassed: Bool { quizzes.contains { $0.passed } }

    var body: some View {
        let insight = insight
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if insight.totalReads > 0 { builtBy(insight) }
                    if insight.latestQuiz != nil || (learning != nil && insight.totalReads > 0) { quiz(insight) }
                    if insight.memorised != nil || (learning != nil && quizPassed) { memorised(insight) }
                    journalSection(insight)
                    NavigationLink(value: ChapterRef(bookID: subject.bookID, chapter: chapterToRead)) {
                        Label(insight.totalReads == 0 ? "Read \(subject.chapterLabel)" : "Read again", systemImage: "book")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("About this")
            .navigationBarTitleDisplayMode(.inline)
            .readingDestinations()
            .navigationDestination(for: JournalOpen.self) { open in
                JournalBookView(volume: open.volume, startAt: open.entryID)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
            }
            .sheet(isPresented: $takingQuiz) {
                if let landmark, let learning { QuizView(landmark: landmark, learning: learning) }
            }
            .sheet(isPresented: $memorising) {
                if let landmark, let learning { MemoriseView(landmark: landmark, learning: learning) }
            }
            .sheet(isPresented: $reflecting) {
                if let book = subject.book, let chapter = subject.chapters.first { ReflectionCard(book: book, chapter: chapter) }
            }
            .sheet(isPresented: $writingNote) { JournalEditor(entry: nil, bookID: subject.bookID) }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(subject.title)
                    .font(.serifTitle(.title2))
                    .foregroundStyle(Color.bodyText)
            }
            if !subject.region.isEmpty {
                Label(subject.region, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(Color.terracotta)
            }
            Text(subject.description)
                .font(.system(.body, design: .serif).italic())
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func builtBy(_ insight: ObjectInsight) -> some View {
        section("What built it") {
            Text("Built by reading \(subject.chapterLabel)")
                .font(.headline)
                .foregroundStyle(Color.bodyText)
            HStack(spacing: 10) {
                stat("\(insight.totalReads)", insight.totalReads == 1 ? "read" : "reads")
                stat("\(insight.readsThisYear)", "this year")
                if subject.isBookLevel, let book = subject.book {
                    stat("\(insight.chaptersRead)/\(book.chapterCount)", "chapters")
                }
            }
            if let first = insight.firstRead, let last = insight.lastRead {
                VStack(alignment: .leading, spacing: 2) {
                    Text("First read \(first.formatted(date: .abbreviated, time: .omitted))")
                    if last != first { Text("Last read \(last.formatted(date: .abbreviated, time: .omitted))") }
                }
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
            }
            if let depth = insight.depth {
                HStack(spacing: 8) {
                    DepthDots(depth: depth)
                    Text("Depth \(depth) of 5 · each reread adds to it")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                }
            }
        }
    }

    private func quiz(_ insight: ObjectInsight) -> some View {
        section("Quiz") {
            if let result = insight.latestQuiz {
                HStack {
                    Image(systemName: result.passed ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(result.passed ? Color.olive : Color.terracotta)
                    Text(result.total.map { "\(result.score) of \($0) · \(result.passed ? "passed" : "not passed")" }
                         ?? "Score \(result.score) · \(result.passed ? "passed" : "not passed")")
                        .foregroundStyle(Color.bodyText)
                    Spacer()
                    Text(result.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            if learning != nil, !(insight.latestQuiz?.passed ?? false) {
                Button(insight.latestQuiz == nil ? "Take quiz" : "Try the quiz again") { takingQuiz = true }
                    .buttonStyle(SoftButtonStyle())
            }
        }
    }

    private func memorised(_ insight: ObjectInsight) -> some View {
        section("Memorised") {
            if let verse = insight.memorised {
                if let text = verse.text {
                    Text("\u{201C}\(text)\u{201D}")
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(Color.bodyText)
                }
                Text("\(verse.reference) · \(verse.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            } else {
                Button("Memorise a verse") { memorising = true }
                    .buttonStyle(SoftButtonStyle())
            }
        }
    }

    private func journalSection(_ insight: ObjectInsight) -> some View {
        section("Journal") {
            ForEach(insight.journal) { entry in
                NavigationLink(value: JournalOpen(volume: volume, entryID: entry.id)) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.created.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.terracotta)
                            Text(entry.text.split(separator: "\n").first.map(String.init) ?? entry.text)
                                .font(.subheadline)
                                .foregroundStyle(Color.bodyText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.secondaryText.opacity(0.6))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button("Add a reflection") {
                if subject.isBookLevel { writingNote = true } else { reflecting = true }
            }
            .buttonStyle(SoftButtonStyle())
        }
    }

    // MARK: Helpers

    private var volume: JournalVolume {
        let n = journal.count
        return JournalVolume(id: subject.bookID, title: subject.book?.name ?? subject.bookID, count: n)
    }

    /// Chapter-level: the least-read of its chapters. Book-level: the next unread chapter.
    private var chapterToRead: Int {
        if !subject.chapters.isEmpty {
            let counts = Dictionary(grouping: reads, by: \.chapterNumber).mapValues(\.count)
            return subject.chapters.min { (counts[$0] ?? 0) < (counts[$1] ?? 0) } ?? subject.chapters[0]
        }
        let read = Set(reads.map(\.chapterNumber))
        return subject.book?.chapterNumbers.first { !read.contains($0) } ?? 1
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
            content()
        }
        .cardStyle()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(Color.bodyText)
            Text(label).font(.caption).foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(Color.sand.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Opens a journal volume at a particular page.
struct JournalOpen: Hashable {
    let volume: JournalVolume
    let entryID: UUID
}

/// Depth as five dots.
struct DepthDots: View {
    let depth: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= depth ? Color.olive : Color.stoneShade.opacity(0.5))
                    .frame(width: 9, height: 9)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Depth \(depth) of 5")
    }
}

#Preview {
    ObjectInsightCard(subject: InsightSubject(id: "preview", title: "Forest tree", region: "", description: "Grew when you read John 15.",
                                              bookID: "john", chapters: [15]))
        .modelContainer(PreviewData.container)
}
