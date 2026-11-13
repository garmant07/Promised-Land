import SwiftUI
import SwiftData

private extension JournalNotebookColor {
    static let names = ["Lavender", "Blue", "Wheat", "Clay", "Sage", "Rose", "Teal", "Walnut"]

    static func color(at index: Int) -> Color {
        let colors: [Color] = [.lavender, Color(hex: "#93AECF"), .wheat, .terracotta, .olive,
                               Color(hex: "#C98B8B"), .water, .primaryBrown]
        return colors[index % colors.count]
    }

    static func name(at index: Int) -> String { names[index % names.count] }
}

// MARK: - Reflection card

/// Optional, skippable questions after reading a chapter. Answers become journal entries.
struct ReflectionCard: View {
    let book: Book
    let chapter: Int
    /// Called after something is saved (the reading check counts a reflection).
    var onSaved: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [String] = ["", ""]
    @State private var saveFailed = false
    // If a later answer fails, retry only the answers that have not already saved.
    @State private var savedAnswers: Set<Int> = []
    @State private var selectedNotebook: JournalNotebook?
    @State private var picker: JournalPickerRoute?
    @State private var newJournal: JournalSheetRoute?
    @FocusState private var focused: Int?

    var body: some View {
        let (prompts, specific) = ReflectionData.prompts(bookID: book.id, chapter: chapter)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        Text("Reflect on \(book.name) \(chapter)")
                            .font(.serifTitle(.title2))
                            .foregroundStyle(Color.bodyText)
                        if let specific { DraftBadge(item: specific) }
                    }
                    Text("Take a moment, or skip. Anything you write is saved privately in your journal.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)

                    ForEach(prompts.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(prompts[i])
                                .font(.system(.headline, design: .serif))
                                .foregroundStyle(Color.bodyText)
                                .fixedSize(horizontal: false, vertical: true)
                            TextEditor(text: $answers[i])
                                .focused($focused, equals: i)
                                .disabled(savedAnswers.contains(i))
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 96)
                                .padding(8)
                                .background(Color.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .accessibilityLabel(prompts[i])
                        }
                        .cardStyle()
                    }

