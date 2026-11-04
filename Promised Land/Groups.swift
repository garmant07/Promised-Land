import SwiftUI

// Groundwork for reading together as a group (see GROUPS.md). Today everything is sample data
// on the device, clearly labelled "Preview"; nothing is sent anywhere. A real backend can
// implement `GroupsService` later without changing the views.

/// Someone in a group. Only what they've chosen to share.
struct GroupMember: Identifiable, Hashable {
    let id: String
    let name: String
    let avatar: Avatar
    /// Their reads (shared with the group).
    let reads: [(book: String, chapter: Int, date: Date)]

    static func == (lhs: GroupMember, rhs: GroupMember) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A reading group and its shared island.
struct GroupSummary: Identifiable, Hashable {
    let id: String
    let name: String
    let members: [GroupMember]
    /// Sample data, shown with a "Preview" label.
    var isPreview = true

    /// Everyone's reads together: each one builds the shared island.
    var combinedReads: [(book: String, chapter: Int, date: Date)] {
        members.flatMap(\.reads).sorted { $0.date < $1.date }
    }

    /// Who read what: for each book, members and their distinct chapters, most first.
    var contributions: [(book: String, members: [(name: String, chapters: Int)])] {
        var byBook: [String: [String: Set<Int>]] = [:]
        for m in members {
            for r in m.reads { byBook[r.book, default: [:]][m.name, default: []].insert(r.chapter) }
        }
        let order = Dictionary(uniqueKeysWithValues: BibleCatalog.books.enumerated().map { ($1.id, $0) })
        return byBook.keys.sorted { (order[$0] ?? 0) < (order[$1] ?? 0) }.map { book in
            (book, byBook[book]!.map { (name: $0.key, chapters: $0.value.count) }.sorted { ($0.chapters, $1.name) > ($1.chapters, $0.name) })
        }
    }

    static func == (lhs: GroupSummary, rhs: GroupSummary) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Where groups come from.
protocol GroupsService {
    func groups() async throws -> [GroupSummary]
}

/// One sample group for the preview. Read-only; nothing leaves the device.
struct MockGroupsService: GroupsService {
    func groups() async throws -> [GroupSummary] { [Self.sample] }

    static let sample = GroupSummary(
        id: "sample-group",
        name: "Sample youth group",
        members: MockFriendsService.samples.map { f in
            GroupMember(id: f.id, name: f.name.replacingOccurrences(of: " (sample)", with: ""), avatar: f.avatar, reads: f.reads)
        })
}

// MARK: - Views

/// A row for a group, in Friends.
struct GroupRow: View {
    let group: GroupSummary

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: -10) {
                ForEach(group.members.prefix(3)) { m in
                    AvatarFigure(avatar: m.avatar)
                        .frame(width: 22, height: 40)
                        .frame(width: 30, height: 46)
                        .background(Color.sand, in: Circle())
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.name).font(.headline).foregroundStyle(Color.bodyText)
                    if group.isPreview { PreviewTag() }
                }
                Text("\(group.members.count) members · one shared island")
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
}

/// The group's shared island (read-only), and who read what.
struct GroupIslandView: View {
    let group: GroupSummary

    var body: some View {
        let island = Island.build(chapters: group.combinedReads, quizzes: [], verses: [])
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if group.isPreview {
                    Label("Preview: a sample group, not real people. Every member's reading builds one shared island; your own island stays yours.",
                          systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(Color.primaryBrown)
                        .padding(12)
                        .background(Color.sand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                PlatformScene(avatar: group.members.first?.avatar ?? .default, island: island)
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .allowsHitTesting(false)
                    .accessibilityLabel("The group's shared island")
                Text("Who read what")
                    .font(.serifTitle(.title3))
                    .foregroundStyle(Color.bodyText)
                ForEach(group.contributions, id: \.book) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(BibleCatalog.book(id: entry.book)?.name ?? entry.book)
                            .font(.headline)
                            .foregroundStyle(Color.bodyText)
                        Text(entry.members.map { "\($0.name) \($0.chapters) ch" }.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Text("Journal entries and reflections stay private unless someone chooses to share one.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .themedScreen()
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A small "Preview" label for sample data.
struct PreviewTag: View {
    var body: some View {
        Text("Preview")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.onPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.terracotta, in: Capsule())
    }
}
