import SwiftUI
import SwiftData

/// The opening page: plain cream, and your character wandering a large patch of grass.
/// Tap the character to go into reading.
struct HomeView: View {
    private let avatarStorage = AvatarStorage()
    @ProgressQuery private var progress: GameProgress
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

    var body: some View {
        let avatar = avatarStorage.avatar
        ZStack {
            Color.cream.ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer(minLength: 56)
                Button(action: openReading) {
                    PlatformScene(avatar: avatar, hop: hop, chapters: progress.totalChaptersRead,
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
        .onAppear {
            showNewGrowth()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-openWorld") { showingWorld = true }
            #endif
        }
        .onChange(of: showingReading) { _, open in if !open { showNewGrowth() } }
        .onChange(of: showingWorld) { _, open in if !open { showNewGrowth() } }
        .onChange(of: progress.totalChaptersRead) { _, _ in
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

    /// Pops in whatever grew since the garden was last seen.
    private func showNewGrowth() {
        let now = progress.totalChaptersRead
        defer { gardenSeen = now }
        guard gardenSeen >= 0, now > gardenSeen else { return }
        let grown = now - gardenSeen
        revealFrom = gardenSeen
        revealID += 1
        withAnimation(.spring(duration: 0.4)) {
            growthNote = grown == 1 ? "Something new is growing" : "\(grown) chapters of new growth"
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

/// The grass garden: every chapter read grows something on it, in a fixed order.
enum Garden {
    struct Slot { let a: CGFloat; let b: CGFloat; let hue: Int }

    /// 49 spots spread over the grass (a jittered 7×7 grid), in a fixed shuffled order
    /// so growth is scattered rather than filling row by row.
    static let slots: [Slot] = {
        var rng = SeededRandom(seed: 2024)
        var result: [Slot] = []
        for row in 0..<7 {
            for col in 0..<7 {
                let a = 0.1 + (CGFloat(col) + CGFloat.random(in: 0.2...0.8, using: &rng)) / 7 * 0.8
                let b = 0.1 + (CGFloat(row) + CGFloat.random(in: 0.2...0.8, using: &rng)) / 7 * 0.8
                result.append(Slot(a: a, b: b, hue: Int.random(in: 0..<4, using: &rng)))
            }
        }
        return result.shuffled(using: &rng)
    }()

    /// How grown slot `k` is after `chapters` chapters: chapter i grows slot i % 49.
    static func level(of k: Int, chapters: Int) -> Int {
        chapters / slots.count + (k < chapters % slots.count ? 1 : 0)
    }

    /// The slots grown by chapters `from..<to`, in the order they grew.
    static func slotsGrown(from: Int, to: Int) -> [Int] {
        guard to > from else { return [] }
        var seen = Set<Int>(), order: [Int] = []
        for i in from..<to where seen.insert(i % slots.count).inserted { order.append(i % slots.count) }
        return order
    }
}

/// The grass platform, sized to the screen, with the garden and the character strolling around on it.
struct PlatformScene: View {
    let avatar: Avatar
    var hop = false
    /// Total chapters read: one more thing grows for each.
    var chapters = 0
    /// Chapters from this count onward pop in when `revealID` changes.
    var revealFrom = 0
    var revealID = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Position on the platform's top face, as (a, b) in 0...1 along its two edges.
    @State private var spot = CGPoint(x: 0.5, y: 0.5)
    @State private var walkFrom = CGPoint(x: 0.5, y: 0.5)
    @State private var walkStart = Date.distantPast
    @State private var walkDuration: TimeInterval = 0
    @State private var walking = false
    @State private var facingLeft = false
    @State private var popStart = Date.distantPast
    @State private var popping = false

    private let sideFraction: CGFloat = 0.16 // matches GrassPlot

    var body: some View {
        GeometryReader { geo in
            let plotW = min(geo.size.width, 460)
            let plotH = plotW * 0.59
            let topH = plotH * (1 - sideFraction)
            let charH = plotW * 0.21
            let charW = charH * 20 / 36
            let originY = (geo.size.height - plotH) / 2 + charH * 0.35

            TimelineView(.animation(paused: !walking && !popping)) { context in
                let now = context.date
                let pos = position(at: now)
                let feet = point(pos, plotW: plotW, topH: topH)
                let t = now.timeIntervalSinceReferenceDate
                let bounce = walking ? -abs(sin(t * 9)) * charH * 0.05 : 0
                let lean = walking ? sin(t * 9) * 3 : 0

                ZStack(alignment: .topLeading) {
                    GrassPlot()
                        .frame(width: plotW, height: plotH)
                    garden(behind: true, feetY: feet.y, plotW: plotW, topH: topH, now: now)
                        .frame(width: plotW, height: plotH)
                    AvatarFigure(avatar: avatar)
                        .frame(width: charW, height: charH)
                        .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
                        .rotationEffect(.degrees(lean), anchor: .bottom)
                        .offset(y: bounce + (hop ? -charH * 0.25 : 0))
                        .position(x: feet.x, y: feet.y - charH * 0.41)
                    garden(behind: false, feetY: feet.y, plotW: plotW, topH: topH, now: now)
                        .frame(width: plotW, height: plotH)
                }
                .frame(width: plotW, height: plotH)
                .offset(y: originY)
            }
            .frame(width: plotW, height: geo.size.height, alignment: .top)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1.2, contentMode: .fit)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            await wander()
        }
        .onChange(of: revealID) { _, _ in startPop() }
        .accessibilityElement()
        .accessibilityLabel("Your garden")
        .accessibilityValue(chapters == 0 ? "Bare grass" : "\(chapters) \(chapters == 1 ? "thing" : "things") growing")
    }

    // MARK: Garden drawing

    /// Items in front of the character (lower on screen) draw over it; the rest behind.
    private func garden(behind: Bool, feetY: CGFloat, plotW: CGFloat, topH: CGFloat, now: Date) -> some View {
        let order = Garden.slotsGrown(from: revealFrom, to: chapters)
        let popElapsed = now.timeIntervalSince(popStart)
        return Canvas { context, _ in
            let u = plotW / 360
            var items: [(CGPoint, Int, Int, CGFloat)] = []
            for (k, slot) in Garden.slots.enumerated() {
                let level = Garden.level(of: k, chapters: chapters)
                guard level > 0 else { continue }
                let p = point(CGPoint(x: slot.a, y: slot.b), plotW: plotW, topH: topH)
                guard (p.y <= feetY) == behind else { continue }
                var scale: CGFloat = 1
                var shownLevel = level
                if let rank = order.firstIndex(of: k) {
                    let progress = (popElapsed - Double(rank) * 0.12) / 0.45
                    if progress < 0 { shownLevel = level - 1; scale = 1 } // not yet: show previous growth
                    else if progress < 1 { scale = Self.overshoot(CGFloat(progress)) }
                }
                guard shownLevel > 0 else { continue }
                items.append((p, shownLevel, slot.hue, scale))
            }
            for (p, level, hue, scale) in items.sorted(by: { $0.0.y < $1.0.y }) {
                var c = context
                c.translateBy(x: p.x, y: p.y)
                c.scaleBy(x: scale, y: scale)
                Self.drawGrowth(&c, level: level, hue: hue, u: u)
            }
        }
        .allowsHitTesting(false)
    }

    private static func overshoot(_ t: CGFloat) -> CGFloat {
        let c1: CGFloat = 1.7, c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }

    /// Draws one garden item at the origin (its base), growing with `level`:
    /// tuft → flower → flowers → bush → sapling → olive tree → fruit, one more per chapter.
    private static func drawGrowth(_ c: inout GraphicsContext, level: Int, hue: Int, u: CGFloat) {
        let petals: [Color] = [.terracotta, .lavender, .wheat, .cream]
        let petal = petals[hue % petals.count]
        func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
            c.fill(Path(ellipseIn: CGRect(x: (x - w / 2) * u, y: (y - h / 2) * u, width: w * u, height: h * u)), with: .color(color))
        }
        func stem(_ x: CGFloat, _ height: CGFloat) {
            c.fill(Path(roundedRect: CGRect(x: (x - 0.4) * u, y: -height * u, width: 0.8 * u, height: height * u), cornerRadius: 0.4 * u),
                   with: .color(Color.olive))
        }
        func flower(_ x: CGFloat, _ y: CGFloat, _ color: Color) {
            stem(x, 4 - y)
            ellipse(x, y - 4.4, 2.8, 2.6, color)
        }
        func tree(canopy: CGFloat, trunk: CGFloat) {
            ellipse(0, 0.5, canopy * 0.9, canopy * 0.35, Color.primaryBrown.opacity(0.10))
            c.fill(Path(roundedRect: CGRect(x: -trunk * 0.12 * u, y: -trunk * u, width: trunk * 0.24 * u, height: trunk * u),
                        cornerRadius: trunk * 0.12 * u), with: .color(Color(hex: "#A9805C")))
            ellipse(canopy * 0.12, -trunk - canopy * 0.28, canopy, canopy * 0.82, Color(hex: "#929E66"))
            ellipse(-canopy * 0.08, -trunk - canopy * 0.36, canopy * 0.95, canopy * 0.8, .olive)
        }

        switch level {
        case 1:
            ellipse(-1.4, 0, 4.6, 2.2, Color.olive.opacity(0.85))
            ellipse(1.6, -0.4, 4, 2, Color(hex: "#929E66").opacity(0.8))
        case 2:
            ellipse(0, 0.2, 4.6, 2, Color.olive.opacity(0.7))
            flower(0, 0, petal)
        case 3:
            ellipse(0, 0.4, 8, 2.6, Color.olive.opacity(0.7))
            flower(-2.4, 0.6, petal)
            flower(0.6, -0.4, petals[(hue + 1) % 4])
            flower(2.8, 0.8, petal)
        case 4:
            ellipse(0, 0.6, 12, 3.6, Color.primaryBrown.opacity(0.08))
            ellipse(1.6, -3, 11, 7.5, Color(hex: "#929E66"))
            ellipse(-0.8, -3.8, 10.5, 7, .olive)
            ellipse(-2.6, -5.2, 2, 2, petal)
            ellipse(2.4, -4.2, 2, 2, petals[(hue + 1) % 4])
        case 5:
            tree(canopy: 10, trunk: 6)
        default:
            tree(canopy: 15, trunk: 9)
            // Every further chapter adds a fruit, up to a full tree.
            let fruit = min(level - 6, 20) // 49 spots × 25 levels covers all 1,189 chapters
            for i in 0..<fruit {
                let angle = CGFloat(i) * 2.4
                let r = 2 + CGFloat(i % 4) * 1.4
                ellipse(cos(angle) * r * 1.2 - 0.6, -9 - 5.4 + sin(angle) * r * 0.75, 1.9, 1.9,
                        i % 2 == 0 ? Color.terracotta : Color.wheat)
            }
        }
    }

    // MARK: Walking

    private func point(_ p: CGPoint, plotW: CGFloat, topH: CGFloat) -> CGPoint {
        CGPoint(x: plotW / 2 + (p.x - p.y) * plotW / 2, y: (p.x + p.y) * topH / 2)
    }

    /// Where the character is right now, mid-walk or standing.
    private func position(at date: Date) -> CGPoint {
        guard walking, walkDuration > 0 else { return spot }
        let t = min(1, max(0, date.timeIntervalSince(walkStart) / walkDuration))
        let e = t * t * (3 - 2 * t) // ease in and out
        return CGPoint(x: walkFrom.x + (spot.x - walkFrom.x) * e, y: walkFrom.y + (spot.y - walkFrom.y) * e)
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
            facingLeft = (target.x - target.y) < (spot.x - spot.y)
            walkFrom = spot
            walkDuration = Double(distance) / 0.11
            walkStart = .now
            spot = target
            walking = true
            try? await Task.sleep(for: .seconds(walkDuration))
            walking = false
        }
    }

    private func startPop() {
        let count = Garden.slotsGrown(from: revealFrom, to: chapters).count
        guard count > 0, !reduceMotion else { return }
        popStart = .now
        popping = true
        let duration = Double(count) * 0.12 + 0.6
        Task {
            try? await Task.sleep(for: .seconds(duration))
            popping = false
        }
    }
}

#Preview("Platform") {
    PlatformScene(avatar: AvatarStorage().avatar)
        .padding()
        .background(Color.cream)
}
