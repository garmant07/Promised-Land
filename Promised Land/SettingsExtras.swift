import SwiftUI
import SwiftData

/// Settings: who's reading, and the "reading unlocks apps" idea (a stored preference only;
/// no app limits are applied and FamilyControls isn't used).
struct SettingsPreferencesSection: View {
    @AppStorage(StorageKeys.ageGroup) private var ageGroup = ""
    @AppStorage(StorageKeys.readingUnlocksApps) private var readingUnlocksApps = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You").font(.serifTitle(.title3)).foregroundStyle(Color.bodyText)
            Picker("Age group", selection: $ageGroup) {
                Text("Not set").tag("")
                ForEach(AgeGroup.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            .pickerStyle(.menu)
            .tint(Color.primaryBrown)
            .frame(minHeight: 44)
            Toggle("Reading unlocks apps", isOn: $readingUnlocksApps)
                .tint(Color.olive)
                .frame(minHeight: 44)
            Text("Coming later: read a chapter to unlock chosen apps. For now this is only a preference; nothing is limited.")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
        }
        .cardStyle()
    }
}

#if DEBUG
/// DEBUG-only tools for testing the island and journeys.
struct DebugToolsSection: View {
    @Environment(\.modelContext) private var context
    @ProgressQuery private var progress: GameProgress
    @State private var confirmingWipe = false
    @State private var message: String?
    @AppStorage("debug.fpsOverlay") private var showsFPS = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Developer").font(.serifTitle(.title3)).foregroundStyle(Color.bodyText)
            Toggle("FPS overlay on the island", isOn: $showsFPS).tint(Color.olive).frame(minHeight: 44)
            Button("Rebuild world") { rebuildWorld() }.buttonStyle(SoftButtonStyle())
            Button("Add 10 random reads") { addRandomReads() }.buttonStyle(SoftButtonStyle())
            Button("Complete a journey") { completeJourney() }.buttonStyle(SoftButtonStyle())
            Button("Reset all data", role: .destructive) { confirmingWipe = true }.buttonStyle(SoftButtonStyle())
            if let message { Text(message).font(.footnote).foregroundStyle(Color.secondaryText) }
        }
        .cardStyle()
        .confirmationDialog("Reset all data?", isPresented: $confirmingWipe, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) { wipe() }
        } message: {
            Text("DEBUG only: every read, quiz, verse, journal entry, placement and setting is erased.")
        }
    }

    /// Forgets where things were placed, so the island lays itself out again from your reading.
    private func rebuildWorld() {
        try? context.delete(model: PlacedItem.self)
        try? context.save()
        for key in ["unlocks.seen", StorageKeys.gardenSeenChapters, StorageKeys.islandProgressSeen] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        message = "The island will lay itself out again."
    }

    private func addRandomReads() {
        for _ in 0..<10 {
            guard let book = BibleCatalog.books.randomElement() else { continue }
            context.recordRead(book.id, Int.random(in: 1...book.chapterCount))
        }
        message = "Added 10 random reads."
    }

    private func completeJourney() {
        guard let journey = CharacterJourneys.all.first(where: { !progress.journeyProgress($0).isComplete }) else {
            message = "Every journey is already complete."
            return
        }
        for chapter in journey.requiredChapters where !progress.isRead(chapter.book, chapter: chapter.chapter) {
            context.recordRead(chapter.book, chapter.chapter)
        }
        message = "Completed \(journey.title)."
    }

    private func wipe() {
        context.resetAllProgress()
        try? context.delete(model: JournalEntry.self)
        try? context.delete(model: PlacedItem.self)
        try? context.save()
        if let domain = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: domain) }
        message = "Everything was erased."
    }
}
#endif

#Preview {
    VStack {
        SettingsPreferencesSection()
        #if DEBUG
        DebugToolsSection()
        #endif
    }
    .padding()
    .modelContainer(PreviewData.container)
}
