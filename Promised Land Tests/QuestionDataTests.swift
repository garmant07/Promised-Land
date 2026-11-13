import Testing
@testable import Promised_Land

@MainActor
struct QuestionDataTests {
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
}
