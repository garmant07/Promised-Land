import SwiftUI
import SwiftData

/// The opening page: plain cream, and your character wandering a large patch of grass.
/// Tap the character to go into reading.
struct HomeView: View {
    private let avatarStorage = AvatarStorage()
    @ProgressQuery private var progress: GameProgress
    @AppStorage(StorageKeys.hasOpenedReading) private var hasOpenedReading = false

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

    var body: some View {
        let avatar = avatarStorage.avatar
        ZStack {
            Color.cream.ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer(minLength: 56)
                Button(action: openReading) {
                    PlatformScene(avatar: avatar, hop: hop)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: "character", in: zoom)
                .accessibilityLabel(avatar.name.isEmpty ? "Your character" : avatar.name)
                .accessibilityHint("Opens reading")

                VStack(spacing: 4) {
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
        .fullScreenCover(isPresented: $showingReading) {
            LibraryView(startAt: readingStart) { showingReading = false }
                .navigationTransition(.zoom(sourceID: readingSource, in: zoom))
        }
        .fullScreenCover(isPresented: $showingWorld) {
            WorldView(scene: worldScene) { showingWorld = false }
        }
        .sheet(isPresented: $showingCustomise) { AvatarCustomizeView() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    /// One quiet button keeps the page bare.
    private var menu: some View {
        Menu {
            Button { showingCustomise = true } label: { Label("Customise character", systemImage: "person.crop.circle") }
            Button { showingWorld = true } label: { Label("World map", systemImage: "map") }
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

/// The grass platform, sized to the screen, with the character strolling around on it.
struct PlatformScene: View {
    let avatar: Avatar
    var hop = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Position on the platform's top face, as (a, b) in 0...1 along its two edges.
    @State private var spot = CGPoint(x: 0.5, y: 0.5)
    @State private var walking = false
    @State private var facingLeft = false

    /// Fraction of the plot's height taken by the earth sides (matches GrassPlot).
    private let sideFraction: CGFloat = 0.16

    var body: some View {
        GeometryReader { geo in
            let plotW = min(geo.size.width, 460)
            let plotH = plotW * 0.59
            let topH = plotH * (1 - sideFraction)
            let charH = plotW * 0.21
            let charW = charH * 20 / 36
            // Where the feet touch the grass, in the platform's coordinates.
            let feet = CGPoint(x: plotW / 2 + (spot.x - spot.y) * plotW / 2,
                               y: (spot.x + spot.y) * topH / 2)
            let originY = (geo.size.height - plotH) / 2 + charH * 0.35

            ZStack(alignment: .topLeading) {
                GrassPlot()
                    .frame(width: plotW, height: plotH)
                    .offset(y: originY)

                TimelineView(.animation(paused: !walking)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let bounce = walking ? -abs(sin(t * 9)) * charH * 0.05 : 0
                    let lean = walking ? sin(t * 9) * 3 : 0
                    AvatarFigure(avatar: avatar)
                        .frame(width: charW, height: charH)
                        .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
                        .rotationEffect(.degrees(lean), anchor: .bottom)
                        .offset(y: bounce + (hop ? -charH * 0.25 : 0))
                }
                .frame(width: charW, height: charH)
                // Place the figure so its feet (about 91% down the frame) stand on the spot.
                .position(x: feet.x, y: originY + feet.y - charH * 0.41)
            }
            .frame(width: plotW, height: geo.size.height)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1.2, contentMode: .fit)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            await wander()
        }
    }

    /// Walk to a random spot, pause, repeat.
    private func wander() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 1.2...3.5)))
            guard !Task.isCancelled else { return }
            var target = spot
            for _ in 0..<10 {
                let candidate = CGPoint(x: CGFloat.random(in: 0.18...0.82), y: CGFloat.random(in: 0.18...0.82))
                let d = hypot(candidate.x - spot.x, candidate.y - spot.y)
                if d > 0.15 && d < 0.5 { target = candidate; break }
            }
            let distance = hypot(target.x - spot.x, target.y - spot.y)
            guard distance > 0.01 else { continue }
            let duration = Double(distance) / 0.11
            facingLeft = (target.x - target.y) < (spot.x - spot.y)
            walking = true
            withAnimation(.linear(duration: duration)) { spot = target }
            try? await Task.sleep(for: .seconds(duration))
            walking = false
        }
    }
}

#Preview("Platform") {
    PlatformScene(avatar: AvatarStorage().avatar)
        .padding()
        .background(Color.cream)
}
