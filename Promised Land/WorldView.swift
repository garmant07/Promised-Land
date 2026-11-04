import SwiftUI
import SwiftData
import SpriteKit

struct WorldView: View {
    @ProgressQuery private var progress: GameProgress
    let scene: WorldScene
    /// Shown as a close button when the map is presented from the home page.
    var onClose: (() -> Void)? = nil
    @State private var showingStats = false
    @State private var showingLibrary = false
    @State private var selectedJourney: Journey?
    @State private var showingCrowns = false
    @State private var showingThrone = false
    @State private var shareImage: ShareImage?
    @CurrentAvatar private var avatar: Avatar
    @Query private var journal: [JournalEntry]
    @State private var selectedStory: InsightSubject?
    @State private var cardCollapsed = false
    @State private var selected: Landmark?
    @State private var selectedConnection: Connection?
    @State private var minimap = MinimapModel()

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 60,
                       options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes],
                       debugOptions: debugOptions)
                .ignoresSafeArea()
                .accessibilityLabel("Map of your world")

            VStack(spacing: 0) {
                WorldHeader(progress: progress, onClose: onClose, openCrowns: { showingCrowns = true }) { showingStats = true }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(Color.cream.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 12)
                HStack {
                    Spacer()
                    MinimapView(progress: progress, model: minimap) { point in
                        scene.flyTo(point)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                Spacer()
                HStack(spacing: 10) {
                    Spacer()
                    Button(action: shareWorld) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(Color.primaryBrown)
                            .frame(width: 48, height: 48)
                            .background(Color.cream.opacity(0.94), in: Circle())
                            .shadow(color: Color.primaryBrown.opacity(0.15), radius: 6, y: 2)
                    }
                    .accessibilityLabel("Share your world")
                    Button { scene.recentre() } label: {
                        Image(systemName: "location.fill")
                            .font(.headline)
                            .foregroundStyle(Color.primaryBrown)
                            .frame(width: 48, height: 48)
                            .background(Color.cream.opacity(0.94), in: Circle())
                            .shadow(color: Color.primaryBrown.opacity(0.15), radius: 6, y: 2)
                    }
                    .accessibilityLabel("Recentre on your newest landmark")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                if let connection = selectedConnection {
                    ConnectionCard(connection: connection) { selectedConnection = nil }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let next = NextUnlock.suggest(from: progress) {
                    NextUnlockCard(next: next, collapsed: $cardCollapsed) { selected = $0 }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            scene.onSelectLandmark = { bookID in selected = WorldData.landmark(bookID: bookID) }
            scene.onSelectConnection = { id in
                withAnimation(.spring(duration: 0.35)) {
                    selectedConnection = WorldData.connections.first { $0.id == id }
                }
            }
            scene.onSelectStoryObject = { id in selectedStory = ChapterLandmarks.entry(id: id).map { InsightSubject.story($0) } }
            scene.onSelectLibrary = { showingLibrary = true }
            scene.onSelectJourney = { id in selectedJourney = JourneyData.journey(id: id) }
            scene.onSelectThrone = { showingThrone = true }
            scene.setAvatar(avatar)
            scene.setLibraryVisible(!journal.isEmpty)
            scene.onViewportChange = { [minimap] rect in minimap.viewport = rect }
            scene.apply(progress)
            scene.setOnScreen(true)
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-openStory"), i + 1 < args.count { selectedStory = ChapterLandmarks.entry(id: args[i + 1]).map { InsightSubject.story($0) } }
            if args.contains("-openStats") { showingStats = true }
            if let i = args.firstIndex(of: "-openJourney"), i + 1 < args.count { selectedJourney = JourneyData.journey(id: args[i + 1]) }
            if args.contains("-openCrowns") { showingCrowns = true }
            if args.contains("-openThrone") { showingThrone = true }
            if args.contains("-openShare") {
                Task { try? await Task.sleep(for: .seconds(4)); shareWorld() }
            }
            #endif
        }
        .onDisappear { scene.setOnScreen(false) }
        .onChange(of: progress) { _, new in scene.apply(new) }
        .onChange(of: journal.isEmpty) { _, empty in scene.setLibraryVisible(!empty) }
        .onChange(of: avatar) { _, new in scene.setAvatar(new) }
        .sheet(item: $selectedJourney) { JourneyCard(journey: $0) }
        .sheet(isPresented: $showingCrowns) { CrownsView() }
        .sheet(isPresented: $showingThrone) { ThroneRoomView() }
        .sheet(item: $shareImage) { SharePreviewSheet(image: $0.image) }
        .sheet(isPresented: $showingLibrary) { LibraryShelfView() }
        .onChange(of: selected) { _, new in scene.setOnScreen(new == nil && selectedStory == nil) }
        .onChange(of: selectedStory) { _, new in scene.setOnScreen(new == nil && selected == nil) }
        .sheet(isPresented: $showingStats) { StatsView() }
        .sheet(item: $selectedStory) { subject in
            ObjectInsightCard(subject: subject).presentationDetents([.medium, .large])
        }
        .sheet(item: $selected) { landmark in
            NavigationStack {
                PlaceDetailView(landmark: landmark)
                    .readingDestinations()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selected = nil }
                                .tint(Color.primaryBrown)
                        }
                    }
            }
        }
    }

    private func shareWorld() {
        let card = ShareCardView(title: "My Promised Land",
                                 subtitle: "\(progress.startedCount) of \(WorldData.landmarks.count) places begun",
                                 artwork: scene.snapshot(), avatar: avatar,
                                 streak: progress.streak, chaptersThisYear: progress.chaptersReadThisYear)
        if let image = card.render() { shareImage = ShareImage(image: image) }
    }

    private var debugOptions: SpriteView.DebugOptions {
        #if DEBUG
        [.showsFPS, .showsNodeCount, .showsDrawCount]
        #else
        []
        #endif
    }
}

/// Title, landmark count, streak and settings — floats over the map.
struct WorldHeader: View {
    let progress: GameProgress
    var onClose: (() -> Void)? = nil
    var openCrowns: (() -> Void)? = nil
    var openStats: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Promised Land")
                    .font(.serifTitle(.title))
                    .foregroundStyle(Color.bodyText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("\(progress.completedCount) of \(WorldData.landmarks.count) built · \(progress.startedCount) begun")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 4)
            StreakPill(days: progress.streak)
            // Crowns show up once the first is earned (progressive disclosure).
            if let openCrowns, progress.totalCrownsEarned > 0 || progress.cycle > 0 {
                Button(action: openCrowns) {
                    Image(systemName: "crown.fill")
                        .font(.headline)
                        .foregroundStyle(Color.wheat)
                        .frame(width: 44, height: 44)
                        .background(Color.card, in: Circle())
                }
                .accessibilityLabel("Crowns")
            }
            Button(action: openStats) {
                Image(systemName: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(Color.primaryBrown)
                    .frame(width: 44, height: 44)
                    .background(Color.card, in: Circle())
            }
            .accessibilityLabel("Reading history")
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Color.primaryBrown)
                        .frame(width: 44, height: 44)
                        .background(Color.card, in: Circle())
                }
                .accessibilityLabel("Close map")
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    WorldView(scene: WorldScene())
        .modelContainer(PreviewData.container)
}
