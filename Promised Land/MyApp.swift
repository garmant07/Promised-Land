import SwiftUI
import SwiftData

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ChapterRead.self, QuizPass.self, VerseMemorised.self])
    }
}
