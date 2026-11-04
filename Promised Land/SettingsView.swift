import SwiftUI
import SwiftData

/// UserDefaults keys for UI state that isn't reading progress.
enum StorageKeys {
    static let hasOnboarded = "hasOnboarded"
    static let worldCamera = "worldCamera"
    static let celebrated = "celebratedLandmarks"
    static let builtConnections = "builtConnections"
    static let hasOpenedReading = "hasOpenedReading"
    static let gardenSeenChapters = "gardenSeenChapters"
    static let storyObjectsSeen = "storyObjectsSeen"
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKeys.hasOnboarded) private var hasOnboarded = false

    @State private var confirmingReset = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Your journey") {
                        Button("Show the welcome again") {
                            hasOnboarded = false
                            dismiss()
                        }
                        .buttonStyle(SoftButtonStyle())
                        Button("Reset map view") {
                            UserDefaults.standard.removeObject(forKey: StorageKeys.worldCamera)
                            NotificationCenter.default.post(name: .resetWorldCamera, object: nil)
                            message = "The map will return to its starting view."
                        }
                        .buttonStyle(SoftButtonStyle())
                        Button("Reset all progress", role: .destructive) { confirmingReset = true }
                            .buttonStyle(SoftButtonStyle())
                        if let message {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(Color.secondaryText)
                        }
                    }

                    section("About") {
                        Text("Scripture is from the American Standard Version (1901), which is in the public domain. This early version bundles a small sample; the full text will follow.")
                            .foregroundStyle(Color.secondaryText)
                        Text("Everything stays on this device. No account, no internet needed.")
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .frame(minHeight: 44)
                        .tint(Color.primaryBrown)
                }
            }
            .confirmationDialog("Reset all progress?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) { resetProgress() }
            } message: {
                Text("Chapters read, quizzes and memorised verses will be cleared. This can't be undone.")
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
            content()
        }
        .cardStyle()
    }

    private func resetProgress() {
        context.resetAllProgress()
        UserDefaults.standard.removeObject(forKey: StorageKeys.celebrated)
        UserDefaults.standard.removeObject(forKey: StorageKeys.builtConnections)
        UserDefaults.standard.removeObject(forKey: StorageKeys.storyObjectsSeen)
        message = "Progress cleared. A fresh start."
    }
}

extension Notification.Name {
    static let resetWorldCamera = Notification.Name("resetWorldCamera")
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
}
