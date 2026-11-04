import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            WorldView()
                .tabItem { Label("World", systemImage: "map.fill") }
            LibraryView()
                .tabItem { Label("Read", systemImage: "book.fill") }
        }
        .tint(Color.primaryBrown)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChapterRead.self, QuizPass.self, VerseMemorised.self], inMemory: true)
}
