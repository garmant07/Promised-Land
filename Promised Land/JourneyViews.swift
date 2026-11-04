import SwiftUI
import SwiftData

/// A journey's route: which stops are lit, and a way to read each one.
struct JourneyCard: View {
    let journey: Journey

    @ProgressQuery private var progress: GameProgress
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let complete = progress.isComplete(journey)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Text(journey.name)
                            .font(.serifTitle(.title2))
                            .foregroundStyle(Color.bodyText)
                        DraftBadge(item: journey)
                    }
                    Text(journey.summary)
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(Color.secondaryText)

                    if complete {
                        JourneyBadge(journey: journey, earned: true)
                            .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(journey.stops.enumerated()), id: \.offset) { index, stop in
                            let lit = progress.isLit(stop)
                            NavigationLink(value: ChapterRef(bookID: stop.bookID, chapter: stop.chapter)) {
                                HStack(spacing: 12) {
                                    Image(systemName: lit ? "largecircle.fill.circle" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(lit ? Color.terracotta : Color.lavender)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stop.name).font(.headline).foregroundStyle(Color.bodyText)
                                        Text("\(stop.chapterLabel) · \(stop.reference)")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.secondaryText)
                                    }
                                    Spacer()
                                    Text(lit ? "Read" : "Read it")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(lit ? Color.olive : Color.primaryBrown)
                                }
                                .frame(minHeight: 56)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if index < journey.stops.count - 1 {
                                Rectangle()
                                    .fill(Color.lavender.opacity(0.5))
                                    .frame(width: 2, height: 14)
                                    .padding(.leading, 11)
                            }
                        }
                    }
                    .cardStyle()

                    Text("\(progress.litCount(journey)) of \(journey.stops.count) stops lit. Reading a stop's chapter lights it, and your character walks the route.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(journey.reference) · Source: \(journey.source)")
                        if ContentGate.showsDrafts, !journey.note.isEmpty { Text("Reviewer note: \(journey.note)") }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Journey")
            .navigationBarTitleDisplayMode(.inline)
            .readingDestinations()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
            }
        }
    }
}

/// A journey badge: a seal with the journey's initial.
struct JourneyBadge: View {
    let journey: Journey
    let earned: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Image(systemName: "seal.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(earned ? Color.wheat : Color.sand)
                Image(systemName: "figure.walk")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(earned ? Color.primaryBrown : Color.secondaryText.opacity(0.4))
            }
            Text(journey.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(earned ? Color.bodyText : Color.secondaryText)
                .multilineTextAlignment(.center)
                .frame(width: 96)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(journey.name) badge, \(earned ? "earned" : "not yet earned")")
    }
}

#Preview {
    JourneyCard(journey: JourneyData.all[0])
        .modelContainer(PreviewData.container)
}
