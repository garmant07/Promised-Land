import SwiftUI
import SwiftData

/// The place sheet for a landmark: progress, plus Read / Take quiz / Memorise.
struct PlaceDetailView: View {
    let landmark: Landmark

    @ProgressQuery private var progress: GameProgress
    @State private var showingQuiz = false
    @State private var showingMemorise = false

    private var stage: BuildStage { progress.stage(of: landmark.bookID) }
    private var level: GrowthLevel { progress.level(of: landmark.bookID) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LandmarkArtView(landmark: landmark, stage: stage, level: level, size: 220,
                                read: progress.chaptersRead(landmark.bookID))
                    .padding(.top, 8)
                    .animation(.spring(duration: 0.5), value: stage)

                VStack(spacing: 6) {
                    Text(landmark.name)
                        .font(.serifTitle(.largeTitle))
                        .foregroundStyle(Color.bodyText)
                        .multilineTextAlignment(.center)
                    Text("\(landmark.book?.name ?? "") · \(landmark.region?.name ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                }

                if let book = landmark.book {
                    progressCard(book)
                    actions(book)
                }

                if stage == .complete, !landmark.characters.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Living here")
                            .font(.serifTitle(.title3))
                            .foregroundStyle(Color.bodyText)
                        ForEach(landmark.characters) { character in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(character.name).font(.headline).foregroundStyle(Color.bodyText)
                                Text("\u{201C}\(character.line)\u{201D}")
                                    .font(.system(.subheadline, design: .serif).italic())
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .themedScreen()
        .navigationTitle(landmark.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingQuiz) {
            if let learning = landmark.learning { QuizView(landmark: landmark, learning: learning) }
        }
        .sheet(isPresented: $showingMemorise) {
            if let learning = landmark.learning { MemoriseView(landmark: landmark, learning: learning) }
        }
    }

    private func progressCard(_ book: Book) -> some View {
        let read = progress.chaptersRead(book.id)
        let reads = book.chapterNumbers.reduce(0) { $0 + progress.readCount(book.id, chapter: $1) }
        let last = book.chapterNumbers.compactMap { progress.lastRead(book.id, chapter: $0) }.max()
        return VStack(alignment: .leading, spacing: 12) {
            if read > 0 {
                Text("Built by reading \(book.name): \(reads) \(reads == 1 ? "read" : "reads") in all" +
                     (last.map { ", most recently \($0.formatted(.dateTime.month(.abbreviated).day()))." } ?? "."))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
            HStack {
                Text(stage.title)
                    .font(.serifTitle(.title3))
                    .foregroundStyle(Color.bodyText)
                Spacer()
                Text("\(read) of \(book.chapterCount) chapters")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.secondaryText)
            }
            ProgressView(value: Double(read), total: Double(book.chapterCount))
                .tint(Color.olive)
            GrowthSteps(stage: stage, level: level)
        }
        .cardStyle()
    }

    @ViewBuilder
    private func actions(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let next = book.chapterNumbers.first { !progress.isRead(book.id, chapter: $0) }
            if let next {
                NavigationLink(value: ChapterRef(bookID: book.id, chapter: next)) {
                    Text(stage == .plot ? "Start reading \(book.name)" : "Continue: \(book.name) \(next)")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            NavigationLink(value: book) {
                Text("All chapters")
            }
            .buttonStyle(SoftButtonStyle())

            if let learning = landmark.learning {
                Button(progress.hasPassedQuiz(book.id) ? "Quiz passed ✓" : "Take the quiz") { showingQuiz = true }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(stage == .plot || progress.hasPassedQuiz(book.id))
                Button(progress.hasMemorised(book.id) ? "Verse memorised ✓" : "Memorise \(learning.memoryVerse.reference)") {
                    showingMemorise = true
                }
                .buttonStyle(SoftButtonStyle())
                .disabled(!progress.hasPassedQuiz(book.id) || progress.hasMemorised(book.id))
                Text(hint(book))
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            } else {
                Label("Quiz and memory verse coming soon", systemImage: "hourglass")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                    .frame(minHeight: 44)
            }
        }
        .cardStyle()
    }

    private func hint(_ book: Book) -> String {
        if stage == .plot { return "Read a chapter to lay foundations and unlock the quiz." }
        if !progress.hasPassedQuiz(book.id) { return "Pass the quiz to add trees and decorations." }
        if !progress.hasMemorised(book.id) { return "Memorise the verse to make \(landmark.name) glow." }
        return "\(landmark.name) is flourishing."
    }
}

/// Build stages followed by quiz / memorise levels.
struct GrowthSteps: View {
    let stage: BuildStage
    let level: GrowthLevel

    var body: some View {
        let steps: [(Bool, String, String)] = [
            (stage >= .foundations, "Foundations", "square.stack.3d.up.fill"),
            (stage >= .rising, "Rising", "hammer.fill"),
            (stage >= .complete, "Complete", "building.columns.fill"),
            (level >= .growing, "Growing", "leaf.fill"),
            (level >= .flourishing, "Flourishing", "sparkles"),
        ]
        HStack(spacing: 4) {
            ForEach(steps, id: \.1) { step in
                VStack(spacing: 5) {
                    Image(systemName: step.2)
                        .font(.footnote)
                        .foregroundStyle(step.0 ? Color.onPrimary : Color.secondaryText.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(step.0 ? Color.olive : Color.sand, in: Circle())
                    Text(step.1)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(step.0 ? Color.bodyText : Color.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityValue(step.0 ? "Reached" : "Not yet")
            }
        }
    }
}

struct LandmarkRow: View {
    let landmark: Landmark
    let progress: GameProgress

    var body: some View {
        let stage = progress.stage(of: landmark.bookID)
        HStack(spacing: 14) {
            LandmarkArtView(landmark: landmark, stage: stage, level: progress.level(of: landmark.bookID), size: 56,
                            read: progress.chaptersRead(landmark.bookID))
            VStack(alignment: .leading, spacing: 4) {
                Text(landmark.name)
                    .font(.headline)
                    .foregroundStyle(Color.bodyText)
                Text("\(landmark.book?.name ?? "") · \(stage.title)")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText.opacity(0.6))
        }
        .padding(12)
        .frame(minHeight: 64)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        PlaceDetailView(landmark: WorldData.landmark(bookID: "ruth")!)
            .readingDestinations()
    }
    .modelContainer(PreviewData.container)
}
