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

    @Test("Imported questions take priority over older entries")
    func importedQuestionsTakePriority() {
        let questions = QuestionData.questions(bookID: "genesis", chapter: 6)
        #expect(questions.count == 8)
        #expect(questions.allSatisfy { $0.reviewed && $0.lesson != nil })
    }

    @Test("A reflection-only chapter returns no questions")
    func reflectionChapterReturnsNoQuestions() {
        #expect(QuestionData.questions(bookID: "not-a-book", chapter: 1).isEmpty)
    }

    @Test("Imported Genesis contains eight reviewed questions in every chapter")
    func importedGenesis() {
        for chapter in 1...50 {
            let questions = QuestionData.questions(bookID: "genesis", chapter: chapter)
            #expect(questions.count == 8)
            for question in questions {
                #expect(question.lesson?.isEmpty == false)
                #expect(question.difficulty != nil)
                #expect(question.reviewed)
                #expect(question.options.indices.contains(question.answer))
                if question.format == .fillInBlank {
                    #expect(question.prompt.components(separatedBy: "____").count == 2)
                }
            }
        }
    }

    @Test("Imported fill-in prompts keep punctuation next to their blank")
    func importedFillInPromptPunctuation() {
        for book in BibleCatalog.books {
            for chapter in book.chapterNumbers {
                for question in QuestionData.questions(bookID: book.id, chapter: chapter)
                    where question.format == .fillInBlank {
                    #expect(question.prompt.range(of: #"____\s+[.,;:?!”’)]"#, options: .regularExpression) == nil,
                             "\(book.name) \(chapter): \(question.prompt)")
                }
            }
        }
    }

    @Test("A quiz selects three distinct imported questions and keeps its selection")
    func quizSelection() {
        let selected = QuestionData.quizQuestions(bookID: "genesis", chapter: 1,
                                                   service: BundledBibleService(), translation: nil)
        #expect(selected.count == 3)
        #expect(Set(selected.map { $0.prompt }).count == 3)
        #expect(selected == selected)
    }

    @Test("Fill-in quiz questions receive four distinct chips with one correct answer")
    func fillInWordBank() {
        var fillIn: ChapterQuestion?
        for _ in 0..<10 {
            let selection = QuestionData.quizQuestions(bookID: "genesis", chapter: 1,
                                                       service: BundledBibleService(), translation: nil)
            fillIn = selection.first { $0.format == .fillInBlank }
            if fillIn != nil { break }
        }
        #expect(fillIn?.options.count == 4)
        if let fillIn {
            #expect(fillIn.options.indices.contains(fillIn.answer))
            #expect(Set(fillIn.options.map { $0.lowercased() }).count == 4)
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
        let question = QuestionData.questions(bookID: "genesis", chapter: 1).first { $0.format == .fillInBlank }!
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
