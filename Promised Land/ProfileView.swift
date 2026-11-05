import SwiftUI
import SwiftData

/// Profile: your character (tap to edit), your reading at a glance, your characters and
/// crowns, and sharing. Settings are behind the gear.
struct ProfileView: View {
    /// Opens edit mode on the island (closing this sheet).
    var onEditIsland: (() -> Void)? = nil
    /// Your island, for the share image.
    var island: Island = .empty

    @CurrentAvatar private var avatar: Avatar
    @ProgressQuery private var progress: GameProgress
    @Query private var reads: [ChapterRead]
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false
    @State private var editingCharacter = false
    @State private var showingStats = false
    @State private var showingCrowns = false
    @State private var showingThrone = false
    @State private var openJourney: JourneyLink?
    @State private var sharing: ShareImage?
    @State private var showingBasket = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    characterCard
                    stats
                    mostRead
                    charactersShelf
                    crownsShelf
                    if let onEditIsland {
                        Button { onEditIsland() } label: { row("Edit island", systemImage: "square.and.pencil") }
                            .buttonStyle(.plain)
                    }
                    Button { showingBasket = true } label: { row("Your basket", systemImage: "basket.fill") }
                        .buttonStyle(.plain)
                    Button { showingStats = true } label: { row("Reading history", systemImage: "chart.bar.fill") }
                        .buttonStyle(.plain)
                }
                .padding(16)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .themedScreen()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape.fill") }
                        .tint(Color.primaryBrown)
                        .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $editingCharacter) { AvatarCustomizeView() }
            .sheet(isPresented: $showingStats) { StatsView() }
            .sheet(isPresented: $showingBasket) { BasketView() }
            .sheet(isPresented: $showingCrowns) { CrownsView() }
            .sheet(isPresented: $showingThrone) { ThroneRoomView() }
            .sheet(item: $sharing) { SharePreviewSheet(image: $0.image) }
            .sheet(item: $openJourney) { link in
                if let journey = CharacterJourneys.journey(id: link.id) {
                    NavigationStack { JourneyMapView(journey: journey).readingDestinations() }
                }
            }
        }
    }

    // MARK: Sections

    private var characterCard: some View {
        VStack(spacing: 10) {
            Button { editingCharacter = true } label: {
                ZStack {
                    SandPlot().frame(width: 150, height: 86).offset(y: 46)
                    AvatarFigure(avatar: avatar).frame(width: 70, height: 112).offset(y: -6)
                }
                .frame(height: 176)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit your character")
            Text(avatar.name.isEmpty ? "Your character" : avatar.name)
                .font(.serifTitle(.title2))
                .foregroundStyle(Color.bodyText)
            HStack(spacing: 10) {
                Button("Edit avatar") { editingCharacter = true }
                    .buttonStyle(SoftButtonStyle())
                Button { share() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(SoftButtonStyle())
            }
        }
        .cardStyle()
    }

    private var stats: some View {
        let distinct = Set(reads.map { "\($0.bookID)#\($0.chapterNumber)" }).count
        let rereads = max(0, reads.count - distinct)
        let journeysDone = progress.unlockedJourneys.count
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tile("\(progress.streak)", "day streak")
            tile("\(progress.chaptersReadThisYear)", "chapters this year")
            tile("\(rereads)", rereads == 1 ? "reread" : "rereads")
            tile("\(Int((progress.overallFraction * 100).rounded(.down)))%", "of the Bible")
            tile("\(journeysDone) of \(CharacterJourneys.all.count)", "journeys completed")
            tile("\(progress.startedCount)", progress.startedCount == 1 ? "place begun" : "places begun")
        }
    }

    @ViewBuilder
    private var mostRead: some View {
        let counts = Dictionary(grouping: reads, by: \.bookID).mapValues(\.count)
        let top = counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(3)
        if !top.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Most-read books").font(.serifTitle(.title3)).foregroundStyle(Color.bodyText)
                ForEach(Array(top), id: \.key) { entry in
                    HStack {
                        Text(BibleCatalog.book(id: entry.key)?.name ?? entry.key).foregroundStyle(Color.bodyText)
                        Spacer()
                        Text("\(entry.value) \(entry.value == 1 ? "read" : "reads")")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Color.secondaryText)
                    }
                    .frame(minHeight: 32)
                }
            }
            .cardStyle()
        }
    }

    private var charactersShelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Characters").font(.serifTitle(.title3)).foregroundStyle(Color.bodyText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(CharacterJourneys.all) { j in
                        let done = progress.journeyProgress(j).isComplete
                        Button { openJourney = JourneyLink(id: j.id) } label: {
                            VStack(spacing: 4) {
                                CharacterFigure(id: j.characterId, look: Avatar(config: AvatarPresets.config(for: j.characterId)))
                                    .frame(width: 58, height: 80)
                                    .saturation(done ? 1 : 0)
                                    .opacity(done ? 1 : 0.35)
                                Text(j.name).font(.caption2.weight(.semibold)).foregroundStyle(Color.bodyText)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(j.name), \(done ? "unlocked" : "locked")")
                    }
                }
                .padding(.horizontal, 6)
            }
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#C79A6C")).frame(height: 8)
        }
        .cardStyle()
    }

    private var crownsShelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Crowns").font(.serifTitle(.title3)).foregroundStyle(Color.bodyText)
                Spacer()
                Text("\(progress.totalCrownsAvailable) to lay down · \(progress.totalCrownsEarned) earned")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Color.secondaryText)
            }
            Text("Each full reread of a book earns a crown. Read the whole Bible to open the throne room.")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
            HStack(spacing: 10) {
                Button("See your crowns") { showingCrowns = true }
                    .buttonStyle(SoftButtonStyle())
                if progress.hasCompletedBible {
                    Button("Throne room") { showingThrone = true }
                        .buttonStyle(SoftButtonStyle())
                }
            }
        }
        .cardStyle()
    }

    // MARK: Pieces

    private func share() {
        let image = ShareRender.card(title: avatar.name.isEmpty ? "My Promised Land" : "\(avatar.name)'s Promised Land",
                                     subtitle: "\(progress.startedCount) of 66 places begun",
                                     artwork: IslandPicture(island: island),
                                     avatar: avatar, streak: progress.streak, chaptersThisYear: progress.chaptersReadThisYear)
        if let image { sharing = ShareImage(image: image) }
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .serif).weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.bodyText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func row(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage).font(.headline).foregroundStyle(Color.bodyText)
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.secondaryText.opacity(0.6))
        }
        .padding(16)
        .frame(minHeight: 56)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview("Profile") {
    ProfileView().modelContainer(PreviewData.container)
}
