import SwiftUI
import SwiftData

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
                            .foregroundStyle(Color.terracotta)
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
                    NewJournalSheet(initialShelf: (try? context.fetch(FetchDescriptor<JournalShelf>())).flatMap { $0.first { $0.id == shelfID } }) { name, shelf in
                        let notebook = JournalNotebook(name: name, shelf: shelf)
                        context.insert(notebook)
                        selectedNotebook = notebook
                        try? context.save()
                    }
                }
            }
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

    init(id: String, title: String, count: Int, notebookID: UUID? = nil, shelfID: UUID? = nil) {
        self.id = id
        self.title = title
        self.count = count
        self.notebookID = notebookID
        self.shelfID = shelfID
    }

    var bookID: String? { id == "free" ? nil : id }
}

struct LibraryShelfView: View {
    @Query(sort: \JournalShelf.created) private var shelves: [JournalShelf]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var sheet: JournalSheetRoute?

    private var volumesByShelf: [(JournalShelf, [JournalVolume])] {
        shelves.map { shelf in
            let volumes = shelf.notebooks
                .sorted { $0.created < $1.created }
                .map { JournalVolume(id: $0.id.uuidString, title: $0.name, count: $0.entries.count,
                                     notebookID: $0.id, shelfID: shelf.id) }
            return (shelf, volumes)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Your journals, kept on this device. Choose a journal to open only the entries filed in it.")
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
                    NewJournalSheet(initialShelf: shelves.first { $0.id == shelfID }) { name, shelf in
                        context.insert(JournalNotebook(name: name, shelf: shelf)); try? context.save()
                    }
                case .renameJournal(let id):
                    if let journal = shelves.flatMap(\.notebooks).first(where: { $0.id == id }) {
                        RenameJournalSheet(title: journal.name) { name in journal.name = name; try? context.save() }
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
        }
    }

    private func shelfSpines(_ items: [JournalVolume], shelf: JournalShelf) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(items) { volume in
                    NavigationLink(value: volume) { spine(volume) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Rename") { if let id = volume.notebookID { sheet = JournalSheetRoute(kind: .renameJournal(id)) } }
                            Button("Move to shelf…") { if let id = volume.notebookID { sheet = JournalSheetRoute(kind: .moveJournal(id)) } }
                        }
                }
                JournalShelfAddSpine { sheet = JournalSheetRoute(kind: .newJournal(shelf.id)) }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            LibraryPlank()
        }
    }

    private func spine(_ volume: JournalVolume) -> some View {
        let colors: [Color] = [.terracotta, .lavender, .olive, .wheat, Color(hex: "#93AECF"), .stoneShade]
        let color = colors[abs(volume.id.hashValue) % colors.count]
        let height = CGFloat(110 + min(volume.count, 10) * 4)
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
    @State private var page = 0
    @State private var editing: JournalEntry?
    @State private var adding = false
    @State private var confirmingDelete = false

    private var entries: [JournalEntry] {
        if let notebookID = volume.notebookID {
            return all.filter { $0.notebook?.id == notebookID }
        }
        return all.filter { $0.bookID == volume.bookID }
    }

    var body: some View {
        VStack(spacing: 12) {
            if entries.isEmpty {
                Spacer()
                Text("This book is empty.").foregroundStyle(Color.secondaryText)
                Spacer()
            } else {
                TabView(selection: $page) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        JournalPageView(entry: entry).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                Text("Page \(min(page, entries.count - 1) + 1) of \(entries.count)")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(.bottom, 12)
        .themedScreen()
        .navigationTitle(volume.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { adding = true } label: { Label("Add page", systemImage: "plus") }
                Spacer()
                Button { editing = current } label: { Label("Edit page", systemImage: "pencil") }
                    .disabled(current == nil)
                Spacer()
                Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete page", systemImage: "trash") }
                    .disabled(current == nil)
            }
        }
        .tint(Color.primaryBrown)
        .onAppear {
            if let startAt, let index = entries.firstIndex(where: { $0.id == startAt }) { page = index }
        }
        .sheet(item: $editing) { JournalEditor(entry: $0, bookID: volume.bookID) }
        .sheet(isPresented: $adding) { JournalEditor(entry: nil, bookID: volume.bookID, notebookID: volume.notebookID) }
        .confirmationDialog("Delete this page?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let current { context.delete(current); try? context.save(); page = max(0, page - 1) }
            }
        }
    }

    private var current: JournalEntry? { entries.indices.contains(page) ? entries[page] : nil }
}

