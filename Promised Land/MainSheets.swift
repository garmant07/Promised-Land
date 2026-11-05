import SwiftUI
import SwiftData

// MARK: - Journeys

/// Your journeys and their progress.
struct JourneysSheet: View {
    var body: some View {
        CharacterJourneysView()
    }
}


#Preview("Journeys") {
    JourneysSheet().modelContainer(PreviewData.container)
}
