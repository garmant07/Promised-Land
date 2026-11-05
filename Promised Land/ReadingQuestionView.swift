import SwiftUI
import SwiftData

/// After "Finish": one easy question about the chapter. A right answer counts it (and the island
/// grows); a wrong one has no penalty: "Have another look", then try again. Chapters without a
/// question yet get a gentle reflection instead (anything you write counts, and it's saved to
/// your journal).
struct ReadingQuestionView: View {
    let book: Book
    let chapter: Int
    /// Called once the chapter counts.
    var onCounted: () -> Void
    /// "Have another look": back to the text.
    var onLookAgain: () -> Void

    @Environment(\.modelContext) private var context
    @State private var picked: Int?
    @State private var reflection = ""

    private var question: ChapterQuestion? { QuestionData.question(bookID: book.id, chapter: chapter) }
    private var prompt: String { ReflectionData.prompts(bookID: book.id, chapter: chapter).prompts.first ?? ReflectionData.general[0] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(book.name) \(chapter)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.terracotta)
                        .textCase(.uppercase)
                    if let question { questionCard(question) } else { reflectionCard }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("One quick question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back to reading") { onLookAgain() }.tint(Color.primaryBrown) }
            }
        }
    }

    private func questionCard(_ q: ChapterQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(q.prompt)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Color.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                DraftBadge(item: q)
            }
            ForEach(q.options.indices, id: \.self) { i in
                let isPicked = picked == i
                let right = i == q.answer
                Button {
                    guard picked != q.answer else { return }
                    withAnimation(.easeOut(duration: 0.2)) { picked = i }
                    if right { count() }
                } label: {
                    HStack {
                        Text(q.options[i]).foregroundStyle(Color.bodyText).multilineTextAlignment(.leading)
                        Spacer()
                        if isPicked {
                            Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(right ? Color.olive : Color.terracotta)
                        }
                    }
                    .padding(12)
                    .frame(minHeight: 52)
                    .background(isPicked ? (right ? Color.olive.opacity(0.2) : Color.terracotta.opacity(0.15)) : Color.card,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            if let picked, picked != q.answer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Not quite. Have another look at the chapter, then try again.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                    Button("Have another look") { onLookAgain() }
                        .buttonStyle(SoftButtonStyle())
                }
            }
            if picked == q.answer {
                Label("That's right. \(book.name) \(chapter) counts.", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(Color.olive)
            }
        }
        .cardStyle()
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prompt)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.bodyText)
            TextEditor(text: $reflection)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
                .padding(8)
                .background(Color.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("Your reflection")
            Text("Saved privately in your journal.")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
            Button("Save and count it") {
                context.insert(JournalEntry(bookID: book.id, chapter: chapter, prompt: prompt,
                                            text: reflection.trimmingCharacters(in: .whitespacesAndNewlines)))
                try? context.save()
                count()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(reflection.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
        }
        .cardStyle()
    }

    private func count() {
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            onCounted()
        }
    }
}

/// The Finish button, with a ring that fills as the reading time passes.
struct FinishButton: View {
    let progress: Double
    let enabled: Bool
    var title = "Finish"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.onPrimary.opacity(0.3), lineWidth: 3)
                    Circle().trim(from: 0, to: progress)
                        .stroke(Color.onPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if enabled { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                }
                .frame(width: 22, height: 22)
                Text(enabled ? title : "Keep reading")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .opacity(enabled ? 1 : 0.75)
        .disabled(!enabled)
        .accessibilityValue(enabled ? "Ready" : "\(Int(progress * 100)) percent")
    }
}

#Preview("Question") {
    ReadingQuestionView(book: BibleCatalog.book(id: "john")!, chapter: 15, onCounted: {}, onLookAgain: {})
        .modelContainer(PreviewData.container)
}

#Preview("Reflection") {
    ReadingQuestionView(book: BibleCatalog.book(id: "obadiah")!, chapter: 1, onCounted: {}, onLookAgain: {})
        .modelContainer(PreviewData.container)
}
