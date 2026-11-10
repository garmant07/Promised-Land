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
          ScrollViewReader { proxy in
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
                    .id("top")
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
            .debugAutoScroll(proxy, to: WorldData.landmarks.last(where: { $0.book != nil })?.id)
          }
            .debugOpenTiming("Read")
            .debugOpenBook($path)
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
    @Environment(\.bibleService) private var bible

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
                    if !bible.isLive && book.hasSampleText {
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
    @Environment(\.bibleService) private var bible

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
                if !bible.isLive && !book.hasSampleText {
                    Label("Connect to the internet to load chapters of \(book.name). You can also choose “I read this in my own Bible” in any chapter and answer a quick question.",
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
        .debugOpenTiming("Book")
        .navigationTitle(book.name)
    }

    private func chapterCell(_ number: Int) -> some View {
        let isRead = progress.isRead(book.id, chapter: number)
        let hasText = bible.hasText(bookID: book.id, chapter: number)
        // With live text every chapter has text: no dots needed.
        let showDot = hasText && !bible.isLive
        return Text("\(number)")
            .font(.headline.monospacedDigit())
            .foregroundStyle(isRead ? Color.onPrimary : Color.bodyText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isRead ? Color.olive : (showDot ? Color.sand : Color.card),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if showDot && !isRead {
                    Circle().fill(Color.terracotta).frame(width: 7, height: 7).padding(6)
                }
            }
            .overlay(alignment: .bottom) {
                // One dot per read, up to five.
                let reads = min(5, progress.readCount(book.id, chapter: number))
                if reads > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<reads, id: \.self) { _ in Circle().fill(Color.onPrimary.opacity(0.85)).frame(width: 4, height: 4) }
                    }
                    .padding(.bottom, 5)
                }
            }
            .accessibilityLabel("Chapter \(number), \(isRead ? "read \(progress.readCount(book.id, chapter: number)) \(progress.readCount(book.id, chapter: number) == 1 ? "time" : "times")" : "not read")\(hasText ? ", text available" : "")")
    }
}

// MARK: - Reader

