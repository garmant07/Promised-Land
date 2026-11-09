import SwiftUI

// Someone else's island (a friend's, or a group's shared one), shown the way you see your own:
// full screen, drawn by the same `PlatformScene`, with pan, zoom, turn and Find me, and tapping a
// building to step inside. Read-only: nothing can be moved, read or collected.

/// An island you're visiting: whose it is and what built it.
struct VisitedIsland: Identifiable {
    enum Owner {
        case friend(FriendSummary)
        case group(GroupSummary)
    }

    let owner: Owner

    var id: String {
        switch owner {
        case .friend(let f): "friend:\(f.id)"
        case .group(let g): "group:\(g.id)"
        }
    }

    /// Shown at the top, so it's clear this isn't your island: "Hannah's Island",
    /// "Sample Youth Group Island".
    var title: String {
        switch owner {
        case .friend(let f): Self.friendTitle(f.name)
        case .group(let g): Self.groupTitle(g.name)
        }
    }

    var isPreview: Bool {
        switch owner {
        case .friend(let f): f.isSample
        case .group(let g): g.isPreview
        }
    }

    /// Every read that built it.
    var reads: [(book: String, chapter: Int, date: Date)] {
        switch owner {
        case .friend(let f): f.reads
        case .group(let g): g.combinedReads
        }
    }

    var avatar: Avatar {
        switch owner {
        case .friend(let f): f.avatar
        case .group(let g): g.members.first?.avatar ?? .default
        }
    }

    var notes: [SharedNote] {
        if case .friend(let f) = owner { return f.notes }
        return []
    }

    /// Built exactly as their island is: from their reads.
    func build() -> Island { Island.build(chapters: reads, quizzes: [], verses: []) }

    /// "Hannah (sample)" → "Hannah's Island".
    static func friendTitle(_ name: String) -> String {
        let first = name.replacingOccurrences(of: " (sample)", with: "").trimmingCharacters(in: .whitespaces)
        return "\(first)\u{2019}s Island"
    }

    /// "Sample youth group" → "Sample Youth Group Island".
    static func groupTitle(_ name: String) -> String {
        let words = name.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }
        let titled = words.joined(separator: " ")
        return titled.hasSuffix("Island") ? titled : "\(titled) Island"
    }

    /// For the read-only inside of one of its buildings: the book's chapters they've read.
    func chaptersRead(_ bookID: String) -> Set<Int> {
        Set(reads.filter { $0.book == bookID }.map(\.chapter))
    }
}

/// Full screen: their island, a title bar (back, whose island, about), and stepping inside.
struct VisitedIslandView: View {
    let visiting: VisitedIsland
    var onClose: () -> Void

    @State private var island = Island(tiles: [], items: [])
    @State private var life = IslandLife()
    @State private var selected: Int?
    @State private var visitIndex: Int?
    @State private var inside: InsideRef?
    @State private var card: FriendItemCard.Subject?
    @State private var showingAbout = false
    @State private var safeTop: CGFloat = 0
    @State private var cloudsUp = true
    @State private var loaded = false

    struct InsideRef: Identifiable { let bookID: String; var id: String { bookID } }

