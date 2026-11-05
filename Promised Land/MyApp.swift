import SwiftUI
import SwiftData

@main struct MyApp: App {
    /// The store opens through the migration plan (AppSchema.swift), so saved progress always carries over.
    private let container: ModelContainer = {
        do { return try AppSchema.container() } catch {
            fatalError("Could not open the saved progress: \(error)")
        }
    }()

    init() {
        #if DEBUG
        // "-perfLog" prints frame rate and the island's main-thread time once a second.
        if PerfProbe.logging { FrameCounter.logger.start() }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
