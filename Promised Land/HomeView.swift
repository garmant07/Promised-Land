import SwiftUI
import SwiftData

/// The opening page: plain cream, and your character standing far off on a patch of grass.
/// Tap the character to go into reading.
struct HomeView: View {
    private let avatarStorage = AvatarStorage()
    @AppStorage(StorageKeys.hasOpenedReading) private var hasOpenedReading = false

    @State private var showingReading = false
    @State private var showingWorld = false
    @State private var showingCustomise = false
    @State private var showingSettings = false
    @State private var hop = false
    @State private var sway = false
    /// Kept alive between visits so the map doesn't rebuild each time.
    @State private var worldScene = WorldScene()
    @Namespace private var zoom

    var body: some View {
        let avatar = avatarStorage.avatar
        ZStack {
            Color.cream.ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer()
                Button(action: openReading) {
                    ZStack {
                        GrassPlot()
                            .frame(width: 132, height: 78)
                            .offset(y: 18)
                        AvatarFigure(avatar: avatar)
                            .frame(width: 18, height: 33)
                            .rotationEffect(.degrees(sway ? 1.5 : -1.5), anchor: .bottom)
                            .offset(y: hop ? -10 : 0)
                    }
                    .frame(width: 160, height: 120)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: "reading", in: zoom)
                .accessibilityLabel(avatar.name.isEmpty ? "Your character" : avatar.name)
                .accessibilityHint("Opens reading")

                VStack(spacing: 4) {
                    if !avatar.name.isEmpty {
                        Text(avatar.name)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText.opacity(0.8))
                    }
                    if !hasOpenedReading {
                        Text("Tap to read")
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText.opacity(0.55))
                            .transition(.opacity)
                    }
                }
                .frame(minHeight: 40, alignment: .top)
                Spacer()
                Spacer()
            }
        }
        .overlay(alignment: .topTrailing) { menu }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { sway = true }
        }
        .fullScreenCover(isPresented: $showingReading) {
            LibraryView { showingReading = false }
                .navigationTransition(.zoom(sourceID: "reading", in: zoom))
        }
        .fullScreenCover(isPresented: $showingWorld) {
            WorldView(scene: worldScene) { showingWorld = false }
        }
        .sheet(isPresented: $showingCustomise) { AvatarCustomizeView() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    /// One quiet button keeps the page bare.
    private var menu: some View {
        Menu {
            Button { showingCustomise = true } label: { Label("Customise character", systemImage: "person.crop.circle") }
            Button { showingWorld = true } label: { Label("World map", systemImage: "map") }
            Button { showingSettings = true } label: { Label("Settings", systemImage: "gearshape") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .foregroundStyle(Color.secondaryText.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(Color.card.opacity(0.7), in: Circle())
        }
        .padding(.trailing, 16)
        .padding(.top, 8)
        .accessibilityLabel("More")
    }

    private func openReading() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { hop = true }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { hop = false }
            showingReading = true
            withAnimation { hasOpenedReading = true }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
