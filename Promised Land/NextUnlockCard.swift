import SwiftUI

/// The single most useful next step, shown at the bottom of the World tab.
struct NextUnlock {
    let title: String
    let detail: String
    let landmark: Landmark

    static func suggest(from progress: GameProgress) -> NextUnlock? {
        // 1. A book already started: the one closest to its next stage.
        let started = WorldData.landmarks.compactMap { landmark -> (Landmark, Book, Int, Int)? in
            guard let book = landmark.book else { return nil }
            let read = progress.chaptersRead(book.id)
            guard read > 0, read < book.chapterCount else { return nil }
            let half = (book.chapterCount + 1) / 2
            let target = read < half ? half : book.chapterCount
            return (landmark, book, read, target - read)
        }
        if let (landmark, book, read, left) = started.min(by: { $0.3 < $1.3 }) {
            let goal = read < (book.chapterCount + 1) / 2 ? "raise its walls" : "complete it"
            return NextUnlock(title: landmark.name,
                              detail: "Read \(left) more \(left == 1 ? "chapter" : "chapters") of \(book.name) to \(goal).",
                              landmark: landmark)
        }
        // 2. A quiz or verse waiting.
        for landmark in WorldData.landmarks where progress.stage(of: landmark.bookID) > .plot {
            guard let learning = landmark.learning, let book = landmark.book else { continue }
            if !progress.hasPassedQuiz(book.id) {
                return NextUnlock(title: landmark.name, detail: "Pass the \(book.name) quiz to add trees and decorations.", landmark: landmark)
            }
            if !progress.hasMemorised(book.id) {
                return NextUnlock(title: landmark.name, detail: "Memorise \(learning.memoryVerse.reference) to make it glow.", landmark: landmark)
            }
        }
        // 3. Something new — prefer books with bundled text.
        let fresh = WorldData.landmarks.filter { progress.stage(of: $0.bookID) == .plot }
        if let landmark = fresh.first(where: { $0.book?.hasSampleText == true }) ?? fresh.first, let book = landmark.book {
            return NextUnlock(title: landmark.name, detail: "Read a chapter of \(book.name) to lift the fog and lay foundations.", landmark: landmark)
        }
        return nil
    }
}

struct NextUnlockCard: View {
    let next: NextUnlock
    @Binding var collapsed: Bool
    var open: (Landmark) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(duration: 0.35)) { collapsed.toggle() }
            } label: {
                HStack {
                    Label("Next unlock", systemImage: "sparkle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.terracotta)
                    if collapsed {
                        Text(next.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.bodyText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: collapsed ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.secondaryText)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(collapsed ? "Show next unlock" : "Hide next unlock")

            if !collapsed {
                Text(next.title)
                    .font(.serifTitle(.title3))
                    .foregroundStyle(Color.bodyText)
                Text(next.detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open \(next.title)") { open(next.landmark) }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.primaryBrown.opacity(0.12), radius: 12, y: 4)
    }
}
