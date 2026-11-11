import SwiftUI
import SwiftData

@main struct MyApp: App {
    /// The store opens through the migration plan (AppSchema.swift), so saved progress always carries over.
    private let container: ModelContainer = {
        do { return try AppSchema.container() } catch {
            fatalError("Could not open the saved progress: \(error)")
        }
    }()

    #if DEBUG
    @AppStorage("debug.fpsOverlay") private var showsFPS = false
    #endif

    init() {
        #if DEBUG
        // "-perfLog" prints frame rate and the island's main-thread time once a second.
        PerfProbe.setEnabled(UserDefaults.standard.bool(forKey: "debug.fpsOverlay"))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if DEBUG
                .onChange(of: showsFPS) { _, enabled in PerfProbe.setEnabled(enabled) }
                #endif
        }
        .modelContainer(container)
    }
}
