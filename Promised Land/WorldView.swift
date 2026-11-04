import SwiftUI
import SwiftData
import SpriteKit

struct WorldView: View {
    @ProgressQuery private var progress: GameProgress
    @State private var scene = WorldScene()
    @State private var showingSettings = false
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
                WorldHeader(progress: progress) { showingSettings = true }
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
                HStack {
                    Spacer()
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
            scene.onViewportChange = { [minimap] rect in minimap.viewport = rect }
            scene.apply(progress)
            scene.setOnScreen(true)
        }
        .onDisappear { scene.setOnScreen(false) }
        .onChange(of: progress) { _, new in scene.apply(new) }
        .onChange(of: selected) { _, new in scene.setOnScreen(new == nil) }
        .sheet(isPresented: $showingSettings) { SettingsView() }
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
    var openSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Promised Land")
                    .font(.serifTitle(.title))
                    .foregroundStyle(Color.bodyText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(progress.completedCount) of \(WorldData.landmarks.count) built · \(progress.startedCount) begun")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 4)
            StreakPill(days: progress.streak)
            Button(action: openSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(Color.primaryBrown)
                    .frame(width: 44, height: 44)
                    .background(Color.card, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    WorldView()
        .modelContainer(PreviewData.container)
}
