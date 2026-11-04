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
        #if DEBUG
        .task { DebugSeed.apply(to: context) }
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
