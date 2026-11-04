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

    var chaptersRead: Int { Set(reads.map { "\($0.book)#\($0.chapter)" }).count }

    static func == (lhs: FriendSummary, rhs: FriendSummary) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Where friends come from. Today: sample data on the device. Later: a real backend
/// can implement this protocol without changing the views.
protocol FriendsService {
    func friends() async throws -> [FriendSummary]
}

/// Sample friends for the preview. Clearly labelled; nothing leaves the device.
struct MockFriendsService: FriendsService {
    func friends() async throws -> [FriendSummary] { Self.samples }

    static let samples: [FriendSummary] = [
        FriendSummary(id: "sample-hannah", name: "Hannah (sample)",
                      avatar: Avatar(name: "Hannah", robe: "#BFA9DA", skin: "#D9A57E", hair: .long, hairColor: "#4A3326", sash: "#E9C77F", sandals: .tan),
                      streak: 12, reads: plan([("genesis", 1...50), ("ruth", 1...4), ("psalms", 1...30), ("john", 1...21)])),
        FriendSummary(id: "sample-eli", name: "Eli (sample)",
                      avatar: Avatar(name: "Eli", robe: "#93AECF", skin: "#8E5E3D", hair: .curly, hairColor: "#2F2418", sash: "#FAF0DE", sandals: .brown),
                      streak: 3, reads: plan([("mark", 1...16), ("acts", 1...12), ("jonah", 1...4)])),
        FriendSummary(id: "sample-joy", name: "Joy (sample)",
                      avatar: Avatar(name: "Joy", robe: "#A9B47C", skin: "#F6D9C0", hair: .bun, hairColor: "#B48A6A", sash: "#E39A7E", sandals: .tan),
                      streak: 27, reads: plan([("proverbs", 1...31), ("luke", 1...24), ("psalms", 1...60), ("exodus", 1...20)])),
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

struct FriendsView: View {
    var service: any FriendsService = MockFriendsService()
    @State private var friends: [FriendSummary] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Preview: these are sample friends, not real people. Reading together with real friends is coming later.",
                          systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(Color.primaryBrown)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.sand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    ForEach(friends) { friend in
                        NavigationLink(value: friend) {
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
            .navigationDestination(for: FriendSummary.self) { FriendWorldView(friend: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
            }
            .task { friends = (try? await service.friends()) ?? [] }
        }
    }
}

/// A read-only look at a friend's island.
struct FriendWorldView: View {
    let friend: FriendSummary

    var body: some View {
        let island = Island.build(chapters: friend.reads, quizzes: [], verses: [])
        ScrollView {
            VStack(spacing: 16) {
                if friend.isSample {
                    Text("Sample friend · preview")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.onPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.terracotta, in: Capsule())
                }
                PlatformScene(avatar: friend.avatar, island: island)
                    .allowsHitTesting(false)
                HStack(spacing: 12) {
                    stat("\(friend.chaptersRead)", "chapters read")
                    stat("\(friend.streak)", "day streak")
                    stat("\(island.items.count)", "things built")
                }
            }
            .padding(16)
        }
        .themedScreen()
        .navigationTitle(friend.name)
        .navigationBarTitleDisplayMode(.inline)
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
