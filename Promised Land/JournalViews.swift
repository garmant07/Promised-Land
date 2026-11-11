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
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 96)
                                .padding(8)
                                .background(Color.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .accessibilityLabel(prompts[i])
                        }
                        .cardStyle()
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
        }
    }

    private func save(_ prompts: [String]) {
        for (prompt, answer) in zip(prompts, answers) {
            let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            context.insert(JournalEntry(bookID: book.id, chapter: chapter, prompt: prompt, text: text))
        }
        try? context.save()
        onSaved?()
        dismiss()
    }
}

// MARK: - Library (journals on shelves)

/// A volume on the shelf: one per Bible book with entries, plus free entries.
struct JournalVolume: Identifiable, Hashable {
    let id: String          // book id, or "free"
    let title: String
    let count: Int
    var bookID: String? { id == "free" ? nil : id }
}

struct LibraryShelfView: View {
    @Query(sort: \JournalEntry.created) private var entries: [JournalEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var newFreeEntry = false
    @State private var summary = LibrarySummaryCache<JournalEntry, LibraryJournalSummary>()

    private var volumes: [JournalVolume] {
        summary.value(for: entries, build: { LibraryJournalSummary(entries: $0) }).volumes
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Your journals, one book for each part of Scripture you've written about. Kept only on this device.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                    if volumes.isEmpty {
                        Text("No entries yet. Reflect after reading a chapter, or write a free entry.")
                            .foregroundStyle(Color.secondaryText)
                            .cardStyle()
                    }
                    // Shelves of five spines each.
                    ForEach(Array(stride(from: 0, to: volumes.count, by: 5)), id: \.self) { start in
                        shelf(Array(volumes[start..<min(start + 5, volumes.count)]))
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: JournalVolume.self) { JournalBookView(volume: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { newFreeEntry = true } label: { Label("New entry", systemImage: "square.and.pencil") }
                        .tint(Color.primaryBrown)
                }
            }
            .sheet(isPresented: $newFreeEntry) { JournalEditor(entry: nil, bookID: nil) }
        }
    }

    private func shelf(_ items: [JournalVolume]) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(items) { volume in
                    NavigationLink(value: volume) { spine(volume) }
                        .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: "#C79A6C"))
                .frame(height: 12)
                .shadow(color: Color.primaryBrown.opacity(0.2), radius: 3, y: 3)
        }
    }

    private func spine(_ volume: JournalVolume) -> some View {
        let colors: [Color] = [.terracotta, .lavender, .olive, .wheat, Color(hex: "#93AECF"), .stoneShade]
        let color = colors[abs(volume.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % colors.count]
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
}

/// One journal volume: page through its entries; add, edit and delete pages.
struct JournalBookView: View {
    let volume: JournalVolume
    /// Opens at this page, if given.
    var startAt: UUID? = nil

    @Query(sort: \JournalEntry.created) private var all: [JournalEntry]
    @Environment(\.modelContext) private var context
    @State private var page = 0
    @State private var summary = LibrarySummaryCache<JournalEntry, LibraryJournalSummary>()
    @State private var editing: JournalEntry?
    @State private var adding = false
    @State private var confirmingDelete = false

    private var entries: [JournalEntry] {
        summary.value(for: all, build: { LibraryJournalSummary(entries: $0) }).entries(for: volume.bookID)
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
        .sheet(isPresented: $adding) { JournalEditor(entry: nil, bookID: volume.bookID) }
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

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var chapter = 0 // 0 = whole book

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
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let entry {
            entry.text = trimmed
            entry.chapter = chapter == 0 ? nil : chapter
            entry.updated = .now
        } else {
            context.insert(JournalEntry(bookID: bookID, chapter: chapter == 0 ? nil : chapter, text: trimmed))
        }
        try? context.save()
        dismiss()
    }
}

#Preview("Library") {
    LibraryShelfView()
        .modelContainer(PreviewData.container)
}
