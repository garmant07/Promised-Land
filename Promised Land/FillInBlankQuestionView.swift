import SwiftUI

struct FillInBlankQuestionView: View {
    let bookName: String
    let chapter: Int
    let question: ChapterQuestion
    let questionNumber: Int
    let questionCount: Int
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var answerState = MultipleChoiceAnswerState()
    @State private var slotFrame = CGRect.zero
    @State private var slotVisible = false
    @State private var shakeOffset: CGFloat = 0
    @State private var successHaptic = 0
    @State private var errorHaptic = 0
    @State private var selectionHaptic = 0
    @State private var returnTask: Task<Void, Never>?
    @State private var fadingBackIndex: Int?
    @GestureState private var dragState = DragState()

    private let coordinateSpaceName = "fill-in-blank"
    private static let dropZoneExpansion: CGFloat = 24
    private static let dragThreshold: CGFloat = 10

    static func isDropLocation(_ location: CGPoint, in frame: CGRect) -> Bool {
        frame.insetBy(dx: -dropZoneExpansion, dy: -dropZoneExpansion).contains(location)
    }

    private struct DragState: Equatable {
        var offset = CGSize.zero
        var index: Int?
    }
    private var longestWordWidth: CGFloat {
        max(90, question.options.map { CGFloat($0.count) * 11 + 34 }.max() ?? 90)
    }

    private var promptParts: [String] {
        question.prompt.components(separatedBy: "____")
    }

    private func words(in text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
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

            verseCard
            chips

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
        .coordinateSpace(name: coordinateSpaceName)
        .sensoryFeedback(.success, trigger: successHaptic)
        .sensoryFeedback(.error, trigger: errorHaptic)
        .sensoryFeedback(.selection, trigger: selectionHaptic)
        .onDisappear {
            returnTask?.cancel()
        }
    }

    private var verseCard: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(words(in: promptParts[0]).enumerated()), id: \.offset) { _, word in
                Text(word)
                    .font(.serifTitle(.title2))
                    .foregroundStyle(Color.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            blankSlot

            if promptParts.count > 1 {
                ForEach(Array(words(in: promptParts[1]).enumerated()), id: \.offset) { _, word in
                    Text(word)
                        .font(.serifTitle(.title2))
                        .foregroundStyle(Color.bodyText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var blankSlot: some View {
        let isFilled = slotVisible, isRight = answerState.isRight
        return Text(isFilled ? question.options[answerState.selected ?? question.answer] : "Blank")
            .font(.body.weight(.semibold))
            .foregroundStyle(isFilled ? Color.bodyText : Color.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minWidth: longestWordWidth, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFilled ? (isRight ? Color.olive.opacity(0.28) : Color.terracotta.opacity(0.28)) : Color.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isFilled ? (isRight ? Color.olive : Color.terracotta) : Color.secondaryText,
                        style: StrokeStyle(lineWidth: 2, dash: isFilled ? [] : [6, 4])
                    )
            }
            .offset(x: shakeOffset)
            .accessibilityLabel(isFilled ? "Blank, \(question.options[answerState.selected ?? question.answer])" : "Blank")
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(coordinateSpaceName))
            } action: { frame in
                guard frame.origin.x.isFinite, frame.origin.y.isFinite,
                      frame.size.width.isFinite, frame.size.height.isFinite,
                      frame.size.width >= 0, frame.size.height >= 0 else { return }
                guard abs(frame.minX - slotFrame.minX) >= 1 ||
                      abs(frame.minY - slotFrame.minY) >= 1 ||
                      abs(frame.width - slotFrame.width) >= 1 ||
                      abs(frame.height - slotFrame.height) >= 1 else { return }
                slotFrame = frame
            }
    }

    private var chips: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, word in
                WordChip(word: word, isVisible: chipIsVisible(index)) {
                    place(index)
                }
                .offset(dragOffsetFor(index))
                .animation(
                    dragState.index == nil && !reduceMotion
                        ? .spring(response: 0.32, dampingFraction: 0.78)
                        : nil,
                    value: dragState
                )
                .opacity(fadingBackIndex == index ? 0 : 1)
                .highPriorityGesture(dragGesture(for: index))
                .disabled(!answerState.canSelect || (answerState.selected == index && slotVisible))
            }
        }
    }

    private func chipIsVisible(_ index: Int) -> Bool {
        !(slotVisible && answerState.selected == index)
    }

    private func dragOffsetFor(_ index: Int) -> CGSize {
        guard answerState.canSelect, dragState.index == index,
              answerState.selected == nil else { return .zero }
        return dragState.offset
    }

    private func dragGesture(for index: Int) -> some Gesture {
        DragGesture(
            minimumDistance: Self.dragThreshold,
            coordinateSpace: .named(coordinateSpaceName)
        )
            .updating($dragState) { value, state, _ in
                guard answerState.canSelect,
                      state.index == nil || state.index == index else { return }
                state.offset = value.translation
                state.index = index
            }
            .onEnded { value in
                guard answerState.canSelect else { return }
                guard Self.isDropLocation(value.location, in: slotFrame) else {
                    rejectDrop(index)
                    return
                }
                place(index)
            }
    }

    private func rejectDrop(_ index: Int) {
        guard reduceMotion else { return }
        returnTask?.cancel()
        withAnimation(.easeOut(duration: 0.12)) {
            fadingBackIndex = index
        }
        returnTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            fadingBackIndex = nil
        }
    }

    private func place(_ index: Int) {
        guard answerState.canSelect, question.options.indices.contains(index) else { return }
        returnTask?.cancel()
        answerState.select(index: index, correctIndex: question.answer)
        slotVisible = true

        if answerState.isRight {
            successHaptic += 1
        } else {
            errorHaptic += 1
            animateWrongAnswer()
        }
    }

    private func animateWrongAnswer() {
        guard !reduceMotion else {
            scheduleWrongAnswerReturn()
            return
        }

        withAnimation(.default) {
            shakeOffset = 8
        }
        withAnimation(.easeInOut(duration: 0.1).repeatCount(5, autoreverses: true)) {
            shakeOffset = -8
        }
        scheduleWrongAnswerReturn()
    }

    private func scheduleWrongAnswerReturn() {
        returnTask?.cancel()
        returnTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                slotVisible = false
                shakeOffset = 0
            }
        }
    }

    private func tryAgain() {
        returnTask?.cancel()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            answerState.tryAgain()
            slotVisible = false
            shakeOffset = 0
        }
        selectionHaptic += 1
    }

    private func showAnswer() {
        returnTask?.cancel()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            answerState.showAnswer(correctIndex: question.answer)
            slotVisible = true
            shakeOffset = 0
        }
        selectionHaptic += 1
    }
}

#Preview("Genesis 1 fill in the blank") {
    FillInBlankQuestionView(
        bookName: "Genesis",
        chapter: 1,
        question: ChapterQuestion(
            bookID: "genesis",
            chapter: 1,
            prompt: "“In the beginning God ____ the heavens and the earth.” (1:1)",
            options: ["named", "created", "blessed", "visited"],
            answer: 1,
            reference: "Genesis 1:1",
            reviewed: true,
            lesson: "God is the Creator and everything else is created.",
            difficulty: .easy,
            format: .fillInBlank
        ),
        questionNumber: 1,
        questionCount: 4,
        onContinue: {}
    )
    .background(Color.cream)
}
