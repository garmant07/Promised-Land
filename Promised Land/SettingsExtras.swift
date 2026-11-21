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

/// Whether each chapter must be answered before it counts.
struct ReadingStrictnessSection: View {
    @AppStorage(StorageKeys.readingStrictMode) private var strictMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading").font(.serifTitle(.title3)).foregroundStyle(Color.bodyText)
            Toggle("Strict mode", isOn: $strictMode)
                .tint(Color.olive)
                .frame(minHeight: 44)
            Text("When on, you have to answer the questions after each chapter. Skip is hidden.")
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
    @AppStorage("debug.apiOverlay") private var showsAPIUsage = true
    @AppStorage(SceneSystem.previewBookKey) private var previewSceneBook = ""
    @AppStorage(SceneSystem.previewStageKey) private var previewSceneStage = -1
    @State private var previewingBible = false
    @Environment(\.bibleService) private var bible

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Developer").font(.serifTitle(.title3)).foregroundStyle(Color.bodyText)
            Toggle("FPS overlay on the island", isOn: $showsFPS).tint(Color.olive).frame(minHeight: 44)
                .onChange(of: showsFPS) { _, enabled in PerfProbe.setEnabled(enabled) }
            Toggle("API.Bible usage in the reader", isOn: $showsAPIUsage).tint(Color.olive).frame(minHeight: 44)
            APIUsageBadge()
            Button("Export sprite bases") {
                SpriteBaseExporter.export()
                message = "Sprite bases exported to Documents/SpriteBases."
            }
            .buttonStyle(SoftButtonStyle())
            if let api = (bible as? APIBibleService) ?? (bible as? RoutedBibleService)?.api {
                Text(api.isLive ? "Key set · \(api.cache.count) chapters cached" : "No API key: built-in ASV available offline")
                    .font(.footnote).foregroundStyle(Color.secondaryText)
                Button("Clear cached Bible text") { api.cache.removeAll(); message = "Cached chapters cleared." }
                    .buttonStyle(SoftButtonStyle())
            }
            // TEMPORARY: remove with Debug/FullBiblePreview before release (NOTES.md).
            Button("Preview full Bible") { previewingBible = true }.buttonStyle(SoftButtonStyle())
            Picker("Preview scene", selection: $previewSceneBook) {
                Text("Off").tag("")
                ForEach(SceneSystem.bookIDs, id: \.self) { bookID in
                    Text(BibleCatalog.book(id: bookID)?.name ?? bookID).tag(bookID)
                }
            }
            .pickerStyle(.menu)
            if let book = BibleCatalog.book(id: previewSceneBook), SceneSystem.isSceneBook(book.id) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stage \(previewSceneStage < 0 ? 0 : previewSceneStage) of \(book.chapterCount)")
                        .font(.footnote).foregroundStyle(Color.secondaryText)
                    Slider(value: Binding(get: {
                        Double(max(0, min(previewSceneStage, book.chapterCount)))
                    }, set: { previewSceneStage = Int($0.rounded()) }),
                           in: 0...Double(book.chapterCount), step: 1)
                }
            }
            Button("Rebuild world") { rebuildWorld() }.buttonStyle(SoftButtonStyle())
            Button("Add 10 random reads") { addRandomReads() }.buttonStyle(SoftButtonStyle())
            Button("Complete a journey") { completeJourney() }.buttonStyle(SoftButtonStyle())
            Button("Reset all data", role: .destructive) { confirmingWipe = true }.buttonStyle(SoftButtonStyle())
            if let message { Text(message).font(.footnote).foregroundStyle(Color.secondaryText) }
        }
        .cardStyle()
        .onAppear { updateScenePreview() }
        .onChange(of: previewSceneBook) { _, _ in updateScenePreview() }
        .onChange(of: previewSceneStage) { _, _ in updateScenePreview() }
        .fullScreenCover(isPresented: $previewingBible) { FullBiblePreviewView { previewingBible = false } }
        .confirmationDialog("Reset all data?", isPresented: $confirmingWipe, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) { wipe() }
        } message: {
            Text("DEBUG only: every read, quiz, verse, journal entry, placement and setting is erased.")
        }
    }

    private func updateScenePreview() {
        guard !previewSceneBook.isEmpty,
              let layout = SceneSystem.layout(for: previewSceneBook) else {
            SceneSystem.previewBookID = nil
            SceneSystem.previewStage = nil
            return
        }
        previewSceneStage = max(0, min(previewSceneStage, layout.chapters))
        SceneSystem.previewBookID = previewSceneBook
        SceneSystem.previewStage = previewSceneStage
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
