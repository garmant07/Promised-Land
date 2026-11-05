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
    /// Reading one chapter (from a character's story link or a building's inside).
    case chapter(ChapterRef)
    /// A character has just come to the island.
    case character(String)
    /// A character's journey map.
    case journey(String)

    var id: String {
        switch self {
        case .read: "read"
        case .journeys: "journeys"
        case .friends: "friends"
        case .profile: "profile"
        case .library: "library"
        case .insight(let subject): "insight-\(subject.id)"
        case .chapter(let ref): "chapter-\(ref.id)"
        case .character(let id): "character-\(id)"
        case .journey(let id): "journey-\(id)"
        }
    }

    /// Reading gets a page-sized sheet on iPad, wide enough for a two-page spread.
    var isReading: Bool {
        switch self {
        case .read, .chapter: true
        default: false
        }
    }

    /// Reading and celebrations open full height; everything else starts at half.
    var detents: Set<PresentationDetent> {
        switch self {
        case .chapter, .character, .journey: [.large]
        default: [.medium, .large]
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
    @Query private var placedItems: [PlacedItem]
    @Environment(\.modelContext) private var context

    @State private var activeSheet: ActiveSheet?
    @State private var selectedItem: Int?
    @State private var showingWorld = false
    /// Kept alive between visits so the map doesn't rebuild each time.
    @State private var worldScene = WorldScene()
    #if DEBUG
    @State private var debugReflection: ChapterRef?
    @State private var debugGallery = false
    @State private var debugCreator = false
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

    // Edit mode
    @State private var editingIsland = false
    @State private var draft: [String: IslandPlacement] = [:]
    @State private var editSelected: String?
    @State private var dragBase: IslandPlacement?

    // Stepping inside a building
    @State private var visitIndex: Int?
    @State private var interior: InteriorRef?

    /// Unlocks already announced (so each banner shows once).
    @AppStorage("unlocks.seen") private var unlocksSeen = ""
    /// False until the first check, when what you already had is noted silently.
    @AppStorage("unlocks.ready") private var unlocksReady = false
    /// Banners waiting to be shown, oldest first.
    @State private var notices: [UnlockNotice] = []

    /// Characters already welcomed (so each celebration shows once).
    @AppStorage("characters.celebrated") private var celebratedCharacters = ""
    /// False until the first check, when characters you already had are noted silently.
    @AppStorage("characters.ready") private var charactersReady = false
    /// Same for the character journeys (they replaced the first character unlocks).
    @AppStorage("characters.journeysReady") private var journeysReady = false
    /// Same for crowns (announced since the master build).
    @AppStorage("unlocks.crownsReady") private var crownsReady = false

    /// Characters whose journeys are complete.
    private var unlockedCharacters: [CharacterJourney] { progress.unlockedJourneys }

    /// Every piece of reading, in order, laid out on the island. A book's quiz grows one
    /// fruit tree (its first pass), however many times it's taken.
    private var island: Island {
        let firstPasses = Dictionary(grouping: quizAttempts.filter(\.passed), by: \.bookID)
            .compactMap { $0.value.min { $0.date < $1.date } }
        return Island.build(chapters: chapterReads.map { ($0.bookID, $0.chapterNumber, $0.date) },
                            started: booksStarted.map { ($0.bookID, $0.date) },
                            quizzes: firstPasses.map { ($0.bookID, $0.date) },
                            verses: versesMemorised.map { ($0.bookID, $0.date) },
                            // The Library is the reading hub, so it's always there.
                            features: progress.hasCompletedBible ? [.library, .throne] : [.library],
                            placements: editingIsland ? draft : savedPlacements,
                            unchecked: chapterReads.filter { !$0.checked }.map { ($0.bookID, $0.chapterNumber) })
    }

    /// Where you've put things (saved in edit mode).
    private var savedPlacements: [String: IslandPlacement] {
        Dictionary(placedItems.map { ($0.key, IslandPlacement(x: $0.x, y: $0.y, rotation: $0.rotation, moved: $0.moved)) },
                   uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        let island = island
        ZStack {
            Earthy.sea.ignoresSafeArea()
            PlatformScene(avatar: avatar, island: island, revealFrom: revealFrom, revealID: revealID,
                          insets: EdgeInsets(top: 70, leading: 8, bottom: 118, trailing: 8),
                          selected: $selectedItem, grown: grown, growID: growID,
                          persistsCamera: true, editing: editingIsland ? editing : nil,
                          onLongPress: { index in startEditing(island.items[index].plotKey) },
                          characters: IslandCharacter.make(unlockedCharacters, island: island),
                          onViewJourney: { activeSheet = .journey($0) },
                          visit: visitIndex,
                          onArrived: { index in
                              guard island.items.indices.contains(index) else { return }
                              switch island.items[index].kind {
                              case .building(let id): interior = InteriorRef(id: id)
                              case .library: interior = InteriorRef(id: InteriorRef.library)
                              case .throne: interior = InteriorRef(id: InteriorRef.throne)
                              default: break
                              }
                          }) { index in open(index, in: island) }
                .ignoresSafeArea(edges: .bottom)
        }
        // The status pill is read-only, so touches on it go through to the island.
        .overlay(alignment: .topLeading) { if !editingIsland { status.allowsHitTesting(false) } }
        .overlay(alignment: .top) { if editingIsland { editBar(island) } }
        .overlay(alignment: .top) {
            if !editingIsland, let notice = notices.first {
                UnlockBanner(notice: notice, more: notices.count - 1,
                             onSee: notice.itemIndex.map { index in { showUnlock(index) } },
                             onDismiss: nextNotice)
                    .padding(.horizontal, 12)
                    .padding(.top, 54)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(notice.id)
                    .task(id: notice.id) {
                        // Moves on by itself after a while.
                        try? await Task.sleep(for: .seconds(7))
                        if notices.first?.id == notice.id { nextNotice() }
                    }
            }
        }
        .sensoryFeedback(.success, trigger: notices.first?.id)
        .overlay(alignment: .bottom) {
            if !editingIsland {
                MainBar(active: activeSheet) { sheet in
                    // Read walks you into the Library, where every book is.
                    if sheet == .read, let library = island.index(of: .library) {
                        visitIndex = library
                    } else {
                        activeSheet = sheet
                    }
                }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            content(for: sheet)
                .presentationDetents(sheet.detents)
                .readingSizing(sheet.isReading)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: activeSheet) { _, sheet in
            if sheet == nil { selectedItem = nil; showNewGrowth() }
        }
        .fullScreenCover(item: $interior, onDismiss: {
            visitIndex = nil
            selectedItem = nil
            showNewGrowth()
        }) { ref in
            if ref.id == InteriorRef.library {
                LibraryHubView { interior = nil }
            } else if ref.id == InteriorRef.throne {
                ThroneRoomView()
            } else {
                InteriorView(bookID: ref.id) { interior = nil }
            }
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
        .fullScreenCover(isPresented: $debugGallery) { AvatarGallery() }
        .sheet(isPresented: $debugCreator) { AvatarCustomizeView() }
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
            if let growthNote, notices.isEmpty {
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
            ProfileView(onEditIsland: {
                activeSheet = nil
                startEditing(nil)
            }, island: island)
        case .library:
            LibraryShelfView()
        case .insight(let subject):
            ObjectInsightCard(subject: subject)
        case .chapter(let ref):
            LibraryView(startAt: ref, onClose: { activeSheet = nil })
        case .character(let id):
            if let journey = CharacterJourneys.journey(id: id) {
                CharacterUnlockView(journey: journey) {
                    Task { try? await Task.sleep(for: .milliseconds(450)); activeSheet = .journey(journey.id) }
                }
            }
        case .journey(let id):
            if let journey = CharacterJourneys.journey(id: id) {
                NavigationStack {
                    JourneyMapView(journey: journey)
                        .readingDestinations()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("Done") { activeSheet = nil }.tint(Color.primaryBrown) }
                        }
                }
                .environment(\.closeReading, CloseReadingAction(action: { activeSheet = nil }))
            }
        }
    }

    /// A tapped island item: the Library building opens the Library; anything else its Insight Card.
    private func open(_ index: Int?, in island: Island) {
        guard let index, island.items.indices.contains(index) else { selectedItem = nil; return }
        let item = island.items[index]
        selectedItem = index
        if case .feature = item.source {
            // Walk to the Library's (or throne room's) door and step inside, like any building.
            visitIndex = index
        } else if case .building = item.kind {
            // Step inside: walk to the door, then open the building.
            visitIndex = index
        } else if let subject = InsightSubject.island(item) {
            activeSheet = .insight(subject)
        }
    }

    // MARK: Edit mode

    private var editing: IslandEditing {
        IslandEditing(selected: editSelected, onDrag: { key, dx, dy, ended in editDrag(key, dx, dy, ended: ended) },
                      onSelect: { editSelected = $0 })
    }

    /// Freezes every plot where it is now, so only what you move changes.
    private func startEditing(_ key: String?) {
        let saved = savedPlacements
        var current = island.placements
        for k in current.keys { current[k]?.moved = saved[k]?.moved ?? false }
        draft = current
        editSelected = key
        selectedItem = nil
        withAnimation(.easeInOut(duration: 0.25)) { editingIsland = true }
    }

    private func editDrag(_ key: String, _ dx: Int, _ dy: Int, ended: Bool) {
        if dragBase == nil { dragBase = draft[key] }
        guard let base = dragBase else { return }
        editSelected = key
        var p = base
        p.x += dx
        p.y += dy
        if dx != 0 || dy != 0 { p.moved = true }
        if draft[key] != p { draft[key] = p }
        guard ended else { return }
        // Dropped somewhere it doesn't fit: back to where it started.
        if island.conflicts.contains(key) {
            withAnimation(.easeOut(duration: 0.2)) { draft[key] = base }
        }
        dragBase = nil
    }

    private func turnSelected() {
        guard let key = editSelected, var p = draft[key] else { return }
        p.rotation = (p.rotation + 1) % 4
        p.moved = true
        draft[key] = p
    }

    /// Lays out again everything you haven't moved yourself.
    private func tidyUp() {
        draft = draft.filter { $0.value.moved }
        // Freeze the new layout, keeping the moved flags.
        var fresh = island.placements
        for k in fresh.keys { fresh[k]?.moved = draft[k]?.moved ?? false }
        draft = fresh
    }

    private func finishEditing(save: Bool) {
        if save {
            var final = island.placements
            for k in final.keys { final[k]?.moved = draft[k]?.moved ?? false }
            context.savePlacements(final)
        }
        withAnimation(.easeInOut(duration: 0.25)) { editingIsland = false }
        draft = [:]
        editSelected = nil
    }

    private func editBar(_ island: Island) -> some View {
        let blocked = !island.conflicts.isEmpty
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("Cancel") { finishEditing(save: false) }
                    .buttonStyle(EditChipStyle())
                Spacer(minLength: 0)
                Button { turnSelected() } label: { Label("Turn", systemImage: "rotate.right") }
                    .buttonStyle(EditChipStyle())
                    .disabled(editSelected == nil)
                Button("Tidy up") { tidyUp() }
                    .buttonStyle(EditChipStyle())
                Spacer(minLength: 0)
                Button("Done") { finishEditing(save: true) }
                    .buttonStyle(EditChipStyle())
                    .disabled(blocked)
            }
            Text(editSelected == nil ? "Drag a building to move its plot. Tap one to turn it."
                 : blocked ? "That spot overlaps another plot." : "Green means it fits. Drag, turn, or tap Done.")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
        }
        .padding(12)
        .background(Color.cream.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 6)
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
    /// Welcomes a newly unlocked character (one at a time).
    private func welcomeCharacters() {
        let unlocked = unlockedCharacters.map(\.id)
        var seen = Set(celebratedCharacters.split(separator: ",").map(String.init))
        guard charactersReady, journeysReady else {
            journeysReady = true
            celebratedCharacters = unlocked.joined(separator: ",")
            charactersReady = true
            return
        }
        guard activeSheet == nil, let new = unlocked.first(where: { !seen.contains($0) }) else { return }
        seen.insert(new)
        celebratedCharacters = seen.sorted().joined(separator: ",")
        activeSheet = .character(new)
    }

    /// Queues a banner for each unlock not announced before.
    private func announceUnlocks(_ island: Island) {
        // Character journeys get their own celebration; the world map's routes aren't announced.
        let crowns = Dictionary(uniqueKeysWithValues: BibleCatalog.books.map { ($0.id, progress.crownsEarned($0.id)) })
        let all = UnlockNotices.all(island: island, completedJourneys: [], crowns: crowns)
        var seen = Set(unlocksSeen.split(separator: ",").map(String.init))
        guard unlocksReady else {
            // The first time, what you already have is noted without announcing it.
            unlocksSeen = all.map(\.id).joined(separator: ",")
            unlocksReady = true
            return
        }
        if !crownsReady {
            // Crowns earned before crowns were announced are noted silently.
            seen.formUnion(all.filter { $0.id.hasPrefix("crown:") }.map(\.id))
            crownsReady = true
            unlocksSeen = seen.sorted().joined(separator: ",")
        }
        let new = all.filter { !seen.contains($0.id) }
        guard !new.isEmpty else { return }
        seen.formUnion(new.map(\.id))
        unlocksSeen = seen.sorted().joined(separator: ",")
        withAnimation(.spring(duration: 0.4)) { notices += new.filter { n in !notices.contains { $0.id == n.id } } }
    }

    private func nextNotice() {
        guard !notices.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.3)) { _ = notices.removeFirst() }
    }

    /// "See it": centres the island on the new thing and gives it a bounce.
    private func showUnlock(_ index: Int) {
        selectedItem = nil
        Task {
            try? await Task.sleep(for: .milliseconds(30))
            selectedItem = index
        }
        nextNotice()
    }

    private func showNewGrowth() {
        let island = island
        #if DEBUG
        // "-quiet" skips welcomes and banners (for screenshots).
        let quiet = ProcessInfo.processInfo.arguments.contains("-quiet")
        #else
        let quiet = false
        #endif
        if !quiet {
            welcomeCharacters()
            announceUnlocks(island)
        }
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
        if args.contains("-editIsland") { startEditing(island.plots.first?.bookID) }
        if args.contains("-openHub") { interior = InteriorRef(id: InteriorRef.library) }
        if args.contains("-avatarGallery") { debugGallery = true }
        if let i = args.firstIndex(of: "-openJourneyMap"), i + 1 < args.count { activeSheet = .journey(args[i + 1]) }
        if args.contains("-openCreator") { debugCreator = true }
        if let i = args.firstIndex(of: "-celebrate"), i + 1 < args.count { activeSheet = .character(args[i + 1]) }
        if let i = args.firstIndex(of: "-openChapter"), i + 1 < args.count {
            let parts = args[i + 1].split(separator: ":")
            if parts.count == 2, let ch = Int(parts[1]) { activeSheet = .chapter(ChapterRef(bookID: String(parts[0]), chapter: ch)) }
        }
        if let i = args.firstIndex(of: "-openReflection"), i + 1 < args.count {
            let parts = args[i + 1].split(separator: ":")
            if parts.count == 2, let book = BibleCatalog.book(id: String(parts[0])), let ch = Int(parts[1]) {
                debugReflection = ChapterRef(bookID: book.id, chapter: ch)
            }
        }
        // "-tapKind chapter|building|banner|lantern|story|library" taps the first island item of that kind.
        if let i = args.firstIndex(of: "-tapKind"), i + 1 < args.count {
            let wanted = args[i + 1]
            let index = island.items.firstIndex { item in
                switch item.source {
                case .chapter: wanted == "chapter"
                case .book: wanted == "building"
                case .quiz: wanted == "banner"
                case .verse: wanted == "lantern"
                case .story: wanted == "story"
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

/// A building being visited (for the full-screen inside page).
struct InteriorRef: Identifiable, Equatable {
    let id: String
    static let library = "feature:library"
    static let throne = "feature:throne"
}

/// Compact buttons for the edit-mode bar.
private struct EditChipStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(Color.primaryBrown.opacity(isEnabled ? 1 : 0.4))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Color.card.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
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

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
