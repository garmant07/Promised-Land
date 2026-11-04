import SwiftUI
import SwiftData

/// Everything that opens over the island. Only one is ever open at a time.
enum ActiveSheet: Identifiable, Equatable {
    case read
    case journeys
    case friends
    case profile
    case library
    case insight(InsightSubject)

    var id: String {
        switch self {
        case .read: "read"
        case .journeys: "journeys"
        case .friends: "friends"
        case .profile: "profile"
        case .library: "library"
        case .insight(let subject): "insight-\(subject.id)"
        }
    }
}

/// The main screen: your island, always full screen, with a small status in the corner and a
/// floating bar for Read, Journeys, Friends and Profile. Features unlock as buildings on the island.
struct HomeView: View {
    @CurrentAvatar private var avatar: Avatar
    @ProgressQuery private var progress: GameProgress
    @Query private var chapterReads: [ChapterRead]
    @Query private var quizAttempts: [QuizPass]
    @Query private var versesMemorised: [VerseMemorised]
    @Query private var journal: [JournalEntry]
    @Query private var booksStarted: [BookStarted]

    @State private var activeSheet: ActiveSheet?
    @State private var selectedItem: Int?
    @State private var showingWorld = false
    /// Kept alive between visits so the map doesn't rebuild each time.
    @State private var worldScene = WorldScene()
    #if DEBUG
    @State private var debugReflection: ChapterRef?
    #endif

    /// Items on the island when it was last seen (-1: never), so new things can build in.
    @AppStorage(StorageKeys.gardenSeenChapters) private var gardenSeen = -1
    /// Each building's chapters when last seen ("book:count,…"), so growth can be shown.
    @AppStorage(StorageKeys.islandProgressSeen) private var progressSeen = ""
    @State private var revealFrom = 0
    @State private var revealID = 0
    @State private var grown: Set<Int> = []
    @State private var growID = 0
    @State private var growthNote: String?

    /// Every piece of reading, in order, laid out on the island. A book's quiz grows one
    /// fruit tree (its first pass), however many times it's taken.
    private var island: Island {
        let firstPasses = Dictionary(grouping: quizAttempts.filter(\.passed), by: \.bookID)
            .compactMap { $0.value.min { $0.date < $1.date } }
        return Island.build(chapters: chapterReads.map { ($0.bookID, $0.chapterNumber, $0.date) },
                            started: booksStarted.map { ($0.bookID, $0.date) },
                            quizzes: firstPasses.map { ($0.bookID, $0.date) },
                            verses: versesMemorised.map { ($0.bookID, $0.date) },
                            features: journal.isEmpty ? [] : [.library])
    }

