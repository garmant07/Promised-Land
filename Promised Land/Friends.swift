import SwiftUI

// MARK: - Service

/// What we know about a friend. Read-only.
struct FriendSummary: Identifiable, Hashable {
    let id: String
    let name: String
    let avatar: Avatar
    let streak: Int
    /// Every read, for drawing their island.
    let reads: [(book: String, chapter: Int, date: Date)]
    var isSample = true
    /// Notes they've chosen to share (journal entries stay private unless shared).
    var notes: [SharedNote] = []

    var chaptersRead: Int { Set(reads.map { "\($0.book)#\($0.chapter)" }).count }

    static func == (lhs: FriendSummary, rhs: FriendSummary) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A note a friend chose to share about a chapter.
struct SharedNote: Hashable, Identifiable {
    let bookID: String
    let chapter: Int
    let text: String
    var id: String { "\(bookID)#\(chapter)#\(text.hashValue)" }
}

/// Where friends come from. Today: sample data on the device. Later: a real backend
/// can implement this protocol without changing the views.
protocol FriendsService {
    func friends() async throws -> [FriendSummary]
}

/// The sample friends' looks.
enum FriendLooks {
    static var hannah: AvatarConfig {
        var a = AvatarConfig(); a.skin = .warm; a.hair = .longStraight; a.hairColour = .darkBrown; a.head = .none
        a.robeColour = .slatePurple; a.sash = .goldTrim; a.sandals = .tan; a.item = .scroll; return a
    }
    static var eli: AvatarConfig {
        var a = AvatarConfig(); a.skin = .brown; a.hair = .shortCurly; a.hairColour = .darkBrown; a.head = .none
        a.robe = .kneeTunic; a.robeColour = .skyBlue; a.sash = .brownBelt; a.cloak = .shoulderCloak; a.cloakColour = .sand
        a.sandals = .darkBrown; return a
    }
    static var joy: AvatarConfig {
        var a = AvatarConfig(); a.skin = .porcelain; a.hair = .longWavy; a.hairColour = .lightBrown; a.head = .headband
        a.headColour = .rose; a.robeColour = .sage; a.sash = .none; a.item = .dove; a.sandals = .tan; return a
    }
}

/// Sample friends for the preview. Clearly labelled; nothing leaves the device.
struct MockFriendsService: FriendsService {
    func friends() async throws -> [FriendSummary] { Self.samples }

    static let samples: [FriendSummary] = [
        FriendSummary(id: "sample-hannah", name: "Hannah (sample)",
                      avatar: Avatar(name: "Hannah", config: FriendLooks.hannah),
                      streak: 12, reads: plan([("genesis", 1...50), ("ruth", 1...4), ("psalms", 1...30), ("john", 1...21)]),
                      notes: [SharedNote(bookID: "ruth", chapter: 1, text: "Sample note: Ruth staying with Naomi really stuck with me this week."),
                              SharedNote(bookID: "psalms", chapter: 23, text: "Sample note: read this one slowly before school.")]),
        FriendSummary(id: "sample-eli", name: "Eli (sample)",
                      avatar: Avatar(name: "Eli", config: FriendLooks.eli),
                      streak: 3, reads: plan([("mark", 1...16), ("acts", 1...12), ("jonah", 1...4)]),
                      notes: [SharedNote(bookID: "jonah", chapter: 4, text: "Sample note: I didn't expect the book to end with a question.")]),
        FriendSummary(id: "sample-joy", name: "Joy (sample)",
                      avatar: Avatar(name: "Joy", config: FriendLooks.joy),
                      streak: 27, reads: plan([("proverbs", 1...31), ("luke", 1...24), ("psalms", 1...60), ("exodus", 1...20)]),
                      notes: [SharedNote(bookID: "luke", chapter: 15, text: "Sample note: three lost things, three parties.")]),
    ]

    /// Spreads a reading plan over the past months, one chapter a day.
    private static func plan(_ ranges: [(String, ClosedRange<Int>)]) -> [(book: String, chapter: Int, date: Date)] {
        let all = ranges.flatMap { book, chapters in chapters.map { (book, $0) } }
        return all.enumerated().map { i, read in
            (read.0, read.1, Date.now.addingTimeInterval(-Double(all.count - i) * 86_400))
        }
    }
}

// MARK: - Views

/// A friend's building or artifact: what built it, and any notes they shared about it.
struct FriendItemCard: View {
    struct Subject: Identifiable {
        let item: Island.Item
        let notes: [SharedNote]
        var id: String { "\(item.gx),\(item.gy)" }
    }
    let subject: Subject

