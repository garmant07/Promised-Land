import SwiftUI
import SwiftData

/// The opening page: plain cream, and your character wandering a large patch of grass.
/// Tap the character to go into reading.
struct HomeView: View {
    @CurrentAvatar private var avatar: Avatar
    @ProgressQuery private var progress: GameProgress
    @Query private var chapterReads: [ChapterRead]
    @Query private var quizPasses: [QuizPass]
    @Query private var versesMemorised: [VerseMemorised]
    @Query private var journal: [JournalEntry]
    @State private var showingLibrary = false
    #if DEBUG
    @State private var debugReflection: ChapterRef?
    #endif
    @AppStorage(StorageKeys.hasOpenedReading) private var hasOpenedReading = false
    /// Chapters read when the garden was last seen (-1: never), so new growth can pop in.
    @AppStorage(StorageKeys.gardenSeenChapters) private var gardenSeen = -1
    @State private var revealFrom = 0
    @State private var revealID = 0
    @State private var growthNote: String?

    @State private var showingReading = false
    /// Where reading opens: nil for the library, or straight into a chapter.
    @State private var readingStart: ChapterRef?
    @State private var readingSource = "character"
    @State private var showingWorld = false
    @State private var showingCustomise = false
    @State private var showingSettings = false
    @State private var hop = false
    /// Kept alive between visits so the map doesn't rebuild each time.
    @State private var worldScene = WorldScene()
    @Namespace private var zoom

    /// Every piece of reading, in order, laid out on the island.
    private var island: Island {
        Island.build(chapters: chapterReads.map { ($0.bookID, $0.chapterNumber, $0.date) },
                     quizzes: quizPasses.map { ($0.bookID, $0.date) },
                     verses: versesMemorised.map { ($0.bookID, $0.date) })
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer(minLength: 56)
                Button(action: openReading) {
                    PlatformScene(avatar: avatar, hop: hop, island: island,
                                  revealFrom: revealFrom, revealID: revealID)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: "character", in: zoom)
                .accessibilityLabel(avatar.name.isEmpty ? "Your character" : avatar.name)
                .accessibilityHint("Opens reading")

                VStack(spacing: 4) {
                    if let growthNote {
                        Label(growthNote, systemImage: "leaf.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.olive)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                    if !avatar.name.isEmpty {
                        Text(avatar.name)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText.opacity(0.8))
                    }
                    if !hasOpenedReading {
                        Text("Tap to read")
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText.opacity(0.55))
                            .transition(.opacity)
                    }
                }
                .frame(minHeight: 40, alignment: .top)