                    if saveFailed {
                        Text("Couldn't save your note. Please try again.")
                            .foregroundStyle(Color.secondaryText)
                    }
                    JournalDestinationRow(name: selectedNotebook?.name ?? "Choose a journal") {
                        picker = JournalPickerRoute()
                    }
                    Button("Save to journal") { save(prompts) }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(answers.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                    Button("Skip") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(16)
            }
            .themedScreen()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedNotebook = try? JournalStore.preferredNotebook(in: context, bookID: book.id)
            }
            .sheet(item: $picker) { _ in
                JournalDestinationPicker(bookID: book.id, onSelected: { selectedNotebook = $0 },
                                         onNewJournal: { shelf in newJournal = JournalSheetRoute(kind: .newJournal(shelf?.id)) })
            }
            .sheet(item: $newJournal) { route in
                if case .newJournal(let shelfID) = route.kind {
                    NewJournalSheet(initialShelf: (try? context.fetch(FetchDescriptor<JournalShelf>())).flatMap { $0.first { $0.id == shelfID } }) { name, shelf, colorIndex in
                        let notebook = JournalNotebook(name: name, shelf: shelf, colorIndex: colorIndex)
                        context.insert(notebook)
                        selectedNotebook = notebook
                        try? context.save()
                    }
                }
            }
            .tint(Color.primaryBrown)
        }
    }

    private func save(_ prompts: [String]) {
        saveFailed = false
        do {
            let notebook = try selectedNotebook ?? JournalStore.preferredNotebook(in: context, bookID: book.id)
            for (index, pair) in zip(prompts, answers).enumerated() {
                guard !savedAnswers.contains(index) else { continue }
                let text = pair.1.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                try JournalStore.save(in: context, notebook: notebook, text: text,
                                      bookID: book.id, chapter: chapter, prompt: pair.0)
                savedAnswers.insert(index)
            }
            onSaved?()
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

// MARK: - Library (journals on shelves)

/// A journal notebook represented as a spine on a journal shelf.
struct JournalVolume: Identifiable, Hashable {
    let id: String
    let title: String
    let count: Int
    let notebookID: UUID?
    let shelfID: UUID?
    let colorIndex: Int?
    let created: Date?

    init(id: String, title: String, count: Int, notebookID: UUID? = nil, shelfID: UUID? = nil,
         colorIndex: Int? = nil, created: Date? = nil) {
        self.id = id
        self.title = title
        self.count = count
        self.notebookID = notebookID
        self.shelfID = shelfID
        self.colorIndex = colorIndex
        self.created = created
    }

    var bookID: String? { id == "free" ? nil : id }
}

struct LibraryShelfView: View {
    @Query(sort: \JournalShelf.created) private var shelves: [JournalShelf]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var sheet: JournalSheetRoute?

    private var volumesByShelf: [(JournalShelf, [JournalVolume])] {
        shelves.filter { $0.modelContext != nil }.map { shelf in
            let volumes = shelf.notebooks
                .filter { $0.modelContext != nil }
                .sorted { $0.created < $1.created }
                .map { JournalVolume(id: $0.id.uuidString, title: $0.name, count: $0.entries.count,
                                     notebookID: $0.id, shelfID: shelf.id, colorIndex: $0.colorIndex,
                                     created: $0.created) }
            return (shelf, volumes)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Your journals")
                        .font(.serifTitle(.title2))
                        .foregroundStyle(Color.bodyText)
                    Text("Kept on this device. Choose a journal to open only the entries filed in it.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                    ForEach(volumesByShelf, id: \.0.id) { shelf, volumes in
                        LibraryShelfLabel(title: shelf.label, systemImage: "books.vertical")
                            .onLongPressGesture { sheet = JournalSheetRoute(kind: .renameShelf(shelf.id)) }
                            .contextMenu {
                                Button("Rename") { sheet = JournalSheetRoute(kind: .renameShelf(shelf.id)) }
                                Button("Delete", role: .destructive) { sheet = JournalSheetRoute(kind: .deleteShelf(shelf.id)) }
                            }
                        shelfSpines(volumes, shelf: shelf)
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: JournalVolume.self) { JournalBookView(volume: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = JournalSheetRoute(kind: .newShelf) } label: { Label("Shelf", systemImage: "plus") }
                        .tint(Color.primaryBrown)
                }
            }
            .sheet(item: $sheet) { route in
                switch route.kind {
                case .newShelf:
                    NewShelfSheet { label in
                        context.insert(JournalShelf(label: label)); try? context.save()
                    }
                case .renameShelf(let id):
                    if let shelf = shelves.first(where: { $0.id == id }) {
                        RenameShelfSheet(title: shelf.label) { label in shelf.label = label; try? context.save() }
                    }
                case .newJournal(let shelfID):
                    NewJournalSheet(initialShelf: shelves.first { $0.id == shelfID }) { name, shelf, colorIndex in
                        context.insert(JournalNotebook(name: name, shelf: shelf, colorIndex: colorIndex)); try? context.save()
                    }
                case .renameJournal(let id):
                    if let journal = shelves.flatMap(\.notebooks).first(where: { $0.id == id }) {
                        RenameJournalSheet(title: journal.name) { name in journal.name = name; try? context.save() }
                    }
                case .colorJournal(let id):
                    if let journal = shelves.flatMap(\.notebooks).first(where: { $0.id == id }) {
                        JournalColorSheet(notebook: journal)
                    }
                case .moveJournal(let id):
                    if let journal = shelves.flatMap(\.notebooks).first(where: { $0.id == id }) {
                        MoveJournalSheet(notebook: journal, shelves: shelves) { shelf in journal.shelf = shelf; try? context.save() }
                    }
                case .deleteShelf(let id):
                    if let shelf = shelves.first(where: { $0.id == id }) {
                        DeleteShelfSheet(shelf: shelf, otherShelves: shelves.filter { $0.id != id },
                                         onDeleteEmpty: { delete(shelf) },
                                         onMoveAndDelete: { target in
                            _ = withAnimation { try? JournalStore.moveJournalsAndDeleteShelf(in: context, shelf: shelf, to: target) }
                        })
                    }
                }
            }
            .tint(Color.primaryBrown)
        }
    }

    private func shelfSpines(_ items: [JournalVolume], shelf: JournalShelf) -> some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(items) { volume in
                        NavigationLink(value: volume) { spine(volume) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Rename") { if let id = volume.notebookID { sheet = JournalSheetRoute(kind: .renameJournal(id)) } }
                                Button("Colour") { if let id = volume.notebookID { sheet = JournalSheetRoute(kind: .colorJournal(id)) } }
                                Button("Move to shelf…") { if let id = volume.notebookID { sheet = JournalSheetRoute(kind: .moveJournal(id)) } }
                            }
                    }
                    JournalShelfAddSpine { sheet = JournalSheetRoute(kind: .newJournal(shelf.id)) }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 12)
            LibraryPlank()
        }
    }

    private func spine(_ volume: JournalVolume) -> some View {
        let id = volume.notebookID ?? UUID(uuidString: volume.id) ?? UUID()
        let index = volume.colorIndex ?? JournalNotebookColor.automaticIndex(for: id)
        let color = JournalNotebookColor.color(at: index)
        let height: CGFloat = 128
        return VStack(spacing: 6) {
            Text(volume.title)
                .font(.system(.caption, design: .serif).weight(.semibold))
                .foregroundStyle(Color.bodyText)
                .rotationEffect(.degrees(-90))
                .fixedSize()
                .frame(width: 20, height: height - 40)
            Text("\(volume.count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.onPrimary)
                .frame(width: 24, height: 24)
                .background(Color.primaryBrown.opacity(0.75), in: Circle())
        }
        .frame(width: 52, height: height)
        .background(color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(volume.title), \(volume.count) \(volume.count == 1 ? "entry" : "entries")")
    }

    private func delete(_ shelf: JournalShelf) {
        _ = withAnimation { try? JournalStore.deleteEmptyShelf(in: context, shelf: shelf) }
    }
}

/// One journal notebook: page through only the entries filed in it.
struct JournalBookView: View {
    let volume: JournalVolume
    /// Opens at this page, if given.
    var startAt: UUID? = nil

    @Query(sort: \JournalEntry.created) private var all: [JournalEntry]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var editing: JournalEntry?
    @State private var addingPage: JournalPageRoute?
    @State private var continuing: JournalContinuationRoute?
    @State private var confirmingDelete = false

    private var entries: [JournalEntry] {
        let filtered: [JournalEntry]
        if let notebookID = volume.notebookID {
            filtered = all.filter { $0.notebook?.id == notebookID }
        } else {
            filtered = all.filter { $0.bookID == volume.bookID }
        }
        return JournalStore.sortedPages(filtered)
    }

    private var startDate: Date {
        JournalPresentation.startDate(journalCreated: volume.created ?? .now,
                                      oldestPageDate: entries.map(\.created).min())
    }

    var body: some View {
        VStack(spacing: 0) {
            JournalBookHeader(title: volume.title, startDate: startDate, pageCount: entries.count)
            Divider().overlay(Color.secondaryText.opacity(0.35))
                .padding(.horizontal, 22)
            if entries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("No pages yet")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.bodyText)
                    Text("Started \(startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                    Text("Write your first page.")
                        .foregroundStyle(Color.secondaryText)
                    Button("Add a page") { addingPage = JournalPageRoute() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Spacer()
            } else {
                TabView(selection: $page) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        JournalPageView(entry: entry) { continuing = JournalContinuationRoute(source: entry) }.tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedScreen()
        .navigationTitle(volume.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Label("Journals", systemImage: "chevron.left") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingPage = JournalPageRoute() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add page")
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button { editing = current } label: { Label("Edit", systemImage: "pencil") }
                    .disabled(current == nil)
                Spacer()
                Text("Page \(entries.isEmpty ? 0 : min(page, entries.count - 1) + 1) of \(entries.count)")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
                    .disabled(current == nil)
            }
        }
        .tint(Color.primaryBrown)
        .onAppear {
            if let startAt, let index = entries.firstIndex(where: { $0.id == startAt }) { page = index }
        }
        .sheet(item: $editing) { JournalEditor(entry: $0, bookID: volume.bookID) }
        .sheet(item: $addingPage) { _ in JournalEditor(entry: nil, bookID: volume.bookID, notebookID: volume.notebookID) }
        .sheet(item: $continuing) { route in
            ContinuedJournalEditor(source: route.source, journalName: volume.title,
                                   pageNumber: min(page, max(0, entries.count - 1)) + 1) { saved in
                let select = { page = entries.firstIndex(where: { $0.id == saved.id }) ?? page }
                if reduceMotion {
                    select()
                } else {
                    withAnimation { select() }
                }
            }
        }
        .confirmationDialog("Delete this page?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let current, current.modelContext != nil else { return }
                withAnimation {
                    context.delete(current)
                    try? context.save()
                    page = max(0, page - 1)
                }
            }
        }
    }

    private var current: JournalEntry? { entries.indices.contains(page) ? entries[page] : nil }
}

/// A single page, like a sheet of paper.
struct JournalPageView: View {
    let entry: JournalEntry
    let continuePage: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(JournalPresentation.pageDetails(for: entry))
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                if let prompt = entry.prompt {
                    Text(prompt)
                        .font(.system(.subheadline, design: .serif).italic())
                        .foregroundStyle(Color.secondaryText)
                }
                Text(entry.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.bodyText)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: continuePage) {
                    Label("Continue on a new page", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primaryBrown)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primaryBrown, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream)
    }
}

