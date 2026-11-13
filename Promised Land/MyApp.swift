import SwiftUI
import SwiftData
import UIKit

@main struct MyApp: App {
    /// The store opens through the migration plan (AppSchema.swift), so saved progress always carries over.
    private let container: ModelContainer = {
        do {
            let container = try AppSchema.container()
            #if DEBUG
            DebugSeed.apply(to: container.mainContext)
            #endif
            // Synchronous: no scene or journal UI exists until every entry is filed.
            try JournalStore.backfill(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not open the saved progress: \(error)")
        }
    }()

    #if DEBUG
    @AppStorage("debug.fpsOverlay") private var showsFPS = false
    #endif

    init() {
        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.bodyText)]
        navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.bodyText)]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = navigationAppearance
        navigationBar.scrollEdgeAppearance = navigationAppearance
        navigationBar.compactAppearance = navigationAppearance
        navigationBar.tintColor = UIColor(Color.primaryBrown)

        #if DEBUG
        // "-perfLog" prints frame rate and the island's main-thread time once a second.
        PerfProbe.setEnabled(UserDefaults.standard.bool(forKey: "debug.fpsOverlay"))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                #if DEBUG
                .onChange(of: showsFPS) { _, enabled in PerfProbe.setEnabled(enabled) }
                #endif
        }
        .modelContainer(container)
    }
}
