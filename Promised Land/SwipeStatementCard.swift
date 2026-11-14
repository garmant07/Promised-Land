import SwiftUI

enum TrueFalseAnswer: Equatable {
    case trueAnswer
    case falseAnswer

    var label: String {
        switch self {
        case .trueAnswer: "True"
        case .falseAnswer: "False"
        }
    }

    var isTrue: Bool {
        self == .trueAnswer
    }
}

enum SwipeStatementDecision: Equatable {
    case trueAnswer
    case falseAnswer
    case none
}

struct SwipeStatementCard: View {
    let statement: String
    let correctAnswer: TrueFalseAnswer
    let selectedAnswer: TrueFalseAnswer?
    let isRight: Bool
    let showsAnswer: Bool
    let onAnswer: (TrueFalseAnswer) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragOffset: CGFloat = 0

    static let dragMinimum: CGFloat = 15
    static let answerDistance: CGFloat = 100
    static let flickDistance: CGFloat = 200

    static func decision(offset: CGFloat, predictedEnd: CGFloat) -> SwipeStatementDecision {
        if offset >= answerDistance || predictedEnd >= flickDistance {
            return .trueAnswer
        }
        if offset <= -answerDistance || predictedEnd <= -flickDistance {
            return .falseAnswer
        }
        return .none
    }

    private var answerOffset: CGFloat {
        guard let selectedAnswer else { return 0 }
        return selectedAnswer == .trueAnswer ? 24 : -24
    }

    private var offset: CGFloat {
        selectedAnswer == nil ? dragOffset : answerOffset
    }

    private var answerRotation: Double {
        guard selectedAnswer != nil else { return 0 }
        return selectedAnswer == .trueAnswer ? 5 : -5
    }

    private var rotation: Double {
        guard !reduceMotion else { return 0 }
        if selectedAnswer != nil { return answerRotation }
        return Double(max(-8, min(8, dragOffset / 100 * 8)))
    }

    private var tint: Color {
        guard selectedAnswer != nil else { return Color.card }
        return isRight ? Color.olive.opacity(0.22) : Color.terracotta.opacity(0.22)
    }

    private var border: Color {
        guard selectedAnswer != nil else { return Color.primaryBrown.opacity(0.45) }
        return isRight ? Color.olive : Color.terracotta
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                VStack(spacing: 12) {
                    Text(statement)
                        .font(.serifTitle(.title2))
                        .foregroundStyle(Color.bodyText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if showsAnswer {
                        Text("The answer is \(correctAnswer.label)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.bodyText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(border, lineWidth: 2)
                }
                .overlay(alignment: .leading) {
                    if selectedAnswer == nil, dragOffset > 40 {
                        Text("True")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.olive)
                            .padding(.leading, 12)
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .trailing) {
                    if selectedAnswer == nil, dragOffset < -40 {
                        Text("False")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.terracotta)
                            .padding(.trailing, 12)
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let selectedAnswer {
                        Image(systemName: isRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(isRight ? Color.olive : Color.terracotta)
                            .padding(12)
                            .transition(.opacity)
                    }
                }
            }
            Text("Swipe right for true, left for false")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
        }
        .offset(x: offset)
        .rotationEffect(.degrees(rotation))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statement)
        .accessibilityHint("Swipe right for true, left for false")
        .accessibilityAction(named: "Answer true") {
            guard selectedAnswer == nil else { return }
            onAnswer(.trueAnswer)
        }
        .accessibilityAction(named: "Answer false") {
            guard selectedAnswer == nil else { return }
            onAnswer(.falseAnswer)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: Self.dragMinimum)
                .updating($dragOffset) { value, state, _ in
                    guard selectedAnswer == nil,
                          abs(value.translation.width) > abs(value.translation.height) else {
                        state = 0
                        return
                    }
                    state = value.translation.width
                }
                .onEnded { value in
                    guard selectedAnswer == nil else { return }
                    switch Self.decision(
                        offset: value.translation.width,
                        predictedEnd: value.predictedEndTranslation.width
                    ) {
                    case .trueAnswer:
                        onAnswer(.trueAnswer)
                    case .falseAnswer:
                        onAnswer(.falseAnswer)
                    case .none:
                        break
                    }
                }
        )
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.78), value: offset)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isRight)
    }
}

#Preview("Swipe statement card") {
    SwipeStatementCard(
        statement: "God created both male and female in His image. (1:27)",
        correctAnswer: .trueAnswer,
        selectedAnswer: nil,
        isRight: false,
        showsAnswer: false,
        onAnswer: {}
    )
    .padding()
    .background(Color.cream)
}
