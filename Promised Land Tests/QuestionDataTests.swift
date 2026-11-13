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

    @Test("The Genesis 1–3 test sets return three questions in order")
    func genesisTestSetOrder() {
        #expect(QuestionData.questions(bookID: "genesis", chapter: 1).count == 3)
        #expect(QuestionData.questions(bookID: "genesis", chapter: 2).count == 3)
        #expect(QuestionData.questions(bookID: "genesis", chapter: 3).count == 3)
        #expect(QuestionData.questions(bookID: "genesis", chapter: 1).map(\.answer) == [3, 2, 2])
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
                #expect(question.format == .multipleChoice)
            }
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
}
