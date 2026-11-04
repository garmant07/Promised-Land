import SwiftUI
import SwiftData

struct WorldView: View {
    @ProgressQuery private var progress: GameProgress
    @State private var showingSettings = false
    @State private var cardCollapsed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(WorldData.regions) { region in
                        Text(region.name)
                            .font(.serifTitle(.title3))
                            .foregroundStyle(Color.bodyText)
                            .padding(.top, 8)
                        ForEach(WorldData.landmarks.filter { $0.regionID == region.id }) { landmark in
                            NavigationLink(value: landmark) {
                                LandmarkRow(landmark: landmark, progress: progress)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 200)
            }
            .safeAreaInset(edge: .top) {
                WorldHeader(progress: progress) { showingSettings = true }
                    .padding(.horizontal, 16)
                    .background(Color.cream)
            }
            .overlay(alignment: .bottom) {
                if let next = NextUnlock.suggest(from: progress) {
                    NextUnlockCard(next: next, collapsed: $cardCollapsed)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .themedScreen()
            .navigationTitle("World")
            .hiddenNavigationBar()
            .readingDestinations()
        }
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