    var body: some View {
        let bookID = subject.item.source.bookID
        let book = bookID.flatMap { BibleCatalog.book(id: $0) }
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.serifTitle(.title2)).foregroundStyle(Color.bodyText)
            if let book {
                Text(detail(book)).font(.subheadline).foregroundStyle(Color.secondaryText)
            }
            ForEach(subject.notes.filter { $0.bookID == bookID }) { note in
                Text("\u{201C}\(note.text)\u{201D}").italic().foregroundStyle(Color.bodyText)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cream.ignoresSafeArea())
    }

    private var title: String {
        if case .place(let id, _) = subject.item.source { return PlaceData.spec(for: id).name }
        return InsightSubject.name(of: subject.item.kind)
    }

    private func detail(_ book: Book) -> String {
        switch subject.item.source {
        case .forest(_, let ch): "Grown by reading \(book.name) \(ch)."
        case .place: subject.item.progress >= subject.item.total ? "Built by reading all of \(book.name)." : "\(subject.item.progress) of \(book.name)'s \(subject.item.total) chapters read."
        default: "From reading \(book.name)."
        }
    }
}

struct FriendsView: View {
    var service: any FriendsService = MockFriendsService()
    var groupsService: any GroupsService = MockGroupsService()
    @State private var friends: [FriendSummary] = []
    @State private var groups: [GroupSummary] = []
    @State private var visiting: VisitedIsland?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Preview: friends coming soon. These are sample friends, not real people.",
                          systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(Color.primaryBrown)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.sand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    if !groups.isEmpty {
                        Text("Groups")
                            .font(.serifTitle(.title3))
                            .foregroundStyle(Color.bodyText)
                            .padding(.top, 4)
                        ForEach(groups) { group in
                            Button { visiting = VisitedIsland(owner: .group(group)) } label: { GroupRow(group: group) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens their island")
                        }
                        Text("Friends")
                            .font(.serifTitle(.title3))
                            .foregroundStyle(Color.bodyText)
                            .padding(.top, 4)
                    }
                    ForEach(friends) { friend in
                        Button { visiting = VisitedIsland(owner: .friend(friend)) } label: {
                            HStack(spacing: 14) {
                                AvatarFigure(avatar: friend.avatar)
                                    .frame(width: 34, height: 60)
                                    .frame(width: 56, height: 64)
                                    .background(Color.sand.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(friend.name).font(.headline).foregroundStyle(Color.bodyText)
                                    Text("\(friend.chaptersRead) chapters · \(friend.streak)-day streak")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.secondaryText.opacity(0.6))
                            }
                            .padding(12)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Friends (preview)")
            .navigationBarTitleDisplayMode(.inline)
            // Their island opens full screen, like your own (see VisitedIslandView).
            .fullScreenCover(item: $visiting) { VisitedIslandView(visiting: $0) { visiting = nil } }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
            }
            .task {
                friends = (try? await service.friends()) ?? []
                groups = (try? await groupsService.groups()) ?? []
                #if DEBUG
                // "-visitIsland group" or "-visitIsland sample-hannah" opens that island (with -openFriends).
                if let id = OpenTiming.argument("-visitIsland") {
                    if id == "group", let g = groups.first { visiting = VisitedIsland(owner: .group(g)) }
                    else if let f = friends.first(where: { $0.id == id }) { visiting = VisitedIsland(owner: .friend(f)) }
                }
                #endif
            }
        }
    }
}

/// A friend's stats and shared notes (in "About this island", over their full-screen island).
struct FriendIslandDetails: View {
    let friend: FriendSummary
    let island: Island

    var body: some View {
        VStack(spacing: 16) {
            if friend.isSample {
                Text("Preview: friends coming soon")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.onPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.terracotta, in: Capsule())
            }
            HStack(spacing: 12) {
                stat("\(friend.chaptersRead)", "chapters read")
                stat("\(friend.streak)", "day streak")
                stat("\(island.items.count)", "things built")
            }
            if !friend.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shared notes").font(.serifTitle(.title3)).foregroundStyle(Color.bodyText)
                    ForEach(friend.notes) { note in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(BibleCatalog.book(id: note.bookID)?.name ?? note.bookID) \(note.chapter)")
                                .font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
                            Text(note.text).foregroundStyle(Color.bodyText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .cardStyle()
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title3, design: .serif).weight(.semibold)).foregroundStyle(Color.bodyText)
            Text(label).font(.caption).foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    FriendsView()
}
