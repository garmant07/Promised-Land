import SwiftUI
import SwiftData
import SpriteKit

struct WorldView: View {
    @ProgressQuery private var progress: GameProgress
    @State private var scene = WorldScene()
    @State private var showingSettings = false
    @State private var cardCollapsed = false
    @State private var selected: Landmark?

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
                Spacer()
                if let next = NextUnlock.suggest(from: progress) {
                    NextUnlockCard(next: next, collapsed: $cardCollapsed) { selected = $0 }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
        }
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
