import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(StorageKeys.hasOnboarded) private var hasOnboarded = false

    var body: some View {
        HomeView()
            .tint(Color.primaryBrown)
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })) {
            OnboardingView { hasOnboarded = true }
        }
        .task {
            AvatarProfile.ensure(in: context)
            IslandMigration.run(context)
            // First run with an API key: find the translations' Bible ids (one request, saved).
            await BibleServices.shared.prepare()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