                if let suggestion = ReadingSuggestion.make(from: progress) {
                    Button {
                        readingSource = "suggestion"
                        readingStart = suggestion.ref
                        showingReading = true
                        withAnimation { hasOpenedReading = true }
                    } label: {
                        ReadingSuggestionCard(suggestion: suggestion)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: "suggestion", in: zoom)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }
                Spacer(minLength: 16)
            }
        }
        .overlay(alignment: .topTrailing) { menu }
        .overlay(alignment: .topLeading) {
            Button { showingWorld = true } label: {
                Image(systemName: "map")
                    .font(.headline)
                    .foregroundStyle(Color.secondaryText.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.card.opacity(0.7), in: Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 8)
            .accessibilityLabel("World map")
        }
        .onAppear {
            showNewGrowth()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-openWorld") { showingWorld = true }
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-openLibrary") { showingLibrary = true }
            if args.contains("-openCustomize") { showingCustomise = true }
            if let i = args.firstIndex(of: "-openReflection"), i + 1 < args.count {
                let parts = args[i + 1].split(separator: ":")
                if parts.count == 2, let book = BibleCatalog.book(id: String(parts[0])), let ch = Int(parts[1]) {
                    debugReflection = ChapterRef(bookID: book.id, chapter: ch)
                }
            }
            if let i = args.firstIndex(of: "-openReading"), i + 1 < args.count {
                let parts = args[i + 1].split(separator: ":")
                if parts.count == 2, let chapter = Int(parts[1]) {
                    readingStart = ChapterRef(bookID: String(parts[0]), chapter: chapter)
                    readingSource = "suggestion"
                    showingReading = true
                }
            }
            #endif
        }
        .onChange(of: showingReading) { _, open in if !open { showNewGrowth() } }
        .onChange(of: showingWorld) { _, open in if !open { showNewGrowth() } }
        .onChange(of: islandItemCount) { _, _ in
            if !showingReading && !showingWorld { showNewGrowth() }
        }
        .fullScreenCover(isPresented: $showingReading) {
            LibraryView(startAt: readingStart) { showingReading = false }
                .navigationTransition(.zoom(sourceID: readingSource, in: zoom))
        }
        .fullScreenCover(isPresented: $showingWorld) {
            WorldView(scene: worldScene) { showingWorld = false }
        }
        .sheet(isPresented: $showingCustomise) { AvatarCustomizeView() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingLibrary) { LibraryShelfView() }
        #if DEBUG
        .sheet(item: $debugReflection) { ref in
            if let book = BibleCatalog.book(id: ref.bookID) { ReflectionCard(book: book, chapter: ref.chapter) }
        }
        #endif
    }

    /// One quiet button keeps the page bare.
    private var menu: some View {
        Menu {
            Button { showingCustomise = true } label: { Label("Customise character", systemImage: "person.crop.circle") }
            Button { showingWorld = true } label: { Label("World map", systemImage: "map") }
            if !journal.isEmpty {
                Button { showingLibrary = true } label: { Label("Library", systemImage: "books.vertical") }
            }
            Button { showingSettings = true } label: { Label("Settings", systemImage: "gearshape") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .foregroundStyle(Color.secondaryText.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(Color.card.opacity(0.7), in: Circle())
        }
        .padding(.trailing, 16)
        .padding(.top, 8)
        .accessibilityLabel("More")
    }

    private var islandItemCount: Int {
        chapterReads.count + quizPasses.count + versesMemorised.count
    }

    /// Pops in whatever was added to the island since it was last seen.
    private func showNewGrowth() {
        let now = island.items.count
        defer { gardenSeen = now }
        guard gardenSeen >= 0, now > gardenSeen else { return }
        let grown = now - gardenSeen
        revealFrom = gardenSeen
        revealID += 1
        withAnimation(.spring(duration: 0.4)) {
            growthNote = grown == 1 ? "Something new on your island" : "\(grown) new things on your island"
        }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.6)) { growthNote = nil }
        }
    }

    private func openReading() {
        readingSource = "character"
        readingStart = nil
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { hop = true }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { hop = false }
            showingReading = true
            withAnimation { hasOpenedReading = true }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}

// MARK: - Reading suggestion

/// What to read next: the book you're in the middle of, or a gentle suggestion.
struct ReadingSuggestion {
    enum Kind { case continuing, suggested }

    let kind: Kind
    let book: Book
    let chapter: Int
    let read: Int

    var ref: ChapterRef { ChapterRef(bookID: book.id, chapter: chapter) }

    /// First verse of the chapter if bundled, otherwise where it fits in the world.
    var preview: String {
        if let verse = SampleText.verses(book: book.id, chapter: chapter)?.first {
            return verse.text
        }
        let place = WorldData.landmark(bookID: book.id)?.name ?? book.name
        return "Builds \(place). Text coming soon — read along in your own Bible."
    }

