import SwiftUI
import SwiftData

// MARK: - Journeys

/// Your journeys and their progress, with the world map one tap away.
struct JourneysSheet: View {
    var openWorldMap: () -> Void

    var body: some View {
        CharacterJourneysView(onOpenWorld: openWorldMap)
    }
}

/// You: your character, your reading, your crowns, and Settings (the gear).
struct ProfileView: View {
    /// Opens edit mode on the island (closing this sheet).
    var onEditIsland: (() -> Void)? = nil
    /// Your island, for the share image.
    var island: Island = .empty
    @State private var sharing: ShareImage?
    @CurrentAvatar private var avatar: Avatar
    @ProgressQuery private var progress: GameProgress
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false
    @State private var editingCharacter = false
    @State private var showingStats = false
    @State private var showingCrowns = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        ZStack {
                            SandPlot().frame(width: 170, height: 100).offset(y: 26)
                            AvatarFigure(avatar: avatar).frame(width: 52, height: 94)
                        }
                        Text(avatar.name.isEmpty ? "Your character" : avatar.name)
                            .font(.serifTitle(.title2))
                            .foregroundStyle(Color.bodyText)
                        Button("Edit your character") { editingCharacter = true }
                            .buttonStyle(SoftButtonStyle())
                    }
                    .cardStyle()

                    HStack(spacing: 12) {
                        tile("\(progress.streak)", progress.streak == 1 ? "day streak" : "day streak")
                        tile("\(Int((progress.overallFraction * 100).rounded(.down)))%", "of the Bible")
                    }
                    HStack(spacing: 12) {
                        tile("\(progress.chaptersReadThisYear)", "chapters this year")
                        tile("\(progress.startedCount)", progress.startedCount == 1 ? "place begun" : "places begun")
                    }

                    if let onEditIsland {
                        Button { onEditIsland() } label: {
                            row("Edit island", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.plain)
                    }
                    Button { showingStats = true } label: {
                        row("Reading history", systemImage: "chart.bar.fill")
                    }
                    .buttonStyle(.plain)
                    if progress.totalCrownsEarned > 0 || progress.cycle > 0 {
                        Button { showingCrowns = true } label: {
                            row("Crowns · \(progress.totalCrownsAvailable)", systemImage: "crown.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
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
            .sheet(isPresented: $showingCrowns) { CrownsView() }
        }
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .serif).weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.bodyText)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
        }
        .cardStyle()
    }

    private func row(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Color.bodyText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText.opacity(0.6))
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

#Preview("Journeys") {
    JourneysSheet {}.modelContainer(PreviewData.container)
}
