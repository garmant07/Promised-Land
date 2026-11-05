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
    /// Your basket of produce.
    case basket

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
        case .basket: "basket"
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
    @Query private var produceCollected: [ProduceCollection]
    @Query private var placedExtras: [PlacedExtra]
    @AppStorage("debug.fpsOverlay") private var showsFPS = false
    @Environment(\.modelContext) private var context

    @State private var activeSheet: ActiveSheet?
    @State private var selectedItem: Int?
    #if DEBUG
    @State private var debugReflection: ChapterRef?
    @State private var debugGallery = false
    @State private var debugCreator = false
    @State private var debugBiblePreview = false
    #endif

    /// Items on the island when it was last seen (-1: never), so new things can build in.
    @AppStorage(StorageKeys.gardenSeenChapters) private var gardenSeen = -1
    /// Each building's chapters when last seen ("book:count,…"), so growth can be shown.
    @AppStorage(StorageKeys.islandProgressSeen) private var progressSeen = ""
    @State private var reveal: [RevealStep] = []
    @State private var revealInitial: [Int: CGFloat] = [:]
    @State private var revealID = 0
    /// The beat of the "see it built" moment playing now (for its caption).
    @State private var revealing: RevealStep?
    /// A short note under the status pill (e.g. produce collected).
    @State private var toast: String?
    /// The Library's stage when the island was last seen (-1: never), so its growth can be shown.
    @AppStorage("library.stageSeen") private var libraryStageSeen = -1
    /// True from when a "see it built" moment is planned until it has finished.
    @State private var revealActive = false
    /// The status bar's height (the island is drawn under it).
    @State private var safeTop: CGFloat = 0

    // Collect All
    @State private var collectFlight: CollectFlight?
    @State private var collectBounce = 0
    @State private var collectSummary: String?
    @State private var collectTarget: CGRect = .zero
    @State private var pendingSummary: String?
    /// The count the button keeps showing while a Collect All lands.
    @State private var collectHolding: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Edit mode
    @State private var editingIsland = false
    @State private var draft: [String: IslandPlacement] = [:]
    @State private var editSelected: String?
    @State private var dragBase: IslandPlacement?
    @State private var draftExtras: [PlacedExtraInfo] = []
    @State private var extraDragBase: PlacedExtraInfo?
    /// Earlier states while editing, for Undo.
    @State private var undoStack: [(placements: [String: IslandPlacement], extras: [PlacedExtraInfo])] = []

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
                            unchecked: chapterReads.filter { !$0.checked }.map { ($0.bookID, $0.chapterNumber) },
                            extras: editingIsland ? draftExtras : savedExtras,
                            journalNotes: journal.count,
                            // While editing, the Library keeps the size it has (dropping a Place on it
                            // is a conflict, not a reason for it to shrink).
                            libraryAvoid: editingIsland ? savedPlacements : nil)
    }

    /// Extras you've placed (saved in edit mode).
    private var savedExtras: [PlacedExtraInfo] {
        placedExtras.compactMap { e in
            ExtraKind(rawValue: e.kind).map { PlacedExtraInfo(id: e.uid, kind: $0, x: CGFloat(e.x), y: CGFloat(e.y), rotation: e.rotation) }
        }.sorted { $0.id < $1.id }
    }

    /// Extras earned by reading streaks, less those already placed.
    private var extrasLeft: [ExtraKind: Int] {
        let dates = chapterReads.map(\.date)
        let earned = RewardData.extrasEarned(longestStreak: Streak.longest(from: dates),
                                             readingDays: ProduceRules.readingDays(dates).count)
        var left = earned
        for e in draftExtras { left[e.kind, default: 0] -= 1 }
        return left
    }

    /// Where you've put things (saved in edit mode).
    private var savedPlacements: [String: IslandPlacement] {
        Dictionary(placedItems.map { ($0.key, IslandPlacement(x: $0.x, y: $0.y, rotation: $0.rotation, moved: $0.moved)) },
                   uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        let island = island
        let baskets = baskets(island)
        let waiting = baskets.values.reduce(0, +)
        ZStack {
            Earthy.sea.ignoresSafeArea()
            PlatformScene(avatar: avatar, island: island, reveal: reveal, revealInitial: revealInitial, revealID: revealID,
                          onRevealStep: { step in
                              withAnimation(.easeInOut(duration: 0.35)) { revealing = step }
                              if step == nil { revealActive = false }
                          },
                          // The island fills the whole screen, under the status bar too; the insets
                          // only keep it clear of the status pill and the bar when fitting it.
                          insets: EdgeInsets(top: 70 + safeTop, leading: 8, bottom: 118, trailing: 8),
                          selected: $selectedItem,
                          persistsCamera: true, editing: editingIsland ? editing : nil,
                          onLongPress: { index in startEditing(island.items[index].plotKey) },
                          characters: IslandCharacter.make(unlockedCharacters, island: island),
                          onViewJourney: { activeSheet = .journey($0) },
                          visit: visitIndex,
                          onArrived: { index in
                              guard island.items.indices.contains(index) else { return }
                              let item = island.items[index]
                              switch item.kind {
                              case .piece, .flourish: if let id = item.source.bookID { interior = InteriorRef(id: id) }
                              case .library: interior = InteriorRef(id: InteriorRef.library)
                              case .throne: interior = InteriorRef(id: InteriorRef.throne)
                              default: break
                              }
                          },
                          life: IslandLife.make(island: island, baskets: baskets),
                          onBasket: { collect($0, island: island) },
                          onCrowd: { activeSheet = .basket },
                          collectFlight: collectFlight,
                          collectTarget: collectTarget,
                          onCollectLanded: collectLanded,
                          showsFPS: showsFPS) { index in open(index, in: island) }
                .ignoresSafeArea()
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { safeTop = $0 }
        // The status pill is read-only, so touches on it go through to the island.
        .overlay(alignment: .topLeading) { if !editingIsland { status.allowsHitTesting(false) } }
        .overlay(alignment: .bottom) {
            if let revealing {
                RevealCaption(step: revealing)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .id(revealing.id)
            }
        }
        .overlay(alignment: .bottomLeading) {
            // Collect All: just above the bar, only while something is ready and nothing else is open.
            // While produce flies in (and a moment after it lands), the button stays to catch it.
            let shownTotal = collectHolding ?? waiting
            let visible = CollectAll.isButtonVisible(total: shownTotal, editing: editingIsland, revealing: revealActive || revealing != nil,
                                                     sheetOpen: activeSheet != nil || interior != nil || visitIndex != nil)
            VStack(alignment: .leading, spacing: 10) {
                if let collectSummary {
                    CollectSummaryToast(text: collectSummary)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .allowsHitTesting(false)
                }
                if visible {
                    CollectAllButton(total: shownTotal, bounce: collectBounce) { collectAll(island) }
                        .disabled(collectHolding != nil)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { collectTarget = $0 }
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }
            .padding(.leading, 16)
            .padding(.bottom, 92)
            .animation(.spring(duration: 0.35), value: visible)
            .animation(.easeInOut(duration: 0.3), value: collectSummary)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: collectBounce)
        .overlay(alignment: .top) { if editingIsland { editBar(island) } }
        .overlay(alignment: .bottom) { if editingIsland { extrasTray } }
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
        .onAppear {
            showNewGrowth()
            #if DEBUG
            debugOpen(island)
            #endif
        }
        .onChange(of: Self.signature(island)) { _, _ in
            if activeSheet == nil && interior == nil { showNewGrowth() }
        }
        #if DEBUG
        .fullScreenCover(isPresented: $debugGallery) { AvatarGallery() }
        .sheet(isPresented: $debugCreator) { AvatarCustomizeView() }
        .fullScreenCover(isPresented: $debugBiblePreview) { FullBiblePreviewView { debugBiblePreview = false } }
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
            if let toast {
                Label(toast, systemImage: "basket.fill")
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
            JourneysSheet()
        case .friends:
            FriendsView()
        case .profile:
            ProfileView(onEditIsland: {
                activeSheet = nil
                startEditing(nil)
            }, island: island)
        case .library:
            LibraryShelfView()
        case .basket:
            BasketView()
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
        } else if case .place = item.source {
            // Step inside: walk to the Place, then open its page.
            visitIndex = index
        } else if let subject = InsightSubject.island(item) {
            activeSheet = .insight(subject)
        }
    }

    // MARK: Produce

    /// What waits in each complete Place's basket: one per reading day since it was completed
    /// (or last collected), up to a small cap.
    private func baskets(_ island: Island) -> [String: Int] {
        ProduceRules.baskets(completed: island.completed, readDates: chapterReads.filter(\.checked).map(\.date),
                             collections: produceCollected.map { ($0.bookID, $0.date) })
    }

    /// Collect All: empties every basket on the island (on screen or not) into your store at once;
    /// the on-screen ones fly into the button, then a summary shows.
    private func collectAll(_ island: Island) {
        let baskets = baskets(island)
        let plan = CollectAll.plan(baskets)
        guard !plan.entries.isEmpty else { return }
        let totals = context.collectAllProduce(baskets)
        collectSummary = nil
        collectHolding = totals.values.reduce(0, +)
        pendingSummary = CollectAll.summary(totals)
        if !reduceMotion { SoftSound.whoosh() }
        collectFlight = CollectFlight(id: (collectFlight?.id ?? 0) + 1, entries: plan.entries)
    }

    /// The produce has landed in the button: a bounce, then the summary.
    private func collectLanded() {
        collectBounce += 1
        collectFlight = nil
        Task {
            // A moment to see the bounce, then it fades away (nothing is left to collect).
            try? await Task.sleep(for: .milliseconds(450))
            collectHolding = nil
        }
        guard let text = pendingSummary else { return }
        pendingSummary = nil
        collectSummary = text
        AccessibilityNotification.Announcement("Collected \(text)").post()
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            if collectSummary == text { collectSummary = nil }
        }
    }

    private func collect(_ bookID: String, island: Island) {
        let n = baskets(island)[bookID] ?? 0
        guard n > 0 else { return }
        let kind = PlaceData.spec(for: bookID).produce
        context.collectProduce(bookID, kind: kind, amount: n)
        withAnimation(.spring(duration: 0.4)) { toast = "\(n) \(kind.name.lowercased()) from \(PlaceData.spec(for: bookID).name)" }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 0.5)) { toast = nil }
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
        draftExtras = savedExtras
        undoStack = []
        editSelected = key
        selectedItem = nil
        withAnimation(.easeInOut(duration: 0.25)) { editingIsland = true }
    }

    private func remember() {
        undoStack.append((draft, draftExtras))
        if undoStack.count > 50 { undoStack.removeFirst() }
    }

    private func undo() {
        guard let last = undoStack.popLast() else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            draft = last.placements
            draftExtras = last.extras
        }
    }

    private func editDrag(_ key: String, _ dx: Int, _ dy: Int, ended: Bool) {
        if key.hasPrefix("extra:") { extraDrag(String(key.dropFirst(6)), dx, dy, ended: ended); return }
        if dragBase == nil { dragBase = draft[key]; remember() }
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
        if dx == 0 && dy == 0 { undoStack.removeLast() } // just a tap
        dragBase = nil
    }

    private func extraDrag(_ id: String, _ dx: Int, _ dy: Int, ended: Bool) {
        guard let index = draftExtras.firstIndex(where: { $0.id == id }) else { return }
        if extraDragBase == nil { extraDragBase = draftExtras[index]; remember() }
        guard let base = extraDragBase else { return }
        editSelected = "extra:\(id)"
        let moved = PlacedExtraInfo(id: id, kind: base.kind, x: base.x + CGFloat(dx), y: base.y + CGFloat(dy), rotation: base.rotation)
        if draftExtras[index] != moved { draftExtras[index] = moved }
        guard ended else { return }
        if island.conflicts.contains("extra:\(id)") {
            withAnimation(.easeOut(duration: 0.2)) { draftExtras[index] = base }
        }
        if dx == 0 && dy == 0 { undoStack.removeLast() }
        extraDragBase = nil
    }

    private func turnSelected() {
        guard let key = editSelected else { return }
        remember()
        if key.hasPrefix("extra:"), let i = draftExtras.firstIndex(where: { "extra:\($0.id)" == key }) {
            draftExtras[i].rotation = (draftExtras[i].rotation + 1) % 4
            return
        }
        guard var p = draft[key] else { return }
        p.rotation = (p.rotation + 1) % 4
        p.moved = true
        draft[key] = p
    }

    /// Puts a new extra from the tray on the nearest open land to the plaza (then drag it).
    private func addExtra(_ kind: ExtraKind) {
        guard (extrasLeft[kind] ?? 0) > 0 else { return }
        let island = island
        let taken = Set(draftExtras.map { Island.Tile(x: Int(floor($0.x)), y: Int(floor($0.y))) })
        let inside: (Island.Tile) -> Bool = { t in island.allPlots.contains { $0.rect.contains(CGPoint(x: CGFloat(t.x) + 0.5, y: CGFloat(t.y) + 0.5)) } }
        let spot = island.tiles.filter { !taken.contains($0) && !inside($0) }
            .min { hypot(Double($0.x) - 1, Double($0.y) - 1) < hypot(Double($1.x) - 1, Double($1.y) - 1) }
        guard let spot else { return }
        remember()
        let extra = PlacedExtraInfo(id: UUID().uuidString, kind: kind, x: CGFloat(spot.x) + 0.5, y: CGFloat(spot.y) + 0.5)
        draftExtras.append(extra)
        editSelected = "extra:\(extra.id)"
    }

    private func removeSelectedExtra() {
        guard let key = editSelected, key.hasPrefix("extra:") else { return }
        remember()
        draftExtras.removeAll { "extra:\($0.id)" == key }
        editSelected = nil
    }

    /// Lays out again everything you haven't moved yourself.
    private func tidyUp() {
        remember()
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
            context.saveExtras(draftExtras)
        }
        withAnimation(.easeInOut(duration: 0.25)) { editingIsland = false }
        draft = [:]
        draftExtras = []
        undoStack = []
        editSelected = nil
    }

    private func editBar(_ island: Island) -> some View {
        let blocked = !island.conflicts.isEmpty
        let extraPicked = editSelected?.hasPrefix("extra:") == true
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button("Cancel") { finishEditing(save: false) }
                    .buttonStyle(EditChipStyle())
                Button { undo() } label: { Image(systemName: "arrow.uturn.backward").accessibilityLabel("Undo") }
                    .buttonStyle(EditChipStyle())
                    .disabled(undoStack.isEmpty)
                Spacer(minLength: 0)
                Button { turnSelected() } label: { Label("Turn", systemImage: "rotate.right").labelStyle(.iconOnly) }
                    .buttonStyle(EditChipStyle())
                    .disabled(editSelected == nil)
                    .accessibilityLabel("Turn")
                if extraPicked {
                    Button { removeSelectedExtra() } label: { Label("Remove", systemImage: "trash").labelStyle(.iconOnly) }
                        .buttonStyle(EditChipStyle())
                        .accessibilityLabel("Remove")
                }
                Button("Tidy up") { tidyUp() }
                    .buttonStyle(EditChipStyle())
                Spacer(minLength: 0)
                Button("Done") { finishEditing(save: true) }
                    .buttonStyle(EditChipStyle())
                    .disabled(blocked)
            }
            Text(editSelected == nil ? "Drag a Place or an extra to move it. Tap one to turn it."
                 : blocked ? "That spot overlaps something, or isn't on land." : "Green means it fits. Drag, turn, or tap Done.")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
        }
        .padding(12)
        .background(Color.cream.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    /// Each Place's chapters, as "book:count,…".
    private static func signature(_ island: Island) -> String {
        island.items.compactMap { item -> String? in
            if item.kind == .library { return "library:\(Int(item.growth))" }
            guard case .place(let id, 0) = item.source else { return nil }
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
        let all = UnlockNotices.all(island: island, crowns: crowns)
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
        let signature = Self.signature(island)
        let libraryStage = island.index(of: .library).map { LibraryArt.stage(of: island.items[$0]) }
        let librarySeen = libraryStageSeen
        defer {
            gardenSeen = island.items.count
            progressSeen = signature.split(separator: ",").filter { !$0.hasPrefix("library:") }.joined(separator: ",")
            if let libraryStage { libraryStageSeen = libraryStage.rawValue }
        }
        // The first look (or the first after the move to growing Places) is quiet.
        guard gardenSeen >= 0 else { return }
        let before = Dictionary(progressSeen.split(separator: ",").compactMap { pair -> (String, Int)? in
            let parts = pair.split(separator: ":")
            guard parts.count == 2, let n = Int(parts[1]) else { return nil }
            return (String(parts[0]), n)
        }, uniquingKeysWith: { a, _ in a })
        var plan = RevealPlanner.plan(island: island, before: before, chapterOrder: chapterOrder)
        // The Library growing plays last, as the biggest moment (the first look at it is quiet).
        if librarySeen >= 0, let seen = LibraryStage(rawValue: librarySeen),
           let step = RevealPlanner.libraryStep(island: island, seen: seen) {
            plan.steps.append(step)
            for change in step.changes { plan.initial[change.index] = change.from }
        }
        guard !plan.steps.isEmpty else { return }
        reveal = plan.steps
        revealInitial = plan.initial
        revealActive = true
        revealID += 1
    }

    /// Each book's distinct checked chapters, in the order first read.
    private var chapterOrder: [String: [Int]] {
        var out: [String: [Int]] = [:]
        var seen: Set<String> = []
        for read in chapterReads.filter(\.checked).sorted(by: { $0.date < $1.date }) where seen.insert("\(read.bookID)#\(read.chapterNumber)").inserted {
            out[read.bookID, default: []].append(read.chapterNumber)
        }
        return out
    }

    #if DEBUG
    private func debugOpen(_ island: Island) {
        let args = ProcessInfo.processInfo.arguments
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
        if args.contains("-fullBiblePreview") { debugBiblePreview = true }
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
        // "-tapKind place|tree|banner|lantern|library" taps the first island item of that kind.
        if let i = args.firstIndex(of: "-tapKind"), i + 1 < args.count {
            let wanted = args[i + 1]
            let index = island.items.firstIndex { item in
                switch item.source {
                case .place: wanted == "place"
                case .flourish: wanted == "flourish"
                case .forest: wanted == "tree"
                case .quiz: wanted == "banner"
                case .verse: wanted == "lantern"
                case .feature: wanted == "library"
                case .extra: wanted == "extra"
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

    /// The Extras tray: decorations earned through reading streaks.
    private var extrasTray: some View {
        let left = extrasLeft
        return VStack(alignment: .leading, spacing: 6) {
            Text("Extras").font(.caption.weight(.bold)).foregroundStyle(Color.secondaryText).textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExtraKind.allCases, id: \.self) { kind in
                        let n = max(0, left[kind] ?? 0)
                        Button { addExtra(kind) } label: {
                            VStack(spacing: 2) {
                                Image(systemName: kind.symbol).font(.title3)
                                Text("\(kind.name) ×\(n)").font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(Color.primaryBrown.opacity(n > 0 ? 1 : 0.4))
                            .frame(width: 76, height: 56)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(n == 0)
                        .accessibilityHint(n == 0 ? RewardData.extraHint(kind) : "Places one on the island")
                    }
                }
            }
            if left.values.allSatisfy({ $0 <= 0 }) {
                Text("Keep a reading streak to earn paths, fences, benches, trees and lamps.")
                    .font(.caption).foregroundStyle(Color.secondaryText)
            }
        }
        .padding(12)
        .background(Color.cream.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
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

/// The caption under the "see it built" moment: what the chapter built, and how far the Place is.
struct RevealCaption: View {
    let step: RevealStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if step.kind == .found || step.kind == .complete || step.kind == .library {
                Text(step.kind == .found ? "A new Place is founded" : step.kind == .library ? "The Library grows" : "Complete!")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.terracotta)
                    .textCase(.uppercase)
            }
            Text(step.caption)
                .font(.serifTitle(.headline))
                .foregroundStyle(Color.bodyText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ProgressView(value: step.progress).tint(Color.olive)
                Text(step.progressLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            Text("Tap anywhere to skip")
                .font(.caption2)
                .foregroundStyle(Color.secondaryText.opacity(0.7))
        }
        .padding(16)
        .frame(maxWidth: 420, alignment: .leading)
        .background(Color.cream.opacity(0.97), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.primaryBrown.opacity(0.16), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}
