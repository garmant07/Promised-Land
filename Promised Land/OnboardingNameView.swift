import SwiftUI

struct OnboardingNameView: View {
    @Binding var name: String
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("What should we call you?")
                .font(.serifTitle(.largeTitle))
                .foregroundStyle(Color.bodyText)
                .multilineTextAlignment(.center)

            TextField("Your first name", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.body)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(errorMessage == nil ? Color.primaryBrown.opacity(0.12) : Color.red.opacity(0.7), lineWidth: 1)
                }
                .accessibilityLabel("Your first name")
                .onChange(of: name) { _, newValue in
                    let limited = String(newValue.prefix(FirstJourneyName.maximumLength))
                    if limited != newValue {
                        name = limited
                    }
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Shown on your island and in settings")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .themedScreen()
    }
}

#Preview {
    OnboardingNameView(name: .constant(""), errorMessage: nil)
}
