import SwiftUI

struct TrueFalseQuestionView: View {
    let bookName: String
    let chapter: Int
    let question: ChapterQuestion
    let questionNumber: Int
    let questionCount: Int
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var answerState = MultipleChoiceAnswerState()
    @State private var showingAnswer = false
    @State private var successHaptic = 0
    @State private var errorHaptic = 0
    @State private var selectionHaptic = 0

    private var selectedAnswer: TrueFalseAnswer? {
        switch answerState.selected {
        case 0: .trueAnswer
        case 1: .falseAnswer
        default: nil
        }
    }

    private var correctAnswer: TrueFalseAnswer {
        question.answer == 0 ? .trueAnswer : .falseAnswer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            MultipleChoiceHeader(
                bookName: bookName,
                chapter: chapter,
                questionNumber: questionNumber,
                questionCount: questionCount,
                difficulty: question.difficulty
            )

            SwipeStatementCard(
                statement: question.prompt,
                correctAnswer: correctAnswer,
                selectedAnswer: selectedAnswer,
                isRight: answerState.isRight,
                showsAnswer: showingAnswer,
                onAnswer: select
            )

            HStack(spacing: 12) {
                answerButton(.falseAnswer)
                answerButton(.trueAnswer)
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

    private func answerButton(_ answer: TrueFalseAnswer) -> some View {
        Button {
            select(answer)
        } label: {
            HStack(spacing: 8) {
                if answer == .falseAnswer {
                    Image(systemName: "chevron.left")
                }
                Text(answer.label)
                    .font(.body.weight(.semibold))
                if answer == .trueAnswer {
                    Image(systemName: "chevron.right")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(TrueFalseButtonStyle(isSelected: selectedAnswer == answer, isRight: answerState.isRight, revealed: answerState.revealed))
        .accessibilityLabel("\(answer.label), button")
        .disabled(!answerState.canSelect)
    }

    private func select(_ answer: TrueFalseAnswer) {
        guard answerState.canSelect else { return }
        showingAnswer = false
        let index = answer == .trueAnswer ? 0 : 1
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.8)) {
            answerState.select(index: index, correctIndex: question.answer)
        }
        if answerState.isRight {
            successHaptic += 1
        } else {
            errorHaptic += 1
        }
    }

    private func tryAgain() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.8)) {
            answerState.tryAgain()
            showingAnswer = false
        }
        selectionHaptic += 1
    }

    private func showAnswer() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            answerState.showAnswer(correctIndex: question.answer)
            showingAnswer = true
        }
        selectionHaptic += 1
    }
}

private struct TrueFalseButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isRight: Bool
    let revealed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.bodyText)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 2)
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }

    private var borderColor: Color {
        guard isSelected, revealed else { return Color.primaryBrown.opacity(0.45) }
        return isRight ? Color.olive : Color.terracotta
    }
}

#Preview("Genesis 1 true or false") {
    TrueFalseQuestionView(
        bookName: "Genesis",
        chapter: 1,
        question: ChapterQuestion(
            bookID: "genesis",
            chapter: 1,
            prompt: "God created both male and female in His image. (1:27)",
            options: ["True", "False"],
            answer: 0,
            reference: "Genesis 1:27",
            reviewed: true,
            lesson: "Men and women carry God’s image equally, and that gives every person dignity and worth.",
            difficulty: .easy,
            format: .trueFalse
        ),
        questionNumber: 2,
        questionCount: 5,
        onContinue: {}
    )
    .background(Color.cream)
}
