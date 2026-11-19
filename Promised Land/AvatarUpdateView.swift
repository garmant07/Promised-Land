import SwiftUI
import SwiftData

enum AvatarUpdateRouting {
    static func shouldPresent(hasOnboarded: Bool, sex: AvatarSex?) -> Bool {
        hasOnboarded && sex == nil
    }

    static func selectedConfig(_ config: AvatarConfig, side: AvatarSex) -> AvatarConfig {
        config.converted(to: side)
    }
}

struct AvatarEditingFlowView: View {
    var onDone: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var profiles: [AvatarProfile]
    @State private var choseSide = false

    var body: some View {
        if let profile = profiles.first {
            if choseSide || profile.config.sex != nil {
                AvatarCreatorView(onDone: onDone)
            } else {
                AvatarUpdateView(config: profile.config) { sex in
                    profile.apply(AvatarUpdateRouting.selectedConfig(profile.config, side: sex))
                    try? context.save()
                    choseSide = true
                }
            }
        } else {
            ProgressView()
                .task { AvatarProfile.ensure(in: context) }
        }
    }
}

struct AvatarUpdateView: View {
    let config: AvatarConfig
    var onPick: (AvatarSex) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("New")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.primaryBrown)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.sand, in: Capsule())
            Text("Characters just got an update")
                .font(.serifTitle(.largeTitle))
                .foregroundStyle(Color.bodyText)
                .multilineTextAlignment(.center)
            Text("Is your character male or female? We'll keep your skin tone, colours and everything else that fits. Next you can check your look and tweak anything.")
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                AvatarUpdateCard(sex: .male, config: config.converted(to: .male)) { onPick(.male) }
                AvatarUpdateCard(sex: .female, config: config.converted(to: .female)) { onPick(.female) }
            }

            Text("Your island, journals and reading progress aren't affected.")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
        .themedScreen()
    }
}

private struct AvatarUpdateCard: View {
    let sex: AvatarSex
    let config: AvatarConfig
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                AvatarView(config: config)
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

#Preview("Update") {
    AvatarUpdateView(config: AvatarConfig()) { _ in }
}