struct ChapterReaderView: View {
    let book: Book
    let chapter: Int

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.closeReading) private var closeReading
    @Query private var reads: [ChapterRead]
    @State private var deepDive: (dive: DeepDive, text: String)?
    @AppStorage(StorageKeys.readingStrictness) private var strictnessRaw = ""
    @AppStorage(StorageKeys.ageGroup) private var ageGroup = ""
    @Environment(\.bibleService) private var bible
    private var translation = TranslationChoice()
    @State private var loader = ChapterLoader()
    #if DEBUG
    @AppStorage("debug.apiOverlay") private var showsAPIUsage = true
    #endif

    /// The reading gate (reach the last page, and spend the chapter's reading time). Owned by
    /// `ReadingSessions`, not this view, so nothing here can recreate or reset it. Time counts only
    /// while the text is on screen: loaded, this page in front, nothing over it, and the app open.
    private let session: ReadingSession
    @State private var onScreen = false
    @State private var asking = false
    @State private var ownBible: ChapterRef?
    @State private var counted = false

    init(book: Book, chapter: Int) {
        self.book = book
        self.chapter = chapter
        self.session = ReadingSessions.shared.session(bookID: book.id, chapter: chapter)
        let id = book.id
        _reads = Query(filter: #Predicate<ChapterRead> { $0.bookID == id && $0.chapterNumber == chapter },
                       sort: \ChapterRead.date, order: .reverse)
    }

    private var isRead: Bool { !reads.isEmpty }
    /// A read from before the reading gate, still waiting for its quick check.
    private var needsCheck: Bool { reads.first.map { !$0.checked } ?? false }
    private var strictness: ReadingStrictness { .current(stored: strictnessRaw, ageGroup: ageGroup) }

    var body: some View {
        Group {
            switch loader.state {
            case .loading:
                ProgressView("Opening \(book.name) \(chapter)…")
                    .tint(Color.primaryBrown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let text):
                PageReaderView(title: "\(book.name) \(chapter)", verses: text.verses,
                               deepDive: { DeepDiveData.entry(bookID: book.id, chapter: chapter, verse: $0.number) },
                               onDeepDive: { dive, verse in deepDive = (dive, verse.text) },
                               onReachedEnd: { session.markReachedEnd() }, footerHeight: 330) {
                    VStack(spacing: 10) {
                        actions(compact: true)
                        textNotice(text)
                    }
                }
                .padding(.bottom, 4)
            case .failed(let error):
                ChapterUnavailableView(title: "\(book.name) \(chapter)", error: error, retry: { Task { await load() } }) {
                    actions(compact: false)
                }
            case .ownBible:
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("\(book.name) \(chapter)")
                            .font(.serifTitle(.largeTitle))
                            .foregroundStyle(Color.bodyText)
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Read it in your own Bible", systemImage: "book.closed")
                                .font(.headline)
                                .foregroundStyle(Color.primaryBrown)
                            Text("This chapter's text isn't available on this device. Connect to the internet to load it, or read it in your own Bible. Then choose “I read this in my own Bible” and answer a quick question or reflection to build your island.")
                                .foregroundStyle(Color.secondaryText)
                            #if DEBUG
                            if !bible.isLive {
                                // Developers: most chapters have no text until an API.Bible key is set.
                                Label("DEBUG: no API.Bible key is set, so only the bundled sample chapters have text. Put your key in Secrets.xcconfig (see README) and run again.",
                                      systemImage: "key")
                                    .font(.footnote)
                                    .foregroundStyle(Color.terracotta)
                            }
                            #endif
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
        .toolbar { ToolbarItem(placement: .topBarTrailing) { TranslationMenu() } }
        #if DEBUG
        .overlay(alignment: .top) { if showsAPIUsage && bible.isLive { APIUsageBadge().allowsHitTesting(false) } }
        #endif
        .task(id: translation.current) { await load() }
        .onAppear { context.recordBookStarted(book.id) }
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
        .onChange(of: loader.text, initial: true) { _, text in
            if let text { session.setText(text, strictness: strictness) }
        }
        .onChange(of: strictness) { _, new in session.setStrictness(new) }
        .onChange(of: isReading, initial: true) { _, reading in
            session.setRunning(reading)
            #if DEBUG
            print("READER \(book.id) \(chapter): timer \(reading ? "running" : "paused") at \(Int(session.elapsed(at: .now)))s of \(Int(session.requiredSeconds))s (\(session.words ?? 0) words)")
            #endif
        }
        // The one ticker: about once a second while the time runs, then it stops.
        .task(id: isReading) {
            guard isReading else { return }
            while !Task.isCancelled && !session.timeUp {
                let wait = min(1, max(0.05, session.secondsToNextTick() + 0.02))
                try? await Task.sleep(for: .seconds(wait))
                session.tick()
            }
        }
        .sheet(isPresented: $asking) {
            ReadingQuestionView(book: book, chapter: chapter, onCounted: { countRead() }, onLookAgain: { asking = false })
        }
        .sheet(item: $ownBible) { ref in
            ReadingQuestionView(book: book, chapter: ref.chapter, onCounted: {
                context.recordRead(ref.bookID, ref.chapter, checked: true)
                ownBible = nil
                finishedReading()
            }, onLookAgain: { ownBible = nil })
        }
        .sheet(isPresented: Binding(get: { deepDive != nil }, set: { if !$0 { deepDive = nil } })) {
            if let deepDive { DeepDiveSheet(dive: deepDive.dive, verseText: deepDive.text) }
        }
    }

    private func load() async {
        await loader.load(bible, bookID: book.id, chapter: chapter, translation: translation.current)
    }

    /// At the bottom of every chapter: the translation's copyright, and a note when the text is
    /// an old copy or the bundled sample.
    private func textNotice(_ text: ChapterText) -> some View {
        VStack(spacing: 4) {
            switch text.origin {
            case .staleCache:
                Label("Saved copy (couldn't refresh it just now)", systemImage: "clock.arrow.circlepath")
            case .bundled where bible.isLive:
                Label("You're offline: showing the bundled sample", systemImage: "wifi.slash")
            default:
                EmptyView()
            }
            Text(text.copyright)
                .multilineTextAlignment(.center)
        }
        .font(.caption2)
        .foregroundStyle(Color.secondaryText)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The chapter's text is actually being read: loaded and on screen, nothing covering it, and
    /// the app in the foreground.
    private var isReading: Bool {
        onScreen && scenePhase == .active && loader.text != nil && !asking && ownBible == nil && deepDive == nil && !counted
    }

    /// Finish (after the gate), "I read this in my own Bible", what's been read, and the next chapter.
    @ViewBuilder
    private func actions(compact: Bool) -> some View {
        let hasText = loader.text != nil
        VStack(spacing: compact ? 6 : 10) {
            if counted {
                Label("Counted! Your island is growing.", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(Color.olive)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else if hasText {
                SessionFinishButton(session: session, readBefore: isRead) { asking = true }
            }
            if !counted {
                Button { ownBible = ChapterRef(bookID: book.id, chapter: chapter) } label: {
                    Label("I read this in my own Bible", systemImage: "book.closed")
                }
                    .buttonStyle(hasText ? AnyButtonStyle(SoftButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))
            }
            if isRead {
                let count = reads.filter(\.checked).count
                if count > 0 {
                    Label(count == 1 ? "You've read this chapter" : "You've read this chapter \(count) times",
                          systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.olive)
                }
                if needsCheck {
                    Button { asking = true } label: {
                        Label("Answer the question to count your earlier read", systemImage: "questionmark.circle")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Color.primaryBrown)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                Button("Undo last read") { withAnimation { context.undoLastRead(book.id, chapter) } }
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                    .frame(minHeight: 44)
            }
            if chapter < book.chapterCount {
                NavigationLink(value: ChapterRef(bookID: book.id, chapter: chapter + 1)) {
                    Text("Next: chapter \(chapter + 1)")
                }
                .buttonStyle(SoftButtonStyle())
            }
        }
    }

    /// The question was answered: the chapter counts.
    private func countRead() {
        if needsCheck {
            context.markLatestChecked(book.id, chapter)
        } else {
            context.recordRead(book.id, chapter, checked: true)
        }
        asking = false
        finishedReading()
    }

    /// Back to the island, where the new piece is built.
    private func finishedReading() {
        withAnimation { counted = true }
        session.reset()
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            closeReading?()
        }
    }
}

/// Mark complete, driven by the chapter's reading session. Its own view, so the once-a-second
/// countdown redraws only this button, not the pages around it.
private struct SessionFinishButton: View {
    let session: ReadingSession
    let readBefore: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            FinishButton(progress: session.progress, enabled: session.canFinish,
                         remaining: Double(session.secondsLeft), readBefore: readBefore, action: action)
                // The ring moves once a second; easing each step keeps it smooth.
                .animation(.linear(duration: 1), value: session.progress)
            #if DEBUG
            // Developers: check the required time against the chapter's length.
            Text("DEBUG: \(session.words ?? 0) words → \(Int(session.requiredSeconds))s required (\(session.strictness.title))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Color.secondaryText)
            #endif
        }
    }
}

/// Lets two different button styles be chosen at runtime.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
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