    var body: some View {
        ZStack(alignment: .top) {
            Earthy.sea.ignoresSafeArea()
            PlatformScene(avatar: visiting.avatar, island: island,
                          insets: EdgeInsets(top: 64 + safeTop, leading: 8, bottom: 40, trailing: 8),
                          selected: $selected, showsControls: true,
                          visit: visitIndex,
                          onArrived: { index in
                              guard island.items.indices.contains(index), let bookID = island.items[index].source.bookID else {
                                  visitIndex = nil; return
                              }
                              inside = InsideRef(bookID: bookID)
                          },
                          life: life,
                          paused: inside != nil,
                          onLoaded: { loaded = true },
                          holdsBackgroundWork: cloudsUp) { index in tap(index) }
                .ignoresSafeArea()
            // The same clouds as your own island while theirs loads (under the title bar, so Back works).
            if cloudsUp {
                CloudCover(loaded: loaded) { cloudsUp = false }
            }
            titleBar
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { safeTop = $0 }
        .onAppear {
            island = visiting.build()
            life = IslandLife.make(island: island)
            IslandCovers.shared.covered += 1
            #if DEBUG
            // "-visitInside ruth" steps straight inside that building (with -visitIsland).
            if let id = OpenTiming.argument("-visitInside") { inside = InsideRef(bookID: id) }
            #endif
        }
        .onDisappear { IslandCovers.shared.covered -= 1 }
        .fullScreenCover(item: $inside, onDismiss: { visitIndex = nil; selected = nil }) { ref in
            VisitedInsideView(visiting: visiting, bookID: ref.bookID) { inside = nil }
        }
        .sheet(item: $card, onDismiss: { selected = nil }) { FriendItemCard(subject: $0).presentationDetents([.medium]) }
        .sheet(isPresented: $showingAbout) { VisitedIslandAbout(visiting: visiting, island: island) }
    }

    /// The same as tapping on your own island: a building is stepped into (walk over, the camera
    /// centres it, then its inside opens); anything else shows a small card.
    private func tap(_ index: Int?) {
        guard let index, island.items.indices.contains(index) else { selected = nil; return }
        let item = island.items[index]
        selected = index
        switch item.source {
        case .place, .feature:
            if item.source.bookID != nil { visitIndex = index } else { card = .init(item: item, notes: visiting.notes) }
        default:
            card = .init(item: item, notes: visiting.notes)
        }
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "chevron.backward")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(Color.cream.opacity(0.95), in: Circle())
            }
            .accessibilityLabel("Back")
            VStack(spacing: 2) {
                Text(visiting.title)
                    .font(.serifTitle(.title3))
                    .foregroundStyle(Color.bodyText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if visiting.isPreview { PreviewTag() }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Color.cream.opacity(0.95), in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Button { showingAbout = true } label: {
                Image(systemName: "info")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(Color.cream.opacity(0.95), in: Circle())
            }
            .accessibilityLabel("About this island")
        }
        .foregroundStyle(Color.primaryBrown)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}

/// Inside one of their buildings (read-only): its art, which of the book's chapters built it, and
/// any notes they shared about it.
struct VisitedInsideView: View {
    let visiting: VisitedIsland
    let bookID: String
    var onClose: () -> Void

    var body: some View {
        let book = BibleCatalog.book(id: bookID)
        let read = visiting.chaptersRead(bookID)
        let totalReads = visiting.reads.filter { $0.book == bookID }.count
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    InteriorHeaderArt(bookID: bookID, distinct: read.count, totalReads: totalReads)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                    Text(PlaceData.spec(for: bookID).name)
                        .font(.serifTitle(.largeTitle))
                        .foregroundStyle(Color.bodyText)
                    if let book {
                        Text("\(read.count) of \(book.chapterCount) chapters of \(book.name) read")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                            ForEach(1...book.chapterCount, id: \.self) { chapter in
                                let isRead = read.contains(chapter)
                                Text("\(chapter)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(isRead ? Color.primaryBrown : Color.secondaryText)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(isRead ? Color.wheat.opacity(0.45) : Color.card,
                                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .accessibilityLabel("Chapter \(chapter), \(isRead ? "read" : "not read")")
                            }
                        }
                    }
                    ForEach(visiting.notes.filter { $0.bookID == bookID }) { note in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shared note on chapter \(note.chapter)").font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
                            Text("\u{201C}\(note.text)\u{201D}").italic().foregroundStyle(Color.bodyText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(16)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .themedScreen()
            .navigationTitle(visiting.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) { Label("Back to the island", systemImage: "chevron.backward") }
                        .tint(Color.primaryBrown)
                }
            }
        }
    }
}

/// About an island you're visiting: the stats and shared notes (a friend), or who read what (a group).
struct VisitedIslandAbout: View {
    let visiting: VisitedIsland
    let island: Island

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch visiting.owner {
                    case .friend(let friend): FriendIslandDetails(friend: friend, island: island)
                    case .group(let group): GroupIslandDetails(group: group)
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle(visiting.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

/// Counts islands of other people open full screen, so your own can hold still behind them.
@MainActor @Observable
final class IslandCovers {
    static let shared = IslandCovers()
    var covered = 0
}
