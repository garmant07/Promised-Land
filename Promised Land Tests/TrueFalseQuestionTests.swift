import Foundation
import Testing
@testable import Promised_Land

@MainActor
struct TrueFalseQuestionTests {
    @Test("Swipe thresholds distinguish short drags, firm swipes and quick flicks")
    func swipeThresholds() {
        #expect(SwipeStatementCard.decision(offset: 40, predictedEnd: 80) == .none)
        #expect(SwipeStatementCard.decision(offset: 100, predictedEnd: 100) == .trueAnswer)
        #expect(SwipeStatementCard.decision(offset: -100, predictedEnd: -100) == .falseAnswer)
        #expect(SwipeStatementCard.decision(offset: 20, predictedEnd: 200) == .trueAnswer)
        #expect(SwipeStatementCard.decision(offset: -20, predictedEnd: -200) == .falseAnswer)
    }

    @Test("True and false Genesis questions use the shared answer state")
    func trueFalseAnswerState() {
        let trueQuestion = QuestionData.questions(bookID: "genesis", chapter: 1)[1]
        #expect(trueQuestion.format == .trueFalse)
        #expect(trueQuestion.options == ["True", "False"])

        var right = MultipleChoiceAnswerState()
        right.select(index: 0, correctIndex: trueQuestion.answer)
        #expect(right.isRight)
        #expect(right.canContinue)

        var wrong = MultipleChoiceAnswerState()
        wrong.select(index: 1, correctIndex: trueQuestion.answer)
        #expect(!wrong.isRight)
        #expect(!wrong.canContinue)

        wrong.tryAgain()
        #expect(wrong.selected == nil)
        #expect(!wrong.revealed)

        wrong.showAnswer(correctIndex: trueQuestion.answer)
        #expect(wrong.selected == trueQuestion.answer)
        #expect(wrong.isRight)
        #expect(wrong.canContinue)

        let falseQuestion = QuestionData.questions(bookID: "genesis", chapter: 3)[1]
        #expect(falseQuestion.answer == 1)
        var falseState = MultipleChoiceAnswerState()
        falseState.select(index: 1, correctIndex: falseQuestion.answer)
        #expect(falseState.isRight)
        #expect(falseState.canContinue)
    }
}
