import SwiftUI
import SwiftData

/// A journey's route: which stops are lit, and a way to read each one.
struct JourneyCard: View {
    let journey: Journey

    @ProgressQuery private var progress: GameProgress
    @Environment(\.dismiss) private var dismiss
    /// The stop whose context card is open.
    @State private var expanded: Int?

    /// A stop: tap to open its context card (what kind of place, what happened, what it may
    /// have looked like), with a link to read its chapter.
    private func stopRow(_ stop: JourneyStop, index: Int) -> some View {
        let lit = progress.isLit(stop)
        let open = expanded == index
        return VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { expanded = open ? nil : index } } label: {
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
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                }
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(open ? "Hides the context card" : "Shows what happened here")
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    if !stop.place.isEmpty {
                        Text(stop.place.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(Color.terracotta)
                    }
                    if !stop.happened.isEmpty {
                        Text(stop.happened).font(.subheadline).foregroundStyle(Color.bodyText)
                    }
                    if !stop.lookedLike.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("What it may have looked like").font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
                            Text(stop.lookedLike).font(.subheadline).italic().foregroundStyle(Color.secondaryText)
                        }
                    }
                    NavigationLink(value: ChapterRef(bookID: stop.bookID, chapter: stop.chapter)) {
                        Text(lit ? "Read \(stop.chapterLabel) again" : "Read \(stop.chapterLabel)")
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                .padding(12)
                .background(Color.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.leading, 36)
            }
        }
    }

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
                            stopRow(stop, index: index)
                            if index < journey.stops.count - 1 {
                                Rectangle()
                                    .fill(Color.lavender.opacity(0.5))
                                    .frame(width: 2, height: 14)
                                    .padding(.leading, 11)
                            }
                        }
                    }
                    .cardStyle()

                    if let reward = JourneyData.reward(journey) {
                        Label(complete ? "\(reward.name) has come to your island." : "Complete this journey to welcome \(reward.name) to your island.",
                              systemImage: "person.fill.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.terracotta)
                    }

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
