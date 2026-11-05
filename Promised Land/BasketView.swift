import SwiftUI
import SwiftData

/// Your basket: produce collected from complete Places, to give to the crowd in the plaza or to
/// keep for a friend's island. Giving bread and fish together feeds the crowd. Everything stays on
/// this device: gifts for friends are only noted here (there's no network).
struct BasketView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProduceCollection.date) private var collected: [ProduceCollection]
    @Query(sort: \ProduceGift.date, order: .reverse) private var gifts: [ProduceGift]
    @State private var feeding = false
    @State private var choosingFriend: ProduceKind?
    @State private var note: String?

    private var inventory: [ProduceKind: Int] {
        ProduceRules.inventory(collected: collected.compactMap { c in ProduceKind(rawValue: c.kind).map { ($0, c.amount) } },
                               given: gifts.compactMap { g in ProduceKind(rawValue: g.kind).map { ($0, g.amount) } })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Complete Places fill a basket on each day you read. Tap a basket on the island to collect it.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                    if inventory.isEmpty {
                        Label("Your basket is empty for now.", systemImage: "basket")
                            .foregroundStyle(Color.secondaryText)
                            .cardStyle()
                    } else {
                        VStack(spacing: 10) {
                            ForEach(ProduceKind.allCases.filter { inventory[$0] != nil }, id: \.self) { kind in row(kind) }
                        }
                        .cardStyle()
                        if ProduceRules.isFeedingTheCrowd(inventory) {
                            Button { give([.bread: 1, .fish: 1], to: "crowd") } label: {
                                Label("Share bread and fish with the crowd", systemImage: "person.3.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    if let note {
                        Text(note).font(.footnote).foregroundStyle(Color.olive)
                    }
                    let saved = gifts.filter { $0.recipient.hasPrefix("friend:") }
                    if !saved.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kept for friends").font(.serifTitle(.title3)).foregroundStyle(Color.bodyText)
                            ForEach(saved) { gift in
                                Text("\(gift.amount) \(ProduceKind(rawValue: gift.kind)?.name.lowercased() ?? gift.kind) for \(friendName(gift.recipient))")
                                    .font(.subheadline).foregroundStyle(Color.secondaryText)
                            }
                            Text("They'll be delivered when visiting friends' islands is ready.")
                                .font(.footnote).foregroundStyle(Color.secondaryText)
                        }
                        .cardStyle()
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Your basket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(Color.primaryBrown) }
            }
            .confirmationDialog("Keep it for which friend?", isPresented: Binding(get: { choosingFriend != nil }, set: { if !$0 { choosingFriend = nil } }),
                                titleVisibility: .visible) {
                ForEach(MockFriendsService.samples) { friend in
                    Button(friend.name) {
                        if let kind = choosingFriend { give([kind: 1], to: "friend:\(friend.id)") }
                    }
                }
            }
            .sheet(isPresented: $feeding) { FeedingTheCrowdView() }
        }
    }

    private func row(_ kind: ProduceKind) -> some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .foregroundStyle(IslandLife.colour(kind))
                .frame(width: 36, height: 36)
                .background(Color.sand, in: Circle())
            Text("\(inventory[kind] ?? 0) \(kind.name.lowercased())")
                .font(.headline).foregroundStyle(Color.bodyText)
            Spacer()
            Button("Give") { give([kind: 1], to: "crowd") }
                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            Button("Keep for a friend") { choosingFriend = kind }
                .font(.subheadline).frame(minHeight: 44)
        }
        .foregroundStyle(Color.primaryBrown)
    }

    private func give(_ gift: [ProduceKind: Int], to recipient: String) {
        context.giveProduce(gift, to: recipient)
        if recipient == "crowd" {
            if ProduceRules.isFeedingTheCrowd(gift) { feeding = true }
            note = "The crowd in the plaza thanks you."
        } else {
            note = "Kept for \(friendName(recipient))."
        }
    }

    private func friendName(_ recipient: String) -> String {
        let id = recipient.replacingOccurrences(of: "friend:", with: "")
        return MockFriendsService.samples.first { $0.id == id }?.name ?? "a friend"
    }
}

/// The "feeding the crowd" moment, when bread and fish are given together.
struct FeedingTheCrowdView: View {
    @Environment(\.dismiss) private var dismiss
    private let entry = FeedingTheCrowd.entry

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            HStack(spacing: 16) {
                Image(systemName: ProduceKind.bread.symbol).foregroundStyle(IslandLife.colour(.bread))
                Image(systemName: ProduceKind.fish.symbol).foregroundStyle(IslandLife.colour(.fish))
            }
            .font(.system(size: 48))
            Text("Everyone was fed")
                .font(.serifTitle(.largeTitle))
                .foregroundStyle(Color.bodyText)
            if ContentGate.isVisible(entry) {
                VStack(spacing: 8) {
                    Text("\u{201C}\(entry.quote)\u{201D}")
                        .font(.system(.title3, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.bodyText)
                    HStack(spacing: 6) {
                        Text(entry.reference).font(.footnote).foregroundStyle(Color.secondaryText)
                        DraftBadge(item: entry)
                    }
                }
            }
            Text("You shared bread and fish with the crowd in the plaza.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondaryText)
            Spacer()
            Button("Wonderful") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream.ignoresSafeArea())
    }
}

#Preview("Basket") {
    BasketView().modelContainer(PreviewData.container)
}

#Preview("Feeding the crowd") {
    FeedingTheCrowdView()
}