    static func make(from progress: GameProgress) -> ReadingSuggestion? {
        func nextUnread(_ book: Book) -> Int? {
            book.chapterNumbers.first { !progress.isRead(book.id, chapter: $0) }
        }
        // 1. The book you read most recently, if it isn't finished.
        if let id = progress.newestBookID, let book = BibleCatalog.book(id: id), let next = nextUnread(book) {
            return ReadingSuggestion(kind: .continuing, book: book, chapter: next, read: progress.chaptersRead(id))
        }
        // 2. Any other book you've started.
        let started = BibleCatalog.books
            .filter { progress.chaptersRead($0.id) > 0 && nextUnread($0) != nil }
            .max { progress.fraction($0.id) < progress.fraction($1.id) }
        if let book = started, let next = nextUnread(book) {
            return ReadingSuggestion(kind: .continuing, book: book, chapter: next, read: progress.chaptersRead(book.id))
        }
        // 3. Somewhere to begin: prefer books with bundled text, starting at their first sample chapter.
        let fresh = BibleCatalog.books.filter { progress.chaptersRead($0.id) == 0 }
        guard let book = fresh.first(where: \.hasSampleText) ?? fresh.first else { return nil }
        let chapter = SampleText.chapters[book.id]?.first?.number ?? 1
        return ReadingSuggestion(kind: .suggested, book: book, chapter: chapter, read: 0)
    }
}

struct ReadingSuggestionCard: View {
    let suggestion: ReadingSuggestion

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(suggestion.kind == .continuing ? "Continue reading" : "A place to begin")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.terracotta)
                Text("\(suggestion.book.name) \(suggestion.chapter)")
                    .font(.serifTitle(.title3))
                    .foregroundStyle(Color.bodyText)
                Text(suggestion.preview)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    ProgressView(value: Double(suggestion.read), total: Double(suggestion.book.chapterCount))
                        .tint(Color.olive)
                    Text("\(suggestion.read)/\(suggestion.book.chapterCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(.top, 2)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: 360)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this chapter")
    }
}

// MARK: - Platform

/// The home island, sized to fit, with your character strolling around on it.
struct PlatformScene: View {
    let avatar: Avatar
    var hop = false
    let island: Island
    /// Items from this index onward pop in when `revealID` changes.
    var revealFrom = 0
    var revealID = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Grid position of the character's feet.
    @State private var spot = CGPoint(x: 13, y: 13)
    @State private var walkFrom = CGPoint(x: 13, y: 13)
    @State private var walkStart = Date.distantPast
    @State private var walkDuration: TimeInterval = 0
    @State private var walking = false
    @State private var facingLeft = false
    @State private var popStart = Date.distantPast
    @State private var popping = false

