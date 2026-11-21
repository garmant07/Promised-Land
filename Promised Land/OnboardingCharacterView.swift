import SwiftUI
import SwiftData

nonisolated enum OnboardingAvatarSelection {
    static func config(for sex: AvatarSex) -> AvatarConfig {
        AvatarSexRules.defaults(for: sex)
    }
}

struct OnboardingCharacterFlow: View {
    @Environment(\.modelContext) private var context
    @State private var selectedSide: AvatarSex?

    var body: some View {
        if selectedSide != nil {
            AvatarCreatorView(onBack: { self.selectedSide = nil }, showsName: true)
        } else {
            OnboardingCharacterPickView { sex in
                let profile = AvatarProfile.ensure(in: context)
                profile.apply(OnboardingAvatarSelection.config(for: sex))
                try? context.save()
                self.selectedSide = sex
            } onBack: {
                // The parent owns the onboarding page navigation.
            }
        }
    }
}

struct OnboardingCharacterPickView: View {
    var onPick: (AvatarSex) -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .tint(Color.primaryBrown)
                Spacer()
            }

            Text("YOUR CHARACTER · STEP 1 OF 2")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.secondaryText)
            Text("Who's your character?")
                .font(.serifTitle(.largeTitle))
                .foregroundStyle(Color.bodyText)
                .multilineTextAlignment(.center)
            Text("Pick one to start. You'll choose hair, clothes and more next.")
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                OnboardingCharacterCard(sex: .male) { onPick(.male) }
                OnboardingCharacterCard(sex: .female) { onPick(.female) }
            }

            Text("You can switch later in Profile → Edit avatar.")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .themedScreen()
    }
}

private struct OnboardingCharacterCard: View {
    let sex: AvatarSex
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                AvatarView(config: OnboardingAvatarSelection.config(for: sex))
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                Text(sex.rawValue.capitalized)
                    .font(.headline)
                    .foregroundStyle(Color.primaryBrown)
            }
            .padding(12)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingCharacterPickView(onPick: { _ in }, onBack: {})
        .modelContainer(PreviewData.container)
}