    var body: some View {
        let island = island
        ZStack {
            Color.cream.ignoresSafeArea()
            PlatformScene(avatar: avatar, island: island, revealFrom: revealFrom, revealID: revealID,
                          insets: EdgeInsets(top: 70, leading: 8, bottom: 118, trailing: 8),
                          selected: $selectedItem, grown: grown, growID: growID) { index in open(index, in: island) }
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .topLeading) { status }
        .overlay(alignment: .bottom) {
            MainBar(active: activeSheet) { activeSheet = $0 }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
        }
        .sheet(item: $activeSheet) { sheet in
            content(for: sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: activeSheet) { _, sheet in
            if sheet == nil { selectedItem = nil; showNewGrowth() }
        }
        .fullScreenCover(isPresented: $showingWorld, onDismiss: showNewGrowth) {
            WorldView(scene: worldScene) { showingWorld = false }
        }
        .onAppear {
            showNewGrowth()
            #if DEBUG
            debugOpen(island)
            #endif
        }
        .onChange(of: Self.signature(island)) { _, _ in
            if activeSheet == nil && !showingWorld { showNewGrowth() }
        }
        #if DEBUG
        .sheet(item: $debugReflection) { ref in
            if let book = BibleCatalog.book(id: ref.bookID) { ReflectionCard(book: book, chapter: ref.chapter) }
        }
        #endif
    }

    /// Small and unobtrusive: streak and places.
    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label("\(progress.streak)", systemImage: "flame.fill")
                    .accessibilityLabel("Reading streak: \(progress.streak) \(progress.streak == 1 ? "day" : "days")")
                Text("·").foregroundStyle(Color.secondaryText.opacity(0.5))
                Label("\(progress.startedCount)", systemImage: "mappin.and.ellipse")
                    .accessibilityLabel("\(progress.startedCount) \(progress.startedCount == 1 ? "place" : "places") begun")
            }
            .font(.footnote.weight(.semibold).monospacedDigit())
            .foregroundStyle(Color.secondaryText)
            .labelStyle(CompactLabelStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.card.opacity(0.85), in: Capsule())
            if let growthNote {
                Label(growthNote, systemImage: "leaf.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.olive)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.card.opacity(0.85), in: Capsule())
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.leading, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func content(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .read:
            LibraryView(onClose: { activeSheet = nil }, showsSuggestion: true)
        case .journeys:
            JourneysSheet { activeSheet = nil; showingWorld = true }
        case .friends:
            FriendsView()
        case .profile:
            ProfileView()
        case .library:
            LibraryShelfView()
        case .insight(let subject):
            ObjectInsightCard(subject: subject)
        }
    }

    /// A tapped island item: the Library building opens the Library; anything else its Insight Card.
    private func open(_ index: Int?, in island: Island) {
        guard let index, island.items.indices.contains(index) else { selectedItem = nil; return }
        let item = island.items[index]
        selectedItem = index
        if case .feature(.library) = item.source {
            activeSheet = .library
        } else if let subject = InsightSubject.island(item) {
            activeSheet = .insight(subject)
        }
    }

    /// Each building's chapters, as "book:count,…".
    private static func signature(_ island: Island) -> String {
        island.items.compactMap { item -> String? in
            guard case .book(let id) = item.source else { return nil }
            return "\(id):\(item.progress)"
        }.joined(separator: ",")
    }

    /// Builds in whatever's new since the island was last seen: new buildings pop up, and
    /// buildings that gained chapters bounce.
    private func showNewGrowth() {
        let island = island
        let now = island.items.count
        let signature = Self.signature(island)
        defer { gardenSeen = now; progressSeen = signature }
        guard gardenSeen >= 0 else { return }

        let before = Dictionary(progressSeen.split(separator: ",").compactMap { pair -> (String, Int)? in
            let parts = pair.split(separator: ":")
            guard parts.count == 2, let n = Int(parts[1]) else { return nil }
            return (String(parts[0]), n)
        }, uniquingKeysWith: { a, _ in a })
        var grownNow: Set<Int> = []
        var chaptersAdded = 0
        var grownName: String?
        for (index, item) in island.items.enumerated() {
            guard case .book(let id) = item.source, let old = before[id], item.progress > old else { continue }
            grownNow.insert(index)
            chaptersAdded += item.progress - old
            grownName = WorldData.landmark(bookID: id)?.name
        }
        let added = max(0, now - gardenSeen)
        if added > 0 {
            revealFrom = gardenSeen
            revealID += 1
        }
        if !grownNow.isEmpty {
            grown = grownNow
            growID += 1
        }
        let note: String? = {
            if added > 0 && chaptersAdded == 0 {
                return added == 1 ? "Foundations laid" : "\(added) new things on your island"
            }
            if chaptersAdded > 0, grownNow.count == 1, let grownName {
                return "\(grownName): \(chaptersAdded) more \(chaptersAdded == 1 ? "chapter" : "chapters") built"
            }
            if chaptersAdded > 0 { return "\(chaptersAdded) chapters built into your island" }
            return nil
        }()
        guard let note else { return }
        withAnimation(.spring(duration: 0.4)) { growthNote = note }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.6)) { growthNote = nil }
        }
    }

    #if DEBUG
    private func debugOpen(_ island: Island) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-openWorld") { showingWorld = true }
        if args.contains("-openLibrary") { activeSheet = .library }
        if args.contains("-openFriends") { activeSheet = .friends }
        if args.contains("-openProfile") { activeSheet = .profile }
        if args.contains("-openJourneys") { activeSheet = .journeys }
        if args.contains("-openRead") { activeSheet = .read }
        if let i = args.firstIndex(of: "-openReflection"), i + 1 < args.count {
            let parts = args[i + 1].split(separator: ":")
            if parts.count == 2, let book = BibleCatalog.book(id: String(parts[0])), let ch = Int(parts[1]) {
                debugReflection = ChapterRef(bookID: book.id, chapter: ch)
            }
        }
        // "-tapKind fruitTree|lantern|library|chapter" taps the first island item of that kind.
        if let i = args.firstIndex(of: "-tapKind"), i + 1 < args.count {
            let wanted = args[i + 1]
            let index = island.items.firstIndex { item in
                switch item.source {
                case .chapter: wanted == "chapter"
                case .book: wanted == "building"
                case .quiz: wanted == "fruitTree"
                case .verse: wanted == "lantern"
                case .finished: wanted == "landmark"
                case .feature: wanted == "library"
                }
            }
            open(index, in: island)
        }
        // "-tapItem 3" opens the Insight Card for island item 3 (as if tapped).
        if let i = args.firstIndex(of: "-tapItem"), i + 1 < args.count, let index = Int(args[i + 1]) {
            open(index, in: island)
        }
    }
    #endif
}