    var body: some View {
        GeometryReader { geo in
            let layout = IslandLayout(island: island, size: geo.size)
            let charH = min(66, max(26, layout.scale * 0.85))
            let charW = charH * 20 / 36
            let staticCount = popping ? min(revealFrom, island.items.count) : island.items.count

            ZStack(alignment: .topLeading) {
                // Everything settled is drawn once; only the character and nearby tall things redraw while walking.
                Canvas { context, _ in
                    IslandPainter.drawTiles(&context, island: island, layout: layout)
                    for item in island.items.prefix(staticCount).sorted(by: { $0.gx + $0.gy < $1.gx + $1.gy }) {
                        IslandPainter.drawItem(&context, item, layout: layout)
                    }
                }

                TimelineView(.animation(paused: !walking && !popping)) { context in
                    let now = context.date
                    let pos = position(at: now)
                    let feet = layout.point(pos.x, pos.y)
                    let t = now.timeIntervalSinceReferenceDate
                    let bounce = walking ? -abs(sin(t * 9)) * charH * 0.05 : 0
                    let lean = walking ? sin(t * 9) * 3 : 0
                    let popElapsed = now.timeIntervalSince(popStart)
                    // Stagger new things, but keep the whole reveal to a couple of seconds.
                    let popStep = min(0.1, 2.0 / Double(max(1, island.items.count - staticCount)))

                    ZStack(alignment: .topLeading) {
                        // New things popping in, and anything tall standing in front of the character.
                        Canvas { c, _ in
                            if popping {
                                for (rank, item) in island.items.enumerated().dropFirst(staticCount) {
                                    let progress = (popElapsed - Double(rank - staticCount) * popStep) / 0.45
                                    guard progress > 0 else { continue }
                                    IslandPainter.drawItem(&c, item, layout: layout, scale: progress < 1 ? Self.overshoot(progress) : 1)
                                }
                            }
                        }
                        AvatarFigure(avatar: avatar)
                            .frame(width: charW, height: charH)
                            .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
                            .rotationEffect(.degrees(lean), anchor: .bottom)
                            .offset(y: bounce + (hop ? -charH * 0.25 : 0))
                            .position(x: feet.x, y: feet.y - charH * 0.41)
                        Canvas { c, _ in
                            for item in island.items.prefix(staticCount) where item.kind.isTall {
                                guard item.gx + item.gy > pos.x + pos.y,
                                      abs((item.gx - item.gy) - (pos.x - pos.y)) < 1.6,
                                      item.gx + item.gy - (pos.x + pos.y) < 2.5 else { continue }
                                IslandPainter.drawItem(&c, item, layout: layout)
                            }
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { placeCharacter() }
        .onChange(of: island.tiles.count) { _, _ in if !walking { placeCharacter() } }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            await wander()
        }
        .onChange(of: revealID) { _, _ in startPop() }
        .accessibilityElement()
        .accessibilityLabel("Your island")
        .accessibilityValue(island.items.isEmpty ? "Bare grass" :
            "\(island.items.count) \(island.items.count == 1 ? "thing" : "things") growing")
    }

    private static func overshoot(_ t: Double) -> CGFloat {
        let c1 = 1.7, c3 = c1 + 1
        return CGFloat(1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2))
    }

    // MARK: Walking

    /// Start somewhere sensible: the middle of the island.
    private func placeCharacter() {
        guard let tile = island.tiles.first, !island.tiles.contains(where: { hypot(Double($0.x) + 0.5 - spot.x, Double($0.y) + 0.5 - spot.y) < 0.6 }) else { return }
        spot = CGPoint(x: Double(tile.x) + 0.5, y: Double(tile.y) + 0.5)
        walkFrom = spot
    }

    private func position(at date: Date) -> CGPoint {
        guard walking, walkDuration > 0 else { return spot }
        let t = min(1, max(0, date.timeIntervalSince(walkStart) / walkDuration))
        let e = t * t * (3 - 2 * t)
        return CGPoint(x: walkFrom.x + (spot.x - walkFrom.x) * e, y: walkFrom.y + (spot.y - walkFrom.y) * e)
    }

    /// Stroll to a nearby spot on the island, pause, repeat.
    private func wander() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 1.2...3.5)))
            guard !Task.isCancelled else { return }
            let nearby = island.tiles.filter { hypot(Double($0.x) + 0.5 - spot.x, Double($0.y) + 0.5 - spot.y) < 2.6 }
            guard let tile = nearby.randomElement() else { continue }
            let target = CGPoint(x: Double(tile.x) + Double.random(in: 0.2...0.8), y: Double(tile.y) + Double.random(in: 0.2...0.8))
            let distance = hypot(target.x - spot.x, target.y - spot.y)
            guard distance > 0.3 else { continue }
            facingLeft = (target.x - target.y) < (spot.x - spot.y)
            walkFrom = spot
            walkDuration = max(0.8, distance / 0.55)
            walkStart = .now
            spot = target
            walking = true
            try? await Task.sleep(for: .seconds(walkDuration))
            walking = false
        }
    }

    private func startPop() {
        let count = island.items.count - revealFrom
        guard count > 0, !reduceMotion else { return }
        popStart = .now
        popping = true
        let duration = min(0.1, 2.0 / Double(count)) * Double(count) + 0.6
        Task {
            try? await Task.sleep(for: .seconds(duration))
            popping = false
        }
    }
}

#Preview("Platform") {
    PlatformScene(avatar: .default, island: .empty)
        .padding()
        .background(Color.cream)
}
