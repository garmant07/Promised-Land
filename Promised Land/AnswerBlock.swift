import SwiftUI

enum AnswerBlockStatus {
    case idle
    case right
    case wrong
    case dimmed
}

struct AnswerBlock: View {
    let letter: String
    let text: String
    let status: AnswerBlockStatus
    let action: () -> Void

    private var backgroundColor: Color {
        switch status {
        case .idle, .dimmed:
            Color.card
        case .right:
            Color.olive
        case .wrong:
            Color.terracotta
        }
    }

    private var iconName: String? {
        switch status {
        case .right:
            "checkmark"
        case .wrong:
            "xmark"
        case .idle, .dimmed:
            nil
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(letter)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.primaryBrown)
                    .frame(width: 24, alignment: .leading)

                Text(text)
                    .font(.body)
                    .foregroundStyle(Color.bodyText)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                if let iconName {
                    Image(systemName: iconName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.bodyText)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.bodyText.opacity(0.3), lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(status == .dimmed ? 0.45 : 1)
        .accessibilityLabel("(letter), (text)")
        .accessibilityValue(status == .right ? "Correct" : status == .wrong ? "Incorrect" : "")
    }
}

#Preview("Answer block") {
    VStack(spacing: 12) {
        AnswerBlock(letter: "A", text: "An example answer", status: .idle, action: {})
        AnswerBlock(letter: "B", text: "The selected answer", status: .right, action: {})
        AnswerBlock(letter: "C", text: "A wrong answer", status: .wrong, action: {})
    }
    .padding()
    .background(Color.cream)
}