enum JournalPresentation {
    static func startDate(journalCreated: Date, oldestPageDate: Date?) -> Date {
        min(journalCreated, oldestPageDate ?? journalCreated)
    }

    @MainActor static func pageDetails(for entry: JournalEntry) -> String {
        let date = entry.created.formatted(date: .abbreviated, time: .omitted)
        let reference = entry.reference
        let base = reference.map { "\($0) · \(date)" } ?? date
        return entry.isContinuation ? "\(base) · continued" : base
    }
}

private struct JournalBookHeader: View {
    let title: String
    let startDate: Date
    let pageCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.serifTitle(.title2))
                .foregroundStyle(Color.bodyText)
            Text("Started \(startDate.formatted(date: .abbreviated, time: .omitted)) · \(pageCount) \(pageCount == 1 ? "page" : "pages")")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

private struct JournalPageRoute: Identifiable {
    let id = UUID()
}

private struct JournalContinuationRoute: Identifiable {
    let id = UUID()
    let source: JournalEntry
}

/// Write or edit a page. For a book volume, the page can be tied to a chapter.
struct JournalEditor: View {
    let entry: JournalEntry?
    let bookID: String?
    var notebookID: UUID? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var chapter = 0 // 0 = whole book
    @State private var saveFailed = false
    @State private var selectedNotebook: JournalNotebook?
    @State private var picker: JournalPickerRoute?
    @State private var newJournal: JournalSheetRoute?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if let bookID, let book = BibleCatalog.book(id: bookID) {
                    Picker("Chapter", selection: $chapter) {
                        Text("\(book.name) (whole book)")
                            .foregroundStyle(Color.secondaryText)
                            .tag(0)
                        ForEach(Array(book.chapterNumbers), id: \.self) {
                            Text("\(book.name) \($0)")
                                .foregroundStyle(Color.secondaryText)
                                .tag($0)
                        }
                    }
                    .tint(Color.primaryBrown)
                    .frame(minHeight: 44)
                }
                if let prompt = entry?.prompt {
                    Text(prompt)
                        .font(.system(.subheadline, design: .serif).italic())
                        .foregroundStyle(Color.secondaryText)
                }
                if entry == nil && notebookID == nil {
                    JournalDestinationRow(name: selectedNotebook?.name ?? "Choose a journal") {
                        picker = JournalPickerRoute()
                    }
                }
                if saveFailed {
                    Text("Couldn't save your note. Please try again.")
                        .foregroundStyle(Color.secondaryText)
                }
                TextEditor(text: $text)
                    .foregroundStyle(Color.bodyText)
                    .tint(Color.primaryBrown)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel("Journal text")
            }
            .padding(16)
            .themedScreen()
            .navigationTitle(entry == nil ? "New page" : "Edit page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(entry == nil ? "New page" : "Edit page")
                        .foregroundStyle(Color.bodyText)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(Color.primaryBrown) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .tint(Color.primaryBrown)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                text = entry?.text ?? ""
                chapter = entry?.chapter ?? 0
                if entry == nil && notebookID == nil {
                    selectedNotebook = try? JournalStore.preferredNotebook(in: context, bookID: bookID)
                }
            }
            .sheet(item: $picker) { _ in
                JournalDestinationPicker(bookID: bookID, onSelected: { selectedNotebook = $0 },
                                         onNewJournal: { shelf in newJournal = JournalSheetRoute(kind: .newJournal(shelf?.id)) })
            }
            .sheet(item: $newJournal) { route in
                if case .newJournal(let shelfID) = route.kind {
                    NewJournalSheet(initialShelf: (try? context.fetch(FetchDescriptor<JournalShelf>())).flatMap { $0.first { $0.id == shelfID } }) { name, shelf, colorIndex in
                        let notebook = JournalNotebook(name: name, shelf: shelf, colorIndex: colorIndex)
                        context.insert(notebook)
                        selectedNotebook = notebook
                        try? context.save()
                    }
                }
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        saveFailed = false
        do {
            if let entry {
                let previous = (entry.text, entry.chapter, entry.updated)
                entry.text = trimmed
                entry.chapter = chapter == 0 ? nil : chapter
                entry.updated = .now
                do { try context.save() }
                catch {
                    entry.text = previous.0
                    entry.chapter = previous.1
                    entry.updated = previous.2
                    throw error
                }
            } else {
                let notebook = try selectedNotebook ?? (notebookID.flatMap { id in
                    try? context.fetch(FetchDescriptor<JournalNotebook>()).first { $0.id == id }
                }) ?? JournalStore.preferredNotebook(in: context, bookID: bookID)
                try JournalStore.save(in: context, notebook: notebook, text: trimmed,
                                      bookID: bookID, chapter: chapter == 0 ? nil : chapter)
            }
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

/// The deliberately smaller editor used when a page continues an existing page.
private struct ContinuedJournalEditor: View {
    let source: JournalEntry
    let journalName: String
    let pageNumber: Int
    let onSaved: (JournalEntry) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(journalName) · continues page \(pageNumber)")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                Divider().overlay(Color.secondaryText.opacity(0.35))
                if let reference = source.reference {
                    Text("\(reference) · today")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                }
                if saveFailed {
                    Text("Couldn't save your note. Please try again.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                }
                TextEditor(text: $text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.bodyText)
                    .tint(Color.primaryBrown)
                    .scrollContentBackground(.hidden)
                    .background(Color.cream)
                    .accessibilityLabel("Journal text")
            }
            .padding(22)
            .background(Color.cream)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .themedScreen()
            .navigationTitle("New page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New page")
                        .foregroundStyle(Color.bodyText)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.primaryBrown)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .tint(Color.primaryBrown)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { text = "" }
        }
    }

    private func save() {
        saveFailed = false
        do {
            let saved = try JournalStore.continuePage(in: context, from: source, text: text)
            onSaved(saved)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

#Preview("Library") {
    LibraryShelfView()
        .modelContainer(PreviewData.container)
}

import SwiftUI
import SwiftData

struct JournalPickerRoute: Identifiable {
    let id = UUID()
}

struct JournalDestinationRow: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Save to: \(name)")
                    .foregroundStyle(Color.bodyText)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(Color.secondaryText)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct JournalSheetRoute: Identifiable {
    enum Kind {
        case newShelf
        case renameShelf(UUID)
        case newJournal(UUID?)
        case renameJournal(UUID)
        case colorJournal(UUID)
        case moveJournal(UUID)
        case deleteShelf(UUID)
    }

    let id = UUID()
    let kind: Kind
}

struct JournalDestinationPicker: View {
    let bookID: String?
    let onSelected: (JournalNotebook) -> Void
    let onNewJournal: (JournalShelf?) -> Void

    @Query(sort: \JournalShelf.created) private var shelves: [JournalShelf]

    init(bookID: String?, onSelected: @escaping (JournalNotebook) -> Void,
         onNewJournal: @escaping (JournalShelf?) -> Void) {
        self.bookID = bookID
        self.onSelected = onSelected
        self.onNewJournal = onNewJournal
    }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(shelves, id: \.id) { shelf in
                    Section {
                        ForEach(shelf.notebooks.sorted { $0.created < $1.created }, id: \.id) { notebook in
                            Button {
                                onSelected(notebook)
                                dismiss()
                            } label: {
                            Label(notebook.name, systemImage: "book.closed")
                                .foregroundStyle(Color.bodyText)
                            }
                        }
                    } header: {
                        Text(shelf.label)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                Button("New journal…") {
                    dismiss()
                    onNewJournal(shelves.first)
                }
                .foregroundStyle(Color.primaryBrown)
            }
            .scrollContentBackground(.hidden)
            .background(Color.cream)
            .navigationTitle("Save to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Save to")
                        .foregroundStyle(Color.bodyText)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.primaryBrown)
                }
            }
            .themedScreen()
            .tint(Color.primaryBrown)
        }
    }
}

