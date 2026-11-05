import SwiftUI
import SwiftData

// MARK: - Journeys

/// Your journeys and their progress, with the world map one tap away.
struct JourneysSheet: View {
    var openWorldMap: () -> Void

    var body: some View {
        CharacterJourneysView(onOpenWorld: openWorldMap)
    }
}


#Preview("Journeys") {
    JourneysSheet {}.modelContainer(PreviewData.container)
}
