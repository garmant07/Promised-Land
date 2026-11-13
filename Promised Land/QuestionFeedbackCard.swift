import SwiftUI

struct QuestionFeedbackCard: View {
    let isRight: Bool
    let lesson: String?
    let canContinue: Bool
    let onTryAgain: () -> Void
    let onShowAnswer: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isRight ? "That's right" : "Not quite")
                .font(.headline)
                .foregroundStyle(Color.bodyText)

            if let lesson, !lesson.isEmpty {
                Text(lesson)
                    .font(.body)
                    .foregroundStyle(Color.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if canContinue {
                Button("Continue", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                HStack(spacing: 12) {
                    Button("Try again", action: onTryAgain)
                        .buttonStyle(SoftButtonStyle())
                    Button("Show answer", action: onShowAnswer)
                        .buttonStyle(SoftButtonStyle())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview("Right feedback") {
    QuestionFeedbackCard(
        isRight: true,
        lesson: "A short lesson.",
        canContinue: true,
        onTryAgain: {},
        onShowAnswer: {},
        onContinue: {}
    )
    .padding()
    .background(Color.cream)
}

