import SwiftUI
import SwiftData

// MARK: - Library

struct LibraryView: View {
    @ProgressQuery private var progress: GameProgress

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Read")
                        .font(.serifTitle(.largeTitle))
                        .foregroundStyle(Color.bodyText)
                        .padding(.top, 8)
                    Text("Read in any order. Finish a book to unlock its place in your world.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                        .padding(.bottom, 4)
                    ForEach(BibleData.books) { book in
                        NavigationLink(value: book) {
                            BookRow(book: book, read: progress.chaptersRead(in: book))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .themedScreen()
            .navigationTitle("Read")
            .hiddenNavigationBar()
            .navigationDestination(for: Book.self) { BookView(book: $0) }
            .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
        }
    }
}

struct BookRow: View {
    let book: Book
    let read: Int

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(book.name)
                    .font(.serifTitle(.title3))
                    .foregroundStyle(Color.bodyText)
                if let place = Place.forBook(book.id) {
                    Label(place.name, systemImage: read == book.chapters.count ? "checkmark.seal.fill" : "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }
                ProgressView(value: Double(read), total: Double(book.chapters.count))
                    .tint(Color.olive)
            }
            Text("\(read)/\(book.chapters.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.secondaryText)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText.opacity(0.6))
        }
        .cardStyle()
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Book

struct BookView: View {
    let book: Book
    @ProgressQuery private var progress: GameProgress

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let place = Place.forBook(book.id) {
                    NavigationLink(value: place) {
                        PlaceRow(place: place, level: progress.level(of: place),
                                 chaptersRead: progress.chaptersRead(in: book))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
                Text("Chapters")
                    .font(.serifTitle(.title3))
                    .foregroundStyle(Color.bodyText)
                ForEach(book.chapters) { chapter in
                    NavigationLink {
                        ChapterReaderView(book: book, chapter: chapter)
                    } label: {
                        chapterRow(chapter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .themedScreen()
        .navigationTitle(book.name)
    }

    private func chapterRow(_ chapter: Chapter) -> some View {
        let isRead = progress.isRead(book.id, chapter: chapter.number)
        return HStack {
            Text("Chapter \(chapter.number)")
                .font(.headline)
                .foregroundStyle(Color.bodyText)
            Spacer()
            Image(systemName: isRead ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isRead ? Color.olive : Color.stoneShade)
                .accessibilityLabel(isRead ? "Read" : "Not read")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Reader

struct ChapterReaderView: View {
    let book: Book
    let chapter: Chapter

    @Environment(\.modelContext) private var context
    @ProgressQuery private var progress: GameProgress
    @State private var unlockedPlace: Place?

    private var isRead: Bool { progress.isRead(book.id, chapter: chapter.number) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("\(book.name) \(chapter.number)")
                    .font(.serifTitle(.largeTitle))
                    .foregroundStyle(Color.bodyText)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(chapter.verses) { verse in
                        let number = Text("\(verse.number)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.terracotta)
                        Text("\(number)  \(verse.text)")
                            .foregroundStyle(Color.bodyText)
                            .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .cardStyle()

                Text("American Standard Version · sample text")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)

                if isRead {
                    Label("You've read this chapter", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Color.olive)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Button("Mark as unread") { toggle() }
                        .buttonStyle(SoftButtonStyle())
                } else {
                    Button("Mark as read") { toggle() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .themedScreen()
        .navigationTitle("Chapter \(chapter.number)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $unlockedPlace) { place in
            CelebrationView(place: place, message: "You finished \(book.name) and unlocked a new place in your world.")
        }
    }

    private func toggle() {
        let wasLocked = Place.forBook(book.id).map { progress.level(of: $0) == .locked } ?? false
        let readOthers = book.chapters.filter { $0.number != chapter.number && progress.isRead(book.id, chapter: $0.number) }.count
        let willComplete = !isRead && readOthers == book.chapters.count - 1

        withAnimation { context.markChapter(book.id, chapter.number, read: !isRead) }

        if wasLocked && willComplete {
            unlockedPlace = Place.forBook(book.id)
        }
    }
}

// MARK: - Celebration

struct CelebrationView: View {
    let place: Place
    let message: String
    var level: GrowthLevel = .unlocked

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            PlaceTileView(place: place, level: level, width: 220)
            Text(place.name)
                .font(.serifTitle(.largeTitle))
                .foregroundStyle(Color.bodyText)
            Text(level.title)
                .font(.headline)
                .foregroundStyle(Color.terracotta)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondaryText)
            Spacer()
            Button("Wonderful") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream.ignoresSafeArea())
        .presentationDetents([.large])
    }
}