private struct JournalPreviewSpine: View {
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Color.clear.frame(width: 20, height: 88)
            Text("0")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.onPrimary)
                .frame(width: 24, height: 24)
                .background(Color.primaryBrown.opacity(0.75), in: Circle())
        }
        .frame(width: 52, height: 128)
        .background(color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct JournalColorSwatches: View {
    @Binding var selection: Int?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<JournalNotebookColor.paletteCount, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    Circle()
                        .fill(JournalNotebookColor.color(at: index))
                        .frame(width: 36, height: 36)
                        .overlay {
                            if selection == index {
                                Circle()
                                    .stroke(Color.cream, lineWidth: 5)
                                    .padding(-4)
                                Circle()
                                    .stroke(Color.bodyText, lineWidth: 1.5)
                                    .padding(-4)
                            }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(JournalNotebookColor.name(at: index))
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct JournalShelfSelection: View {
    let shelves: [JournalShelf]
    let selectedShelf: JournalShelf?
    let select: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(shelves.enumerated()), id: \.element.id) { index, shelf in
                Button { select(shelf.id) } label: {
                    HStack {
                        Text(shelf.label)
                            .foregroundStyle(Color.bodyText)
                        Spacer()
                        if shelf.id == selectedShelf?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.primaryBrown)
                        }
                    }
                    .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
                if index < shelves.count - 1 {
                    Divider().overlay(Color.secondaryText.opacity(0.25))
                }
            }
        }
        .padding(.horizontal, 14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct NewShelfSheet: View {
    var onCreate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Shelf label", text: $label, prompt: Text("Shelf label").foregroundStyle(Color.secondaryText))
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(Color.bodyText)
                    .listRowBackground(Color.card)
            }
            .scrollContentBackground(.hidden)
            .background(Color.cream)
            .navigationTitle("New shelf")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New shelf")
                        .foregroundStyle(Color.bodyText)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(Color.primaryBrown) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(label.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .tint(Color.primaryBrown)
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .themedScreen()
            .tint(Color.primaryBrown)
        }
    }
}

