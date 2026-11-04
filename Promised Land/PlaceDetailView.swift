import SwiftUI

struct PlaceDetailView: View {
    let place: Place

    @ProgressQuery private var progress: GameProgress
    @State private var showingQuiz = false
    @State private var showingMemorise = false

    private var level: GrowthLevel { progress.level(of: place) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PlaceTileView(place: place, level: level, width: 240)
                    .padding(.top, 8)
                    .animation(.spring(duration: 0.5), value: level)

                VStack(spacing: 6) {
                    Text(place.name)
                        .font(.serifTitle(.largeTitle))
                        .foregroundStyle(Color.bodyText)
                        .multilineTextAlignment(.center)
                    Text(place.blurb)
                        .font(.body)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                }

                GrowthSteps(level: level)

                nextStep
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .themedScreen()
        .navigationTitle(place.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingQuiz) { QuizView(place: place) }
        .sheet(isPresented: $showingMemorise) { MemoriseView(place: place) }
    }

    @ViewBuilder
    private var nextStep: some View {
        if let book = place.book {
            VStack(alignment: .leading, spacing: 12) {
                switch level {
                case .locked:
                    stepTitle("Unlock this place")
                    Text("Read every chapter of \(book.name). You've read \(progress.chaptersRead(in: book)) of \(book.chapters.count).")
                        .foregroundStyle(Color.secondaryText)
                    NavigationLink(value: book) {
                        Text("Read \(book.name)")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                case .unlocked:
                    stepTitle("Help it grow")
                    Text("Pass a short quiz on \(book.name) to reach Growing.")
                        .foregroundStyle(Color.secondaryText)
                    Button("Take the quiz") { showingQuiz = true }
                        .buttonStyle(PrimaryButtonStyle())
                case .growing:
                    stepTitle("Make it flourish")
                    Text("Memorise \(place.memoryVerse.reference) to reach Flourishing.")
                        .foregroundStyle(Color.secondaryText)
                    Button("Memorise the verse") { showingMemorise = true }
                        .buttonStyle(PrimaryButtonStyle())
                case .flourishing:
                    stepTitle("Flourishing")
                    Text("\u{201C}\(place.memoryVerse.text)\u{201D}")
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(Color.bodyText)
                    Text(place.memoryVerse.reference)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }
                if level > .locked {
                    NavigationLink(value: book) {
                        Text("Revisit \(book.name)")
                    }
                    .buttonStyle(SoftButtonStyle())
                }
            }
            .cardStyle()
        }
    }

    private func stepTitle(_ text: String) -> some View {
        Text(text)
            .font(.serifTitle(.title3))
            .foregroundStyle(Color.bodyText)
    }
}

struct GrowthSteps: View {
    let level: GrowthLevel

    private let steps: [(GrowthLevel, String, String)] = [
        (.unlocked, "Unlocked", "book.closed.fill"),
        (.growing, "Growing", "leaf.fill"),
        (.flourishing, "Flourishing", "sparkles"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(steps, id: \.1) { step in
                let reached = level >= step.0
                VStack(spacing: 6) {
                    Image(systemName: step.2)
                        .font(.title3)
                        .foregroundStyle(reached ? Color.onPrimary : Color.secondaryText.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(reached ? Color.olive : Color.sand, in: Circle())
                    Text(step.1)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(reached ? Color.bodyText : Color.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityValue(reached ? "Reached" : "Not yet")
            }
        }
        .padding(.vertical, 12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
