import SwiftUI

struct WordChip: View {
    let word: String
    var isVisible = true
    var action: () -> Void = {}

    var body: some View {
        Text(word)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.bodyText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(Color.card, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.bodyText.opacity(0.22), lineWidth: 1)
            }
            .contentShape(Capsule())
            .onTapGesture(perform: action)
            .opacity(isVisible ? 1 : 0)
            .accessibilityLabel("\(word), button")
            .accessibilityAddTraits(.isButton)
    }
}

#Preview("Word chips") {
    FlowLayout(spacing: 8) {
        WordChip(word: "created")
        WordChip(word: "visited")
        WordChip(word: "blessed")
        WordChip(word: "named")
    }
    .padding()
    .background(Color.cream)
}