struct NewJournalSheet: View {
    let initialShelf: JournalShelf?
    var onCreate: (String, JournalShelf, Int?) -> Void

    @Query(sort: \JournalShelf.created) private var shelves: [JournalShelf]
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedShelfID: UUID?
    @State private var selectedColorIndex: Int?

    private var selectedShelf: JournalShelf? {
        shelves.first { $0.id == selectedShelfID } ?? initialShelf ?? shelves.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("New journal")
                        .font(.serifTitle(.title2))
                        .foregroundStyle(Color.bodyText)
                    JournalPreviewSpine(color: JournalNotebookColor.color(at: selectedColorIndex ?? 0))
                        .frame(maxWidth: .infinity)
                    Text("Name")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                    TextField("Name", text: $name, prompt: Text("Name").foregroundStyle(Color.secondaryText))
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(Color.bodyText)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("Colour")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, 4)
                    JournalColorSwatches(selection: $selectedColorIndex)
                    Text("Shelf")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, 4)
                    JournalShelfSelection(shelves: shelves, selectedShelf: selectedShelf) { selectedShelfID = $0 }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .background(Color.cream.ignoresSafeArea())
            .onAppear { selectedShelfID = initialShelf?.id ?? shelves.first?.id }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(Color.primaryBrown) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let shelf = selectedShelf, !trimmed.isEmpty {
                            onCreate(trimmed, shelf, selectedColorIndex)
                            dismiss()
                        }
                    }
                    .tint(Color.primaryBrown)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedShelf == nil)
                }
            }
            .themedScreen()
            .tint(Color.primaryBrown)
        }
    }
}