/// A single page, like a sheet of paper.
struct JournalPageView: View {
    let entry: JournalEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(entry.reference ?? "Free entry")
                        .font(.headline)
                        .foregroundStyle(Color.terracotta)
                    Spacer()
                    Text(entry.created.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }
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
            }
            .padding(22)
            .background(Color(hex: "#FFF9EE"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.primaryBrown.opacity(0.10), radius: 8, y: 3)
            .padding(16)
        }
    }
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
                        Text("\(book.name) (whole book)").tag(0)
                        ForEach(Array(book.chapterNumbers), id: \.self) { Text("\(book.name) \($0)").tag($0) }
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
                        .foregroundStyle(Color.terracotta)
                }
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(hex: "#FFF9EE"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel("Journal text")
            }
            .padding(16)
            .themedScreen()
            .navigationTitle(entry == nil ? "New page" : "Edit page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                    NewJournalSheet(initialShelf: (try? context.fetch(FetchDescriptor<JournalShelf>())).flatMap { $0.first { $0.id == shelfID } }) { name, shelf in
                        let notebook = JournalNotebook(name: name, shelf: shelf)
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
    }
}

struct JournalSheetRoute: Identifiable {
    enum Kind {
        case newShelf
        case renameShelf(UUID)
        case newJournal(UUID?)
        case renameJournal(UUID)
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
                    Section(shelf.label) {
                        ForEach(shelf.notebooks.sorted { $0.created < $1.created }, id: \.id) { notebook in
                            Button {
                                onSelected(notebook)
                                dismiss()
                            } label: {
                                Label(notebook.name, systemImage: "book.closed")
                            }
                        }
                    }
                }
                Button("New journal…") {
                    dismiss()
                    onNewJournal(shelves.first)
                }
            }
            .navigationTitle("Save to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.primaryBrown)
                }
            }
            .themedScreen()
        }
    }
}

struct NewShelfSheet: View {
    var onCreate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Shelf label", text: $label)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("New shelf")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(label.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct NewJournalSheet: View {
    let initialShelf: JournalShelf?
    var onCreate: (String, JournalShelf) -> Void

    @Query(sort: \JournalShelf.created) private var shelves: [JournalShelf]
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedShelfID: UUID?

    private var selectedShelf: JournalShelf? {
        shelves.first { $0.id == selectedShelfID } ?? initialShelf ?? shelves.first
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                Section("Shelf") {
                    ForEach(shelves, id: \.id) { shelf in
                        Button {
                            selectedShelfID = shelf.id
                        } label: {
                            HStack {
                                Text(shelf.label).foregroundStyle(Color.bodyText)
                                Spacer()
                                if shelf.id == selectedShelf?.id {
                                    Image(systemName: "checkmark").foregroundStyle(Color.terracotta)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New journal")
            .onAppear { selectedShelfID = initialShelf?.id ?? shelves.first?.id }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let shelf = selectedShelf, !trimmed.isEmpty {
                            onCreate(trimmed, shelf)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedShelf == nil)
                }
            }
        }
    }
}

struct RenameJournalSheet: View {
    let title: String
    var onRename: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(title: String, onRename: @escaping (String) -> Void) {
        self.title = title
        self.onRename = onRename
        _name = State(initialValue: title)
    }

    var body: some View {
        NavigationStack {
            Form { TextField("Name", text: $name) }
                .navigationTitle("Rename journal")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { onRename(trimmed); dismiss() }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}

struct RenameShelfSheet: View {
    let title: String
    var onRename: (String) -> Void
    var body: some View {
        RenameJournalSheet(title: title, onRename: onRename)
            .navigationTitle("Rename shelf")
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
                Button(shelf.label) {
                    onMove(shelf)
                    dismiss()
                }
            }
            .navigationTitle("Move journal to…")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
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
                    Section { Text("Delete “\(shelf.label)”?”") }
                    Button("Delete shelf", role: .destructive) {
                        onDeleteEmpty()
                        dismiss()
                    }
                } else {
                    Section("Move \(shelf.notebooks.count) journals to:") {
                        ForEach(otherShelves, id: \.id) { target in
                            Button(target.label) {
                                onMoveAndDelete(target)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Delete shelf")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct JournalShelfAddSpine: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                Text("New journal")
                    .font(.caption2)
            }
            .foregroundStyle(Color.primaryBrown)
            .frame(width: 76, height: 118)
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
