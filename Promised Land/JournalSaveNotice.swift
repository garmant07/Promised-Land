import SwiftUI
import Observation

/// Outlives the reading sheet so a failed note remains visible after the chapter counts.
@MainActor @Observable
final class JournalSaveNotice {
    static let shared = JournalSaveNotice()
    var isPresented = false
}

private struct JournalSaveNoticeModifier: ViewModifier {
    let isVisible: Bool
    @State private var notice = JournalSaveNotice.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if isVisible && notice.isPresented {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your chapter counted, but your note couldn't be saved.")
                        .font(.body)
                        .foregroundStyle(Color.bodyText)
                    Button("OK") { notice.isPresented = false }
                        .tint(Color.primaryBrown)
                }
                .cardStyle()
                .padding(16)
            }
        }
    }
}

extension View {
    func journalSaveNotice(isVisible: Bool) -> some View {
        modifier(JournalSaveNoticeModifier(isVisible: isVisible))
    }
}
