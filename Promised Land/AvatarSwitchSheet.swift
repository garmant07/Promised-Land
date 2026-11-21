import SwiftUI

struct AvatarSexSwitchRequest: Identifiable {
    let id: AvatarSex
    let target: AvatarSex
}

struct AvatarSwitchSheet: View {
    let current: AvatarConfig
    let target: AvatarSex
    var onSwitch: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var targetName: String { target.rawValue.capitalized }
    private var currentName: String { current.sex?.rawValue.capitalized ?? "Current" }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                AvatarView(config: current)
                    .frame(width: 88, height: 140)
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color.secondaryText)
                AvatarView(config: current.switched(to: target))
                    .frame(width: 88, height: 140)
            }

            Text("Switch to \(targetName)?")
                .font(.serifTitle(.title2))
                .foregroundStyle(Color.bodyText)
            Text("Your character goes back to the \(target.rawValue) starting look. Your skin tone stays the same.")
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)

            Button("Switch to \(targetName)") { onSwitch(); dismiss() }
                .buttonStyle(PrimaryButtonStyle())
            Button("Keep \(currentName)") { dismiss() }
                .buttonStyle(SoftButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: 520)
        .themedScreen()
        .presentationDetents([.medium])
    }
}
