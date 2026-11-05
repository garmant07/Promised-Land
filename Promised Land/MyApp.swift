import SwiftUI
import SwiftData

@main struct MyApp: App {
    /// The store opens through the migration plan (AppSchema.swift), so saved progress always carries over.
    private let container: ModelContainer = {
        do { return try AppSchema.container() } catch {
            fatalError("Could not open the saved progress: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