struct RenameJournalSheet: View {
    let title: String
    let navigationTitle: String
    var onRename: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(title: String, onRename: @escaping (String) -> Void, navigationTitle: String = "Rename journal") {
        self.title = title
        self.navigationTitle = navigationTitle
        self.onRename = onRename
        _name = State(initialValue: title)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name, prompt: Text("Name").foregroundStyle(Color.secondaryText))
                    .foregroundStyle(Color.bodyText)
                    .listRowBackground(Color.card)
            }
                .scrollContentBackground(.hidden)
                .background(Color.cream)
                .navigationTitle(navigationTitle)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(navigationTitle)
                            .foregroundStyle(Color.bodyText)
                    }
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(Color.primaryBrown) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { onRename(trimmed); dismiss() }
                        }
                        .tint(Color.primaryBrown)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .themedScreen()
                .tint(Color.primaryBrown)
        }
    }
}

struct JournalColorSheet: View {
    let notebook: JournalNotebook
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name: String
    @State private var selectedColorIndex: Int?

    init(notebook: JournalNotebook) {
        self.notebook = notebook
        _name = State(initialValue: notebook.name)
        _selectedColorIndex = State(initialValue: notebook.colorIndex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Edit journal")
                        .font(.serifTitle(.title2))
                        .foregroundStyle(Color.bodyText)
                    JournalPreviewSpine(color: JournalNotebookColor.color(at: selectedColorIndex ?? JournalNotebookColor.automaticIndex(for: notebook.id)))
                        .frame(maxWidth: .infinity)
                    Text("Name")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                    TextField("Name", text: $name, prompt: Text("Name").foregroundStyle(Color.secondaryText))
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(Color.bodyText)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("Colour")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, 4)
                    JournalColorSwatches(selection: $selectedColorIndex)
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .background(Color.cream.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit journal")
                        .foregroundStyle(Color.bodyText)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.primaryBrown)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        notebook.name = trimmed
                        notebook.colorIndex = selectedColorIndex
                        try? context.save()
                        dismiss()
                    }
                    .tint(Color.primaryBrown)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .themedScreen()
            .tint(Color.primaryBrown)
        }
    }
}

