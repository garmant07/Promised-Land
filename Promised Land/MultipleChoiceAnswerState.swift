import Foundation

struct MultipleChoiceAnswerState: Equatable {
    private(set) var selected: Int?
    private(set) var revealed = false
    private(set) var isRight = false

    var canContinue: Bool {
        selected != nil && revealed && isRight
    }

    var canSelect: Bool {
        selected == nil
    }

    init(selected: Int? = nil, revealed: Bool = false, isRight: Bool = false) {
        self.selected = selected
        self.revealed = revealed
        self.isRight = isRight
    }

    mutating func select(index: Int, correctIndex: Int) {
        guard canSelect else { return }
        selected = index
        revealed = true
        isRight = index == correctIndex
    }

    mutating func tryAgain() {
        self = Self()
    }

    mutating func showAnswer(correctIndex: Int) {
        selected = correctIndex
        revealed = true
        isRight = true
    }
}
