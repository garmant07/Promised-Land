import SwiftUI
import SwiftData

struct QuizView: View {
    let landmark: Landmark
    let learning: BookLearning

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var selected: Int?
    @State private var correct = 0
    @State private var finished = false

    private var questions: [QuizQuestion] { learning.quiz }
    private var bookName: String { landmark.book?.name ?? "" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if finished {
                        results
                    } else {
                        question(questions[index])
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("\(bookName) quiz")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .frame(minHeight: 44)
                        .tint(Color.primaryBrown)
                }
            }
        }
    }

    private func question(_ q: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Question \(index + 1) of \(questions.count)")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
            ProgressView(value: Double(index), total: Double(questions.count))
                .tint(Color.olive)
            Text(q.prompt)
                .font(.serifTitle(.title2))
                .foregroundStyle(Color.bodyText)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(q.options.indices, id: \.self) { i in
                Button {
                    guard selected == nil else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        selected = i
                        if i == q.answerIndex { correct += 1 }
                    }
                } label: {
                    HStack {
                        Text(q.options[i])
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if let symbol = symbol(for: i, in: q) {
                            Image(systemName: symbol)
                        }
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.bodyText)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(background(for: i, in: q),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(selected != nil)
            }

            if selected != nil {
                Button(index + 1 < questions.count ? "Next question" : "See results") {
                    withAnimation {
                        if index + 1 < questions.count {
                            index += 1
                            selected = nil
                        } else {
                            finish()
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            }
        }
    }

    private func symbol(for i: Int, in q: QuizQuestion) -> String? {
        guard let selected else { return nil }
        if i == q.answerIndex { return "checkmark.circle.fill" }
        if i == selected { return "xmark.circle.fill" }
        return nil
    }

    private func background(for i: Int, in q: QuizQuestion) -> Color {
        guard let selected else { return .card }
        if i == q.answerIndex { return Color.olive.opacity(0.45) }
        if i == selected { return Color.terracotta.opacity(0.45) }
        return .card
    }

    private var passed: Bool { correct >= learning.passMark }

    private func finish() {
        finished = true
        if passed { context.recordQuizPass(landmark.bookID, score: correct) }
    }

    private var results: some View {
        VStack(spacing: 18) {
            LandmarkArtView(landmark: landmark, stage: .foundations, level: passed ? .growing : .base, size: 180)
            Text(passed ? "\(landmark.name) is growing!" : "Nearly there")
                .font(.serifTitle(.title))
                .foregroundStyle(Color.bodyText)
                .multilineTextAlignment(.center)
            Text("You answered \(correct) of \(questions.count) correctly.")
                .foregroundStyle(Color.secondaryText)
            if passed {
                Button("Back to my world") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Text("You need \(learning.passMark) correct to pass. Have another look at \(bookName) and try again.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.secondaryText)
                Button("Try again") {
                    withAnimation {
                        index = 0; selected = nil; correct = 0; finished = false
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Close") { dismiss() }
                    .buttonStyle(SoftButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    QuizView(landmark: WorldData.landmark(bookID: "ruth")!, learning: LearningData.forBook("ruth")!)
        .modelContainer(PreviewData.container)
}
