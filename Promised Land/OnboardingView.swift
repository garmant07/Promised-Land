import SwiftUI
import SwiftData

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0
    @State private var selectedCharacterSex: AvatarSex?
    @State private var finishingEditor = false
    @AppStorage(StorageKeys.readingStrictMode) private var strictMode = false
    @Environment(\.modelContext) private var context
    @Query private var profiles: [AvatarProfile]
    @AppStorage(StorageKeys.playerName) private var playerName = ""
    @State private var nameError: String?

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                OnboardingNameView(name: $playerName, errorMessage: nameError)
                    .padding(.horizontal, 24)
                    .tag(0)

                OnboardingModeView(isStrict: $strictMode) {
                    OnboardingModeChoice.save(isStrict: strictMode)
                    withAnimation { page = 2 }
                }
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

            if page != 1 {
                Button(page < pageCount - 1 ? "Next" : "Begin the journey") {
                    if page == 0 {
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
                    finishingEditor = true
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
        guard OnboardingAvatarSelection.shouldResetAfterEditorDismissal(isFinishing: finishingEditor) else {
            finishingEditor = false
            return
        }
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
