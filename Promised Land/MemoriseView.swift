import SwiftUI
import SwiftData

/// Three gentle steps: read the verse, read it with gaps, then rebuild it word by word.
struct MemoriseView: View {
    let place: Place

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private enum Stage { case read, gaps, rebuild, done }

    private struct Chip: Identifiable, Equatable {
        let id: Int
        let word: String
    }

    @State private var stage: Stage = .read
    @State private var revealed: Set<Int> = []
    @State private var placed: [String] = []
    @State private var pool: [Chip] = []
    @State private var wrongChip: Int?

    private var verse: MemoryVerse { place.memoryVerse }
    private var words: [String] { verse.words }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    stageHeader
                    switch stage {
                    case .read: readStage
                    case .gaps: gapsStage
                    case .rebuild: rebuildStage
                    case .done: doneStage
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle(verse.reference)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .frame(minHeight: 44)
                        .tint(Color.primaryBrown)
                }
            }
        }
    }

    // MARK: Stages

    private var stageHeader: some View {
        let titles: [Stage: String] = [.read: "1 · Read it slowly", .gaps: "2 · Fill the gaps in your head",
                                       .rebuild: "3 · Rebuild the verse", .done: "Memorised"]
        return Text(titles[stage] ?? "")
            .font(.serifTitle(.title3))
            .foregroundStyle(Color.bodyText)
    }

    private var readStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            verseCard(verse.text)
            Text("Read it aloud two or three times. When you feel ready, move on.")
                .foregroundStyle(Color.secondaryText)
            Button("I'm ready") { withAnimation { stage = .gaps } }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var gapsStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            FlowLayout(spacing: 6) {
                ForEach(words.indices, id: \.self) { i in
                    let hidden = i % 2 == 1 && !revealed.contains(i)
                    Button {
                        withAnimation { _ = revealed.insert(i) }
                    } label: {
                        Text(words[i])
                            .font(.system(.title3, design: .serif))
                            .foregroundStyle(hidden ? Color.clear : Color.bodyText)
                            .padding(.horizontal, 6)
                            .frame(minHeight: 44)
                            .background(hidden ? Color.sand : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hidden)
                    .accessibilityLabel(hidden ? "Hidden word, tap to reveal" : words[i])
                }
            }
            .cardStyle()
            Text("Say the whole verse, filling in the gaps. Tap a gap if you need a peek.")
                .foregroundStyle(Color.secondaryText)
            Button("Rebuild it") { startRebuild() }
                .buttonStyle(PrimaryButtonStyle())
            Button("Read it again") { withAnimation { revealed = []; stage = .read } }
                .buttonStyle(SoftButtonStyle())
        }
    }

    private var rebuildStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            // The verse so far.
            Text(placed.isEmpty ? "Tap the words in order…" : placed.joined(separator: " "))
                .font(.system(.title3, design: .serif))
                .foregroundStyle(placed.isEmpty ? Color.secondaryText : Color.bodyText)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .cardStyle()

            Text("\(placed.count) of \(words.count) words")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)

            FlowLayout(spacing: 8) {
                ForEach(pool) { chip in
                    Button { tap(chip) } label: {
                        Text(chip.word)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.bodyText)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(wrongChip == chip.id ? Color.terracotta.opacity(0.5) : Color.sand,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .offset(x: wrongChip == chip.id ? 4 : 0)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Start over") { startRebuild() }
                .buttonStyle(SoftButtonStyle())
        }
    }

    private var doneStage: some View {
        VStack(spacing: 18) {
            PlaceTileView(place: place, level: .flourishing, width: 200)
            Text("\(place.name) is flourishing!")
                .font(.serifTitle(.title))
                .foregroundStyle(Color.bodyText)
                .multilineTextAlignment(.center)
            verseCard(verse.text)
            Button("Back to my world") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    private func verseCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.bodyText)
                .lineSpacing(4)
            Text(verse.reference)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
        }
        .cardStyle()
    }

    // MARK: Logic

    private func startRebuild() {
        withAnimation {
            placed = []
            pool = words.enumerated().map { Chip(id: $0.offset, word: $0.element) }.shuffled()
            stage = .rebuild
        }
    }

    private func tap(_ chip: Chip) {
        let expected = words[placed.count]
        // Repeated words (e.g. "I", "the") are interchangeable, so compare text, not identity.
        if chip.word == expected {
            withAnimation(.easeOut(duration: 0.2)) {
                placed.append(chip.word)
                pool.removeAll { $0.id == chip.id }
            }
            if placed.count == words.count {
                context.recordMemorised(place.bookID, reference: verse.reference)
                withAnimation(.easeInOut.delay(0.3)) { stage = .done }
            }
        } else {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.2)) { wrongChip = chip.id }
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation { if wrongChip == chip.id { wrongChip = nil } }
            }
        }
    }
}

// MARK: - Flow layout

/// Wraps its children onto new lines, like words in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
