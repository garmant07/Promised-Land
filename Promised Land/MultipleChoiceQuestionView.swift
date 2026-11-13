import SwiftUI

struct MultipleChoiceQuestionView: View {
    let bookName: String
    let chapter: Int
    let question: ChapterQuestion
    let questionNumber: Int
    let questionCount: Int
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var answerState = MultipleChoiceAnswerState()
    @State private var successHaptic = 0
    @State private var errorHaptic = 0
    @State private var selectionHaptic = 0

    private let letters = ["A", "B", "C", "D"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            MultipleChoiceHeader(
                bookName: bookName,
                chapter: chapter,
                questionNumber: questionNumber,
                questionCount: questionCount,
                difficulty: question.difficulty
            )

            HStack(alignment: .top, spacing: 8) {
                Text(question.prompt)
                    .font(.serifTitle(.title2))
                    .foregroundStyle(Color.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                DraftBadge(item: question)
            }

            VStack(spacing: 12) {
                ForEach(Array(question.options.prefix(letters.count).enumerated()), id: \.offset) { index, option in
                    AnswerBlock(
                        letter: letters[index],
                        text: option,
                        status: status(for: index),
                        action: { select(index) }
                    )
                    .disabled(!answerState.canSelect)
                }
            }

            if answerState.revealed {
                QuestionFeedbackCard(
                    isRight: answerState.isRight,
                    lesson: question.lesson,
                    canContinue: answerState.canContinue,
                    onTryAgain: tryAgain,
                    onShowAnswer: showAnswer,
                    onContinue: onContinue
                )
            }
        }
        .padding(20)
        .background(Color.cream)
        .sensoryFeedback(.success, trigger: successHaptic)
        .sensoryFeedback(.error, trigger: errorHaptic)
        .sensoryFeedback(.selection, trigger: selectionHaptic)
    }

    private func status(for index: Int) -> AnswerBlockStatus {
        guard answerState.revealed else { return .idle }
        if answerState.isRight && index == question.answer {
            return .right
        }
        if answerState.selected == index {
            return .wrong
        }
        return .dimmed
    }

    private func select(_ index: Int) {
        guard answerState.canSelect else { return }
        animate {
            answerState.select(index: index, correctIndex: question.answer)
        }
        if answerState.isRight {
            successHaptic += 1
        } else {
            errorHaptic += 1
        }
    }

    private func tryAgain() {
        animate {
            answerState.tryAgain()
        }
        selectionHaptic += 1
    }

    private func showAnswer() {
        animate {
            answerState.showAnswer(correctIndex: question.answer)
        }
        selectionHaptic += 1
    }

    private func animate(_ changes: () -> Void) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(.easeOut(duration: 0.2), changes)
        }
    }
}

struct MultipleChoiceHeader: View {
    let bookName: String
    let chapter: Int
    let questionNumber: Int
    let questionCount: Int
    let difficulty: QuestionDifficulty?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(headerText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.bodyText)
                Spacer()
                if let difficulty {
                    Text(difficultyLabel(difficulty))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.bodyText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.card, in: Capsule())
                }
            }

            if questionCount > 1 {
                HStack(spacing: 5) {
                    ForEach(1...questionCount, id: \.self) { number in
                        Capsule()
                            .fill(number <= questionNumber ? Color.primaryBrown : Color.card)
                            .frame(height: 6)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Question progress")
                .accessibilityValue("\(questionNumber) of \(questionCount)")
            }
        }
    }

    private var headerText: String {
        Self.headerText(bookName: bookName, chapter: chapter, questionNumber: questionNumber, questionCount: questionCount)
    }

    static func headerText(bookName: String, chapter: Int, questionNumber: Int, questionCount: Int) -> String {
        if questionCount > 1 {
            "\(bookName) \(chapter) · Question \(questionNumber) of \(questionCount)"
        } else {
            "\(bookName) \(chapter)"
        }
    }

    private func difficultyLabel(_ difficulty: QuestionDifficulty) -> String {
        switch difficulty {
        case .easy:
            "Easy"
        case .medium:
            "Medium"
        case .hard:
            "Hard"
        }
    }
}

#Preview("Genesis 1 multiple choice") {
    MultipleChoiceQuestionView(
        bookName: "Genesis",
        chapter: 1,
        question: ChapterQuestion(
            bookID: "genesis",
            chapter: 1,
            prompt: "How did God make light? (1:3)",
            options: ["He gathered it from the stars", "He took it from the sun", "Angels made it for Him", "He spoke, and it was"],
            answer: 3,
            reference: "Genesis 1:3",
            reviewed: true,
            lesson: "God's word has power. When He speaks, it happens, so His words to us can be trusted.",
            difficulty: .easy
        ),
        questionNumber: 1,
        questionCount: 3,
        onContinue: {}
    )
    .padding()
    .background(Color.cream)
}