struct RenameShelfSheet: View {
    let title: String
    var onRename: (String) -> Void
    var body: some View {
        RenameJournalSheet(title: title, onRename: onRename, navigationTitle: "Rename shelf")
    }
}

struct MoveJournalSheet: View {
    let notebook: JournalNotebook
    let shelves: [JournalShelf]
    var onMove: (JournalShelf) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(shelves.filter { $0.id != notebook.shelf?.id }, id: \.id) { shelf in
                Button {
                    onMove(shelf)
                    dismiss()
                } label: {
                    Text(shelf.label).foregroundStyle(Color.bodyText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.cream)
            .navigationTitle("Move journal to…")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Move journal to…")
                        .foregroundStyle(Color.bodyText)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.primaryBrown)
                }
            }
            .themedScreen()
            .tint(Color.primaryBrown)
        }
    }
}

struct DeleteShelfSheet: View {
    let shelf: JournalShelf
    let otherShelves: [JournalShelf]
    var onDeleteEmpty: () -> Void
    var onMoveAndDelete: (JournalShelf) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if otherShelves.isEmpty {
                    Text("You need at least one shelf.")
                        .foregroundStyle(Color.secondaryText)
                } else if shelf.notebooks.isEmpty {
                    Section { Text("Delete “\(shelf.label)”?”").foregroundStyle(Color.bodyText) }
                    Button("Delete shelf", role: .destructive) {
                        onDeleteEmpty()
                        dismiss()
                    }
                } else {
                    Section {
                        ForEach(otherShelves, id: \.id) { target in
                            Button {
                                onMoveAndDelete(target)
                                dismiss()
                            } label: {
                                Text(target.label).foregroundStyle(Color.bodyText)
                            }
                        }
                    } header: {
                        Text("Move \(shelf.notebooks.count) journals to:")
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.cream)
            .navigationTitle("Delete shelf")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Delete shelf")
                        .foregroundStyle(Color.bodyText)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.primaryBrown)
                }
            }
            .themedScreen()
            .tint(Color.primaryBrown)
        }
    }
}

struct JournalShelfAddSpine: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
            }
            .foregroundStyle(Color.primaryBrown)
            .frame(width: 52, height: 128)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .foregroundStyle(Color.primaryBrown.opacity(0.65))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New journal")
    }
}

#Preview("Journal picker") {
    JournalDestinationPicker(bookID: "john", onSelected: { _ in }, onNewJournal: { _ in })
        .modelContainer(PreviewData.container)
}

#Preview("Journal book") {
    NavigationStack {
        JournalBookView(volume: JournalVolume(id: UUID().uuidString, title: "My journals", count: 0))
    }
    .modelContainer(PreviewData.container)
}
