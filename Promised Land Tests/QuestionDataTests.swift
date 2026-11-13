import Foundation
import Testing
@testable import Promised_Land

@MainActor
struct QuestionDataTests {
    @Test("Multiple choice header uses its values and omits the question label for one question")
    func multipleChoiceHeaderText() {
        #expect(MultipleChoiceHeader.headerText(bookName: "Genesis", chapter: 1, questionNumber: 2, questionCount: 3) == "Genesis 1 · Question 2 of 3")
        #expect(MultipleChoiceHeader.headerText(bookName: "Genesis", chapter: 1, questionNumber: 1, questionCount: 1) == "Genesis 1")
    }

    @Test("A chapter with only an old entry returns one question")
    func oldEntryFallsBackToOneQuestion() {
        let questions = QuestionData.questions(bookID: "genesis", chapter: 6)
        #expect(questions.count == 1)
        #expect(questions.first?.prompt == "What was Noah told to build?")
    }

    @Test("A reflection-only chapter returns no questions")
    func reflectionChapterReturnsNoQuestions() {
        #expect(QuestionData.questions(bookID: "obadiah", chapter: 1).isEmpty)
    }

    @Test("The Genesis 1–3 test sets return four questions with fill-in first")
    func genesisTestSetOrder() {
        for chapter in 1...3 {
            let questions = QuestionData.questions(bookID: "genesis", chapter: chapter)
            #expect(questions.count == 4)
            #expect(questions.first?.format == .fillInBlank)
        }
        #expect(QuestionData.questions(bookID: "genesis", chapter: 1).map(\.answer) == [1, 3, 2, 2])
    }

    @Test("Every Genesis 1–3 test question has four reviewed options, a lesson and a difficulty")
    func genesisTestSetMetadata() {
        for chapter in 1...3 {
            for question in QuestionData.questions(bookID: "genesis", chapter: chapter) {
                #expect(question.options.count == 4)
                #expect(question.options.indices.contains(question.answer))
                #expect(question.lesson?.isEmpty == false)
                #expect(question.difficulty != nil)
                #expect(question.reviewed)
                if question.format == .fillInBlank {
                    #expect(question.prompt.components(separatedBy: "____").count == 2)
                } else {
                    #expect(question.format == .multipleChoice)
                }
            }
        }
    }

    @Test("Fill-in questions have four chips and valid reviewed metadata")
    func fillInQuestionMetadata() {
        for chapter in 1...3 {
            let question = QuestionData.questions(bookID: "genesis", chapter: chapter).first
            #expect(question?.format == .fillInBlank)
            #expect(question?.prompt.components(separatedBy: "____").count == 2)
            #expect(question?.options.count == 4)
            #expect(question.map { $0.options.indices.contains($0.answer) } == true)
            #expect(question?.lesson?.isEmpty == false)
            #expect(question?.difficulty != nil)
            #expect(question?.reviewed == true)
        }
    }

    @Test("A right answer enables Continue and ignores later selections")
    func rightAnswerState() {
        var state = MultipleChoiceAnswerState()
        state.select(index: 2, correctIndex: 2)
        state.select(index: 1, correctIndex: 2)
        #expect(state.selected == 2)
        #expect(state.revealed)
        #expect(state.isRight)
        #expect(state.canContinue)
    }

    @Test("A wrong answer reveals feedback but not Continue")
    func wrongAnswerState() {
        var state = MultipleChoiceAnswerState()
        state.select(index: 1, correctIndex: 2)
        #expect(state.selected == 1)
        #expect(state.revealed)
        #expect(!state.isRight)
        #expect(!state.canContinue)
    }

    @Test("Try again clears the answer state")
    func tryAgainState() {
        var state = MultipleChoiceAnswerState()
        state.select(index: 1, correctIndex: 2)
        state.tryAgain()
        #expect(state.selected == nil)
        #expect(!state.revealed)
        #expect(!state.isRight)
        #expect(!state.canContinue)
    }

    @Test("Show answer selects the correct answer and enables Continue")
    func showAnswerState() {
        var state = MultipleChoiceAnswerState()
        state.select(index: 1, correctIndex: 2)
        state.showAnswer(correctIndex: 2)
        #expect(state.selected == 2)
        #expect(state.revealed)
        #expect(state.isRight)
        #expect(state.canContinue)
    }


    @Test("Fill-in answer state supports right and wrong chip placement")
    func fillInAnswerState() {
        let question = QuestionData.questions(bookID: "genesis", chapter: 1)[0]
        #expect(question.format == .fillInBlank)

        var right = MultipleChoiceAnswerState()
        right.select(index: question.answer, correctIndex: question.answer)
        #expect(right.isRight)
        #expect(right.canContinue)

        var wrong = MultipleChoiceAnswerState()
        let wrongIndex = question.answer == 0 ? 1 : 0
        wrong.select(index: wrongIndex, correctIndex: question.answer)
        #expect(!wrong.isRight)
        #expect(!wrong.canContinue)

        wrong.tryAgain()
        #expect(wrong.selected == nil)
        #expect(!wrong.revealed)

        wrong.showAnswer(correctIndex: question.answer)
        #expect(wrong.selected == question.answer)
        #expect(wrong.canContinue)
    }
}
