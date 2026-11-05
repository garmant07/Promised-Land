#if DEBUG
import SwiftUI
import SwiftData

// TEMPORARY (DEBUG only): see NOTES.md, "Remove before release". Delete this folder, and the
// "Preview full Bible" button in SettingsExtras.swift, to remove it.

/// What a fully read Bible looks like, without touching your progress: every chapter of all 66
/// books, read in a separate in-memory store, built into a complete island with villagers,
/// produce, roads and ambient life. Richness, a replay of the build, jumping to a book, the FPS
/// overlay and edit mode are all here; nothing is saved, and Exit returns to your own island.
struct FullBiblePreviewView: View {
    var onExit: () -> Void

    @State private var container: ModelContainer?
    @State private var reads: [(book: String, chapter: Int, date: Date)] = []
    @State private var richness: Double = 1
    @State private var shownBooks = 66
    @State private var replayToken = 0
    @State private var speed: Double = 4
    @State private var showsFPS = true
    @State private var selected: Int?
    @State private var panelOpen = true
    // Edit mode (kept only while the preview is open).
    @State private var editing = false
    @State private var draft: [String: IslandPlacement] = [:]
    @State private var kept: [String: IslandPlacement] = [:]
    @State private var editSelected: String?
    @State private var dragBase: IslandPlacement?

    private var replaying: Bool { shownBooks < 66 }

    private var island: Island {
        let ids = Set(BibleCatalog.books.prefix(shownBooks).map(\.id))
        return Island.build(chapters: reads.filter { ids.contains($0.book) }, quizzes: [], verses: [],
                            features: shownBooks == 66 ? [.library, .throne] : [.library],
                            placements: editing ? draft : kept, richnessOverride: Int(richness))
    }

    var body: some View {
        let island = island
        ZStack {
            Earthy.sea.ignoresSafeArea()
            if reads.isEmpty {
                ProgressView("Reading all 66 books…")
            } else {
                PlatformScene(avatar: Avatar(), island: island, insets: EdgeInsets(top: 110, leading: 8, bottom: panelOpen ? 300 : 90, trailing: 8),
                              selected: $selected, showsControls: true,
                              editing: editing ? IslandEditing(selected: editSelected, onDrag: drag, onSelect: { editSelected = $0 }) : nil,
                              life: IslandLife.make(island: island, baskets: Dictionary(uniqueKeysWithValues: island.completed.keys.map { ($0, 2) })),
                              showsFPS: showsFPS) { selected = $0 }
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay(alignment: .top) { banner }
        .overlay(alignment: .bottom) { panel(island) }
        .task { load() }
    }

    // MARK: Pieces

    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.fill")
            Text("PREVIEW — not your real progress")
                .font(.footnote.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Button("Exit") { replayToken += 1; onExit() }
                .font(.subheadline.weight(.bold))
                .frame(minHeight: 44)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.terracotta, in: Capsule())
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func panel(_ island: Island) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(editing ? "Edit mode (not saved)" : replaying ? "Building… \(shownBooks) of 66 books" : "Full Bible: 66 Places")
                    .font(.headline).foregroundStyle(Color.bodyText)
                Spacer()
                Button { withAnimation { panelOpen.toggle() } } label: {
                    Image(systemName: panelOpen ? "chevron.down" : "chevron.up").frame(width: 44, height: 44)
                }
                .accessibilityLabel(panelOpen ? "Hide controls" : "Show controls")
            }
            if panelOpen {
                if editing {
                    HStack {
                        Button("Turn") { turn() }.buttonStyle(SoftButtonStyle()).disabled(editSelected == nil)
                        Button("Done") { kept = draft; editing = false }.buttonStyle(PrimaryButtonStyle()).disabled(!island.conflicts.isEmpty)
                    }
                } else {
                    HStack {
                        Text("Richness \(Int(richness))").font(.subheadline.monospacedDigit()).frame(width: 96, alignment: .leading)
                        Slider(value: $richness, in: 1...5, step: 1).tint(Color.olive)
                    }
                    HStack(spacing: 8) {
                        Button(replaying ? "Stop" : "Replay the build") { replaying ? stopReplay() : replay() }
                            .buttonStyle(SoftButtonStyle())
                        Picker("Speed", selection: $speed) {
                            Text("1×").tag(1.0); Text("4×").tag(4.0); Text("12×").tag(12.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(BibleCatalog.books) { book in
                                Button(book.name) { jump(to: book.id, in: island) }
                            }
                        } label: { Label("Jump to book", systemImage: "scope").frame(minHeight: 44) }
                        Spacer()
                        Toggle("FPS", isOn: $showsFPS).fixedSize()
                        Button("Edit") { draft = island.placements; editing = true }
                            .buttonStyle(SoftButtonStyle())
                            .fixedSize()
                    }
                }
            }
        }
        .tint(Color.primaryBrown)
        .padding(14)
        .background(Color.cream.opacity(0.97), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: Actions

    private func load() {
        guard reads.isEmpty else { return }
        do {
            let container = try FullBiblePreviewData.makeContainer()
            self.container = container
            let stored = try container.mainContext.fetch(FetchDescriptor<ChapterRead>(sortBy: [SortDescriptor(\.date)]))
            reads = stored.map { ($0.bookID, $0.chapterNumber, $0.date) }
        } catch {
            reads = FullBiblePreviewData.reads
        }
    }

    /// Fast-forwards the island growing book by book from the starting square.
    private func replay() {
        replayToken += 1
        let token = replayToken
        shownBooks = 0
        Task {
            while replayToken == token, shownBooks < 66 {
                try? await Task.sleep(for: .seconds(1 / speed))
                guard replayToken == token else { return }
                shownBooks += 1
            }
        }
    }

    private func stopReplay() {
        replayToken += 1
        shownBooks = 66
    }

    private func jump(to bookID: String, in island: Island) {
        selected = nil
        Task {
            try? await Task.sleep(for: .milliseconds(30))
            selected = island.placeIndex(bookID)
        }
    }

    private func drag(_ key: String, _ dx: Int, _ dy: Int, ended: Bool) {
        guard !key.hasPrefix("extra:") else { return }
        if dragBase == nil { dragBase = draft[key] }
        guard let base = dragBase else { return }
        editSelected = key
        var p = base
        p.x += dx; p.y += dy; p.moved = true
        draft[key] = p
        guard ended else { return }
        if island.conflicts.contains(key) { draft[key] = base }
        dragBase = nil
    }

    private func turn() {
        guard let key = editSelected, var p = draft[key] else { return }
        p.rotation = (p.rotation + 1) % 4
        draft[key] = p
    }
}

#Preview {
    FullBiblePreviewView {}
}
#endif
