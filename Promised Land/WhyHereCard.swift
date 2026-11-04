import SwiftUI
import SwiftData

/// "Why is this here?": what built a story object, and your history with that chapter.
struct WhyHereCard: View {
    let entry: ChapterLandmark

    @ProgressQuery private var progress: GameProgress
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \JournalEntry.created, order: .reverse) private var journal: [JournalEntry]

    private var notes: [JournalEntry] {
        journal.filter { $0.bookID == entry.bookID && ($0.chapter.map { entry.chapters.contains($0) } ?? false) }
    }

    var body: some View {
        let history = progress.history(of: entry)
        let depth = progress.depth(of: entry)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ChapterObjectArtView(entry: entry, depth: max(1, depth))
                        .frame(height: 280)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(entry.name)
                                .font(.serifTitle(.title2))
                                .foregroundStyle(Color.bodyText)
                            DraftBadge(item: entry)
                        }
                        Text(entry.chapterLabel)
                            .font(.headline)
                            .foregroundStyle(Color.terracotta)
                        Text(entry.summary)
                            .font(.system(.body, design: .serif).italic())
                            .foregroundStyle(Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Why is this here?")
                            .font(.serifTitle(.title3))
                            .foregroundStyle(Color.bodyText)
                        Text(historyLine(history))
                            .foregroundStyle(Color.bodyText)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            stat("\(history.thisYear)", "this year")
                            stat("\(depth) of 5", "depth")
                        }
                        if entry.chapters.count > 1 {
                            ForEach(Array(entry.chapters), id: \.self) { chapter in
                                let n = progress.readCount(entry.bookID, chapter: chapter)
                                HStack {
                                    Text("\(entry.book?.name ?? "") \(chapter)")
                                    Spacer()
                                    Text(n == 0 ? "not yet read" : "\(n)×")
                                        .foregroundStyle(Color.secondaryText)
                                }
                                .font(.subheadline)
                            }
                        }
                        Text("Each reread adds a little more to it, up to five.")
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText)
                    }
                    .cardStyle()

                    if !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("From your journal")
                                .font(.serifTitle(.title3))
                                .foregroundStyle(Color.bodyText)
                            ForEach(notes) { note in
                                NavigationLink {
                                    JournalPageView(entry: note).themedScreen()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.reference ?? "")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.terracotta)
                                            Text(note.text)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.bodyText)
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(Color.secondaryText.opacity(0.6))
                                    }
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .cardStyle()
                    }

                    NavigationLink(value: ChapterRef(bookID: entry.bookID, chapter: chapterToRead)) {
                        Text(history.reads == 0 ? "Read \(entry.chapterLabel)" : "Read again")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(entry.reference) · Source: \(entry.source)")
                        if ContentGate.showsDrafts, !entry.note.isEmpty {
                            Text("Reviewer note: \(entry.note)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Why is this here?")
            .navigationBarTitleDisplayMode(.inline)
            .readingDestinations()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
            }
        }
    }

    /// The chapter of this object read least (so "Read again" spreads across a range).
    private var chapterToRead: Int {
        entry.chapters.min { progress.readCount(entry.bookID, chapter: $0) < progress.readCount(entry.bookID, chapter: $1) }
            ?? entry.chapters.lowerBound
    }

    private func historyLine(_ h: (reads: Int, last: Date?, thisYear: Int)) -> String {
        guard h.reads > 0 else { return "Read \(entry.chapterLabel) to build it." }
        let times = h.reads == 1 ? "once" : "\(h.reads) times"
        let what = entry.chapters.count == 1 ? "this chapter" : "these chapters"
        let when = h.last.map { ", most recently \($0.formatted(.dateTime.month(.abbreviated).day()))" } ?? ""
        return "\(entry.name): \(entry.chapterLabel). You've read \(what) \(times)\(when)."
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(Color.bodyText)
            Text(label).font(.caption).foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(Color.sand.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// The story object's artwork, drawn by the same painter as the map.
struct ChapterObjectArtView: View {
    let entry: ChapterLandmark
    let depth: Int

    var body: some View {
        let look = ChapterObjectLook(kind: entry.kind, depth: depth, variant: entry.variant, size: 3)
        if let art = ChapterObjectPainter.render(look, scale: 2) {
            Image(decorative: art.image, scale: 2)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Reading history

struct StatsView: View {
    @ProgressQuery private var progress: GameProgress
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Whole Bible")
                            .font(.serifTitle(.title3))
                            .foregroundStyle(Color.bodyText)
                        Text("\(Int((progress.overallFraction * 100).rounded(.down)))%")
                            .font(.system(size: 44, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.primaryBrown)
                        ProgressView(value: progress.overallFraction)
                            .tint(Color.olive)
                        Text("\(progress.totalChaptersRead) of \(progress.totalChapters) chapters read at least once")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                    }
                    .cardStyle()

                    HStack(spacing: 12) {
                        tile("\(progress.chaptersReadThisYear)", "chapters read this year")
                        tile("\(progress.rereads)", progress.rereads == 1 ? "reread" : "rereads")
                    }
                    HStack(spacing: 12) {
                        tile("\(progress.totalReadsThisYear)", "reads this year")
                        tile("\(progress.streak)", progress.streak == 1 ? "day streak" : "day streak")
                    }

                    if !JourneyData.visible.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Journeys")
                                .font(.serifTitle(.title3))
                                .foregroundStyle(Color.bodyText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(JourneyData.visible) { journey in
                                        JourneyBadge(journey: journey, earned: progress.isComplete(journey))
                                    }
                                }
                            }
                            Text("\(progress.completedJourneys.count) of \(JourneyData.visible.count) journeys complete")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        }
                        .cardStyle()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Most-read books")
                            .font(.serifTitle(.title3))
                            .foregroundStyle(Color.bodyText)
                        let top = Array(progress.mostReadBooks.prefix(5))
                        if top.isEmpty {
                            Text("Nothing read yet. Your first chapter will show up here.")
                                .foregroundStyle(Color.secondaryText)
                        }
                        ForEach(top, id: \.book.id) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.book.name).font(.headline).foregroundStyle(Color.bodyText)
                                    Spacer()
                                    Text("\(item.reads) \(item.reads == 1 ? "read" : "reads")")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(Color.secondaryText)
                                }
                                ProgressView(value: Double(item.reads), total: Double(max(1, top.first?.reads ?? 1)))
                                    .tint(Color.terracotta)
                            }
                        }
                    }
                    .cardStyle()
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Reading history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
            }
        }
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title, design: .serif).weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.bodyText)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
        }
        .cardStyle()
    }
}

#Preview("Why is this here") {
    WhyHereCard(entry: ChapterLandmarks.all.first { $0.id == "true-vine" }!)
        .modelContainer(PreviewData.container)
}

#Preview("Stats") {
    StatsView()
        .modelContainer(PreviewData.container)
}