/// Icon and number close together, for the small status pill.
private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.foregroundStyle(Color.terracotta)
            configuration.title
        }
    }
}

// MARK: - Bottom bar

/// The floating bar: Read, Journeys, Friends, Profile.
struct MainBar: View {
    let active: ActiveSheet?
    var open: (ActiveSheet) -> Void

    private let items: [(ActiveSheet, String, String)] = [
        (.read, "Read", "book.fill"),
        (.journeys, "Journeys", "point.topleft.down.to.point.bottomright.curvepath.fill"),
        (.friends, "Friends", "person.2.fill"),
        (.profile, "Profile", "person.crop.circle.fill"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.1) { item in
                let selected = active == item.0
                Button { open(item.0) } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.2)
                            .font(.system(size: 19, weight: .semibold))
                        Text(item.1)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(selected ? Color.onPrimary : Color.primaryBrown)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(selected ? Color.primaryBrown : Color.clear,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.1)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(6)
        .background(Color.cream.opacity(0.96), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.primaryBrown.opacity(0.14), radius: 14, y: 4)
    }
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

/// The island, filling the screen: pinch to zoom, drag to pan, tap an object to inspect it.
/// Your character strolls around on it.
struct PlatformScene: View {
    let avatar: Avatar
    let island: Island
    /// Items from this index onward build in when `revealID` changes.
    var revealFrom = 0
    var revealID = 0
    /// Room kept clear of the island (for the status pill and the bottom bar).
    var insets = EdgeInsets()
    var selected: Binding<Int?> = .constant(nil)
    /// Buildings that just grew bounce when `growID` changes.
    var grown: Set<Int> = []
    var growID = 0
    /// Called with the tapped item's index (nil for empty ground). Nil callback = read-only.
    var onTap: ((Int?) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Camera
    @State private var zoom: CGFloat = 1
    @State private var zoomStart: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panStart: CGSize = .zero
    @State private var isPanning = false

    // Character
    @State private var spot = CGPoint(x: 13, y: 13)
    @State private var walkFrom = CGPoint(x: 13, y: 13)
    @State private var walkStart = Date.distantPast
    @State private var walkDuration: TimeInterval = 0
    @State private var walking = false
    @State private var facingLeft = false

    // Building in & selection
    @State private var popStart = Date.distantPast
    @State private var popping = false
    @State private var bounceStart = Date.distantPast
    @State private var bouncing = false
    @State private var bounceTargets: Set<Int> = []

    var body: some View {
        GeometryReader { geo in
            let layout = IslandLayout(island: island, size: geo.size, insets: insets, zoom: zoom)
            let charH = min(66 * layout.zoom, max(26, layout.scale * 0.85))
            let charW = charH * 20 / 36
            let staticCount = popping ? min(revealFrom, island.items.count) : island.items.count

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    // Settled things are drawn once; only the character, new things and the
                    // selected item redraw while animating.
                    Canvas { context, _ in
                        IslandPainter.drawTiles(&context, island: island, layout: layout)
                        if let selected = selected.wrappedValue, island.items.indices.contains(selected) {
                            Self.drawHighlight(&context, island.items[selected], layout: layout)
                        }
                        for item in island.items.prefix(staticCount).sorted(by: { $0.gx + $0.gy < $1.gx + $1.gy }) {
                            IslandPainter.drawItem(&context, item, layout: layout)
                        }
                    }

                    TimelineView(.animation(paused: !walking && !popping && !bouncing)) { context in
                        let now = context.date
                        let pos = position(at: now)
                        let feet = layout.point(pos.x, pos.y)
                        let t = now.timeIntervalSinceReferenceDate
                        let bounce = walking ? -abs(sin(t * 9)) * charH * 0.05 : 0
                        let lean = walking ? sin(t * 9) * 3 : 0
                        let popElapsed = now.timeIntervalSince(popStart)
                        let popStep = min(0.1, 2.0 / Double(max(1, island.items.count - staticCount)))

                        ZStack(alignment: .topLeading) {
                            // New things building in, and the selected item's bounce.
                            Canvas { c, _ in
                                if popping {
                                    for (rank, item) in island.items.enumerated().dropFirst(staticCount) {
                                        let progress = (popElapsed - Double(rank - staticCount) * popStep) / 0.45
                                        guard progress > 0 else { continue }
                                        IslandPainter.drawItem(&c, item, layout: layout, scale: progress < 1 ? Self.overshoot(progress) : 1)
                                    }
                                }
                                if bouncing {
                                    let e = now.timeIntervalSince(bounceStart)
                                    let s = 1 + 0.16 * sin(min(1, e / 0.5) * .pi) * (1 - min(1, e / 0.5))
                                    for index in bounceTargets.sorted() where island.items.indices.contains(index) {
                                        IslandPainter.drawItem(&c, island.items[index], layout: layout, scale: s)
                                    }
                                }
                            }
                            AvatarFigure(avatar: avatar)
                                .frame(width: charW, height: charH)
                                .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
                                .rotationEffect(.degrees(lean), anchor: .bottom)
                                .offset(y: bounce)
                                .position(x: feet.x, y: feet.y - charH * 0.43)
                            // Tall things in front of the character are drawn over it.
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
                .offset(pan)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(onTap == nil ? nil : dragGesture(layout: layout, size: geo.size))
            .simultaneousGesture(onTap == nil ? nil : zoomGesture(size: geo.size))
            .onChange(of: selected.wrappedValue) { _, index in
                guard let index, island.items.indices.contains(index) else { return }
                centre(on: island.items[index], layout: layout, size: geo.size)
                if !reduceMotion { startBounce([index]) }
            }
        }
        .onAppear { placeCharacter() }
        .onChange(of: island.tiles.count) { _, _ in if !walking { placeCharacter() } }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            await wander()
        }
        .onChange(of: revealID) { _, _ in startPop() }
        .onChange(of: growID) { _, _ in if !reduceMotion { startBounce(grown, duration: 0.9) } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your island")
        .accessibilityValue(island.items.isEmpty ? "Bare grass" :
            "\(island.items.count) \(island.items.count == 1 ? "thing" : "things") growing")
    }

    // MARK: Gestures

    /// One drag gesture tells taps from pans: under 10pt of movement is a tap.
    private func dragGesture(layout: IslandLayout, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPanning, !TapClassifier.isTap(translation: value.translation) { isPanning = true }
                if isPanning {
                    pan = clamp(CGSize(width: panStart.width + value.translation.width,
                                       height: panStart.height + value.translation.height), size: size)
                }
            }
            .onEnded { value in
                if isPanning {
                    isPanning = false
                    panStart = pan
                } else if TapClassifier.isTap(translation: value.translation) {
                    onTap?(IslandHitTester.hit(point: value.location, layout: layout, pan: pan, items: island.items))
                }
            }
    }

    private func zoomGesture(size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let z = min(IslandLayout.maxZoom, max(IslandLayout.minZoom, zoomStart * value.magnification))
                let ratio = z / zoom
                zoom = z
                pan = clamp(CGSize(width: pan.width * ratio, height: pan.height * ratio), size: size)
            }
            .onEnded { _ in
                zoomStart = zoom
                panStart = pan
            }
    }

    /// Keeps the island on screen however far you zoom.
    private func clamp(_ p: CGSize, size: CGSize) -> CGSize {
        let maxX = (zoom - 1) * size.width / 2 + size.width * 0.25
        let maxY = (zoom - 1) * size.height / 2 + size.height * 0.25
        return CGSize(width: min(maxX, max(-maxX, p.width)), height: min(maxY, max(-maxY, p.height)))
    }

    /// Eases the view so the selected item sits in the middle of the free area.
    private func centre(on item: Island.Item, layout: IslandLayout, size: CGSize) {
        let base = layout.point(item.gx, item.gy)
        let target = CGPoint(x: insets.leading + (size.width - insets.leading - insets.trailing) / 2,
                             y: insets.top + (size.height - insets.top - insets.bottom) * 0.35)
        let desired = clamp(CGSize(width: target.x - base.x, height: target.y - base.y), size: size)
        // Ease only part of the way, so it feels like a nudge rather than a jump.
        let eased = CGSize(width: pan.width + (desired.width - pan.width) * 0.6,
                           height: pan.height + (desired.height - pan.height) * 0.6)
        withAnimation(.easeOut(duration: 0.45)) { pan = eased }
        panStart = eased
    }

    private func startBounce(_ targets: Set<Int>, duration: Double = 0.55) {
        bounceTargets = targets
        bounceStart = .now
        bouncing = true
        Task {
            try? await Task.sleep(for: .seconds(duration))
            bouncing = false
        }
    }

    private static func drawHighlight(_ c: inout GraphicsContext, _ item: Island.Item, layout: IslandLayout) {
        let base = layout.point(item.gx, item.gy)
        let w = max(item.footprint.width, 0.5) * layout.scale * 2.2
        c.fill(Path(ellipseIn: CGRect(x: base.x - w / 2, y: base.y - w * 0.22, width: w, height: w * 0.44)),
               with: .color(Color.wheat.opacity(0.55)))
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

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
