import SwiftUI
import SwiftData

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0
    @State private var selectedCharacterSex: AvatarSex?
    @Environment(\.modelContext) private var context
    @Query private var profiles: [AvatarProfile]
    @AppStorage(StorageKeys.ageGroup) private var ageGroup = ""
    @AppStorage(StorageKeys.playerName) private var playerName = ""
    @State private var nameError: String?

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                AgeGroupPicker(selection: $ageGroup)
                    .padding(.horizontal, 24)
                    .tag(0)

                OnboardingNameView(name: $playerName, errorMessage: nameError)
                    .padding(.horizontal, 24)
                    .tag(1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        OnboardingCharacterFlow { sex in
                            let profile = AvatarProfile.ensure(in: context)
                            profile.apply(OnboardingAvatarSelection.config(for: sex))
                            try? context.save()
                            selectedCharacterSex = sex
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                .tag(2)
                .task { AvatarProfile.ensure(in: context) }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < pageCount - 1 ? "Next" : "Begin the journey") {
                if page == 1 {
                    let normalized = FirstJourneyName.normalized(playerName)
                    guard !normalized.isEmpty else {
                        nameError = "Enter your first name"
                        return
                    }
                    playerName = normalized
                    nameError = nil
                }

                if page < pageCount - 1 {
                    withAnimation { page += 1 }
                } else if profiles.first?.config.sex != nil {
                    onFinish()
                }
            }
            .onChange(of: playerName) { _, value in
                if !value.isEmpty {
                    nameError = nil
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
        .background(Color.cream.ignoresSafeArea())
        .fullScreenCover(
            isPresented: Binding(
                get: { selectedCharacterSex != nil },
                set: { if !$0 { returnToCharacterChoice() } }
            )
        ) {
            AvatarCreatorView(
                onDone: {
                    selectedCharacterSex = nil
                    onFinish()
                },
                onBack: {
                    returnToCharacterChoice()
                },
                showsName: false,
                doneTitle: "Begin the journey"
            )
        }
    }

    private func returnToCharacterChoice() {
        if let profile = profiles.first {
            profile.apply(AvatarConfig())
            try? context.save()
        }
        selectedCharacterSex = nil
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .modelContainer(PreviewData.container)
}
