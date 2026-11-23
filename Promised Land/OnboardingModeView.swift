import SwiftUI

struct OnboardingModeView: View {
    @Binding var isStrict: Bool
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)

            Text("How do you want to read?")
                .font(.serifTitle(.largeTitle))
                .foregroundStyle(Color.bodyText)
                .multilineTextAlignment(.center)

            Text("You can change this anytime in Settings.")
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                modeCard(
                    title: "Easy mode",
                    detail: "Questions help you remember what you read, but you can skip them. Every chapter still counts.",
                    selected: !isStrict
                ) { isStrict = false }

                modeCard(
                    title: "Strict mode",
                    detail: "Answer the questions after each chapter to count it. No skipping, for when you want a challenge.",
                    selected: isStrict
                ) { isStrict = true }
            }

            Spacer()

            Button("Next", action: onNext)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.vertical, 24)
        .themedScreen()
    }

    private func modeCard(title: String, detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.bodyText)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.olive : Color.secondaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? Color.olive : Color.primaryBrown.opacity(0.12), lineWidth: selected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview("Easy selected") {
    OnboardingModeView(isStrict: .constant(false), onNext: {})
        .padding()
}
