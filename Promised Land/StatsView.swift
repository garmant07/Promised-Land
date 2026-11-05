import SwiftUI
import SwiftData

// MARK: - Reading history

struct StatsView: View {
    @ProgressQuery private var progress: GameProgress
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Whole Bible")
                            .font(.serifTitle(.title3))
                            .foregroundStyle(Color.bodyText)
                        Text("\(Int((progress.overallFraction * 100).rounded(.down)))%")
                            .font(.system(size: 44, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.primaryBrown)
                        ProgressView(value: progress.overallFraction)
                            .tint(Color.olive)
                        Text("\(progress.totalChaptersRead) of \(progress.totalChapters) chapters read at least once")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                    }
                    .cardStyle()

                    HStack(spacing: 12) {
                        tile("\(progress.chaptersReadThisYear)", "chapters read this year")
                        tile("\(progress.rereads)", progress.rereads == 1 ? "reread" : "rereads")
                    }
                    HStack(spacing: 12) {
                        tile("\(progress.totalReadsThisYear)", "reads this year")
                        tile("\(progress.streak)", progress.streak == 1 ? "day streak" : "day streak")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Most-read books")
                            .font(.serifTitle(.title3))
                            .foregroundStyle(Color.bodyText)
                        let top = Array(progress.mostReadBooks.prefix(5))
                        if top.isEmpty {
                            Text("Nothing read yet. Your first chapter will show up here.")
                                .foregroundStyle(Color.secondaryText)
                        }
                        ForEach(top, id: \.book.id) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.book.name).font(.headline).foregroundStyle(Color.bodyText)
                                    Spacer()
                                    Text("\(item.reads) \(item.reads == 1 ? "read" : "reads")")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(Color.secondaryText)
                                }
                                ProgressView(value: Double(item.reads), total: Double(max(1, top.first?.reads ?? 1)))
                                    .tint(Color.terracotta)
                            }
                        }
                    }
                    .cardStyle()
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Reading history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
            }
        }
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title, design: .serif).weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.bodyText)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
        }
        .cardStyle()
    }
}

#Preview("Stats") {
    StatsView()
        .modelContainer(PreviewData.container)
}
