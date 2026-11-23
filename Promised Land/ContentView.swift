import SwiftUI
import SwiftData

enum ContentViewRouting {
    static func shouldPresentAvatarUpdate(
        hasOnboarded: Bool,
        sex: AvatarSex?,
        finishedOnboardingThisSession: Bool
    ) -> Bool {
        !finishedOnboardingThisSession
            && AvatarUpdateRouting.shouldPresent(hasOnboarded: hasOnboarded, sex: sex)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(StorageKeys.hasOnboarded) private var hasOnboarded = false
    @Query private var profiles: [AvatarProfile]
    @State private var showingAvatarUpdate = false
    @State private var finishedOnboardingThisSession = false

    var body: some View {
        HomeView()
            .tint(Color.primaryBrown)
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 }), onDismiss: {
            decideWhetherToShowAvatarUpdate()
        }) {
            OnboardingView {
                try? context.save()
                finishedOnboardingThisSession = true
                FirstJourneyStore.finishOnboarding()
                hasOnboarded = true
            }
        }
        .fullScreenCover(isPresented: $showingAvatarUpdate) {
            AvatarEditingFlowView { showingAvatarUpdate = false }
        }
        .onAppear {
            _ = FirstJourneyStore.bootstrap(hasOnboarded: hasOnboarded)
            decideWhetherToShowAvatarUpdate()
        }
        .onChange(of: hasOnboarded) { _, _ in decideWhetherToShowAvatarUpdate() }
        .onChange(of: profiles.first?.config.sex) { _, _ in decideWhetherToShowAvatarUpdate() }
        .task {
            AvatarProfile.ensure(in: context)
            IslandMigration.run(context)
            // First run with an API key: find the translations' Bible ids (one request, saved).
            await BibleServices.shared.prepare()
            decideWhetherToShowAvatarUpdate()
        }
    }

    private func decideWhetherToShowAvatarUpdate() {
        guard !showingAvatarUpdate else { return }
        guard ContentViewRouting.shouldPresentAvatarUpdate(
            hasOnboarded: hasOnboarded,
            sex: profiles.first?.config.sex,
            finishedOnboardingThisSession: finishedOnboardingThisSession
        ) else { return }
        showingAvatarUpdate = true
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
