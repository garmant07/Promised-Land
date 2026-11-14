import SwiftUI
import SwiftData

/// After "Mark complete": one easy question about the chapter. A right answer counts it (and the island
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
    @Environment(\.bibleService) private var bible
    private var translation = TranslationChoice()
    @State private var questionSet: [ChapterQuestion]?
    @State private var questionIndex = 0
    @State private var reflection = ""
    @State private var noteSaveFailed = false
    @State private var selectedNotebook: JournalNotebook?
    @State private var picker: JournalPickerRoute?
    @State private var newJournal: JournalSheetRoute?

    private var currentQuestion: ChapterQuestion? {
        guard let questionSet, questionSet.indices.contains(questionIndex) else { return nil }
        return questionSet[questionIndex]
    }

    private var prompt: String { ReflectionData.prompts(bookID: book.id, chapter: chapter).prompts.first ?? ReflectionData.general[0] }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let questionSet, let question = currentQuestion,
                       question.format == .trueFalse {
                        TrueFalseQuestionView(
                            bookName: book.name,
                            chapter: chapter,
                            question: question,
                            questionNumber: questionIndex + 1,
                            questionCount: questionSet.count,
                            onContinue: continueQuestion
                        )
                        .id(questionIndex)
                    } else if let questionSet, let question = currentQuestion,
                              question.format == .multipleChoice {
                        MultipleChoiceQuestionView(
                            bookName: book.name,
                            chapter: chapter,
                            question: question,
                            questionNumber: questionIndex + 1,
                            questionCount: questionSet.count,
                            onContinue: continueQuestion
                        )
                        .id(questionIndex)
                    } else if let questionSet, let question = currentQuestion,
                              question.format == .fillInBlank {
                        FillInBlankQuestionView(
                            bookName: book.name,
                            chapter: chapter,
                            question: question,
                            questionNumber: questionIndex + 1,
                            questionCount: questionSet.count,
                            onContinue: continueQuestion
                        )
                        .id(questionIndex)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("\(book.name) \(chapter)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.secondaryText)
                                .textCase(.uppercase)
                            if questionSet == nil {
                                ProgressView()
                                    .tint(Color.primaryBrown)
                                    .frame(maxWidth: .infinity)
                            } else {
                                reflectionCard
                            }
                        }
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("One quick question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back to reading") { onLookAgain() }.tint(Color.primaryBrown) }
            }
            .tint(Color.primaryBrown)
        }
        .task(id: "\(book.id)-\(chapter)-\(translation.current?.rawValue ?? "")") {
            questionSet = QuestionData.quizQuestions(bookID: book.id, chapter: chapter, service: bible, translation: translation.current)
            questionIndex = 0
        }
    }

    private func continueQuestion() {
        guard let questionSet else { return }
        if questionIndex + 1 < questionSet.count {
            questionIndex += 1
        } else {
            count()
        }
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
                .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("Your reflection")
            Text("Saved privately in your journal.")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
            JournalDestinationRow(name: selectedNotebook?.name ?? "Choose a journal") {
                picker = JournalPickerRoute()
            }
            Button("Save and count it") {
                do {
                    let notebook = try selectedNotebook ?? JournalStore.preferredNotebook(in: context, bookID: book.id)
                    try JournalStore.save(in: context, notebook: notebook, text: reflection,
                                          bookID: book.id, chapter: chapter, prompt: prompt)
                    noteSaveFailed = false
                } catch {
                    noteSaveFailed = true
                }
                // As before, a note-save failure does not prevent this chapter from counting.
                count()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(reflection.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
        }
        .cardStyle()
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
    }

    private func count() {
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            onCounted()
            if noteSaveFailed { JournalSaveNotice.shared.isPresented = true }
        }
    }
}

/// "Keep reading · 2:41" while the reading time runs (counting down, with a ring that fills);
/// once it's done, "Mark complete", or "Mark complete again" for a chapter already read.
struct FinishButton: View {
    let progress: Double
    let enabled: Bool
    /// Seconds of reading time still to go.
    var remaining: Double = 0
    /// The chapter has been read before.
    var readBefore = false
    let action: () -> Void

    static func title(readBefore: Bool) -> String { readBefore ? "Mark complete again" : "Mark complete" }

    /// What the button says: the time left while reading, then Mark complete (again).
    static func label(enabled: Bool, remaining: Double, readBefore: Bool) -> String {
        if enabled { return title(readBefore: readBefore) }
        let left = Int(remaining.rounded(.up))
        return left > 0 ? "Keep reading \u{00B7} \(left / 60):\(String(format: "%02d", left % 60))" : "Keep reading"
    }

    /// The time left in words, for VoiceOver ("2 minutes 41 seconds left").
    static func spokenTimeLeft(_ remaining: Double) -> String {
        let left = Int(remaining.rounded(.up))
        let m = left / 60, s = left % 60
        let parts = (m > 0 ? ["\(m) minute\(m == 1 ? "" : "s")"] : []) + (s > 0 || m == 0 ? ["\(s) second\(s == 1 ? "" : "s")"] : [])
        return parts.joined(separator: " ") + " left"
    }

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
                Text(Self.label(enabled: enabled, remaining: remaining, readBefore: readBefore))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    // The digits roll once a second, and the switch to Mark complete eases in.
                    .animation(.easeInOut(duration: 0.25), value: Self.label(enabled: enabled, remaining: remaining, readBefore: readBefore))
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .opacity(enabled ? 1 : 0.75)
        .disabled(!enabled)
        .accessibilityLabel(enabled ? Self.title(readBefore: readBefore) : "Keep reading")
        .accessibilityValue(enabled ? "Ready" : remaining > 0 ? Self.spokenTimeLeft(remaining) : "Read to the end")
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
