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
            #if DEBUG
            DebugSeed.apply(to: context)
            #endif
            AvatarProfile.ensure(in: context)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
