import SwiftUI
import SwiftData

/// The Journeys sheet: every character journey as a card, shortest first.
struct CharacterJourneysView: View {
    /// Opens the SpriteKit world map (its routes are kept as map decoration).
    var onOpenWorld: (() -> Void)?
    @ProgressQuery private var progress: GameProgress
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("Follow one person's story through the Bible. Finish a journey to welcome them to your island.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                    ForEach(CharacterJourneys.all) { journey in
                        NavigationLink(value: JourneyLink(id: journey.id)) {
                            JourneyCardRow(journey: journey, progress: progress.journeyProgress(journey))
                        }
                        .buttonStyle(.plain)
                    }
                    if let onOpenWorld {
                        Button { onOpenWorld() } label: {
                            Label("Open the world map", systemImage: "map")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SoftButtonStyle())
                        .padding(.top, 6)
                    }
                }
                .padding(16)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .themedScreen()
            .navigationTitle("Journeys")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: JourneyLink.self) { link in
                if let journey = CharacterJourneys.journey(id: link.id) { JourneyMapView(journey: journey) }
            }
            .readingDestinations()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(Color.primaryBrown) }
            }
        }
    }
}

/// Opens a journey's map.
struct JourneyLink: Hashable { let id: String }

/// A journey card: portrait (locked until complete), name, rarity, progress and next stop.
struct JourneyCardRow: View {
    let journey: CharacterJourney
    let progress: JourneyProgress

    var body: some View {
        HStack(spacing: 14) {
            CharacterFigure(id: journey.characterId, look: Avatar(config: AvatarPresets.config(for: journey.characterId)))
                .frame(width: 56, height: 80)
                .saturation(progress.isComplete ? 1 : 0)
                .opacity(progress.isComplete ? 1 : 0.45)
                .overlay(alignment: .bottomTrailing) {
                    if !progress.isComplete {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(Color.secondaryText)
                            .padding(5).background(Color.cream, in: Circle())
                    }
                }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(journey.name).font(.headline).foregroundStyle(Color.bodyText)
                    RarityBadge(rarity: journey.rarity)
                }
                Text(journey.subtitle).font(.footnote).foregroundStyle(Color.secondaryText)
                ProgressView(value: progress.fraction)
                    .tint(progress.isComplete ? Earthy.gold : Color.olive)
                Text(progress.isComplete ? "Complete: \(journey.name) walks your island"
                     : "\(progress.read) of \(progress.required) chapters · Next: \(progress.nextStop?.title ?? "")")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.secondaryText.opacity(0.6))
        }
        .padding(12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct RarityBadge: View {
    let rarity: Rarity

    var body: some View {
        Text(rarity.title.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }

    var color: Color {
        switch rarity {
        case .common: Color.olive
        case .rare: Color(hex: "#7C67A8")
        case .legendary: Color(hex: "#B07A2A")
        }
    }
}

// MARK: - The level map

/// One journey as a winding dotted path of stops: done stops filled and glowing, the next one
/// pulsing, your avatar standing on the latest one done; "Continue" opens the next chapter.
struct JourneyMapView: View {
    let journey: CharacterJourney
    @ProgressQuery private var progress: GameProgress
    @CurrentAvatar private var avatar: Avatar
    @State private var openStop: JourneyStopData?

    private let rowHeight: CGFloat = 118

    var body: some View {
        let p = progress.journeyProgress(journey)
        ScrollView {
            VStack(spacing: 16) {
                header(p)
                path(p)
                if let next = p.nextChapter {
                    NavigationLink(value: next) {
                        Label("Continue: \(BibleCatalog.book(id: next.bookID)?.name ?? next.bookID) \(next.chapter)", systemImage: "book")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                HStack(spacing: 6) {
                    Text(journey.reference).font(.caption).foregroundStyle(Color.secondaryText)
                    DraftBadge(item: journey)
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .themedScreen()
        .navigationTitle(journey.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $openStop) { stop in StopCardView(stop: stop, journey: journey) }
    }

    private func header(_ p: JourneyProgress) -> some View {
        HStack(spacing: 14) {
            CharacterFigure(id: journey.characterId, look: Avatar(config: AvatarPresets.config(for: journey.characterId)))
                .frame(width: 72, height: 100)
                .saturation(p.isComplete ? 1 : 0)
                .opacity(p.isComplete ? 1 : 0.5)
            VStack(alignment: .leading, spacing: 6) {
                Text(journey.title).font(.serifTitle(.title2)).foregroundStyle(Color.bodyText)
                HStack(spacing: 6) {
                    RarityBadge(rarity: journey.rarity)
                    Text("\(p.read) of \(p.required) chapters").font(.footnote).foregroundStyle(Color.secondaryText)
                }
                ProgressView(value: p.fraction).tint(p.isComplete ? Earthy.gold : Color.olive)
            }
        }
        .cardStyle()
    }

    private func path(_ p: JourneyProgress) -> some View {
        GeometryReader { geo in
            let points = journey.stops.indices.map { stopPoint($0, width: geo.size.width) }
            let latestDone = journey.stops.lastIndex { p.completedStops.contains($0.id) }
            ZStack(alignment: .topLeading) {
                Canvas { c, _ in
                    guard points.count > 1 else { return }
                    let route = Path { r in
                        r.move(to: points[0])
                        for i in 1..<points.count {
                            let a = points[i - 1], b = points[i]
                            r.addCurve(to: b, control1: CGPoint(x: a.x, y: (a.y + b.y) / 2), control2: CGPoint(x: b.x, y: (a.y + b.y) / 2))
                        }
                    }
                    c.stroke(route, with: .color(Color.lavender.opacity(0.7)), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 11]))
                }
                ForEach(Array(journey.stops.enumerated()), id: \.element.id) { i, stop in
                    let done = p.completedStops.contains(stop.id)
                    let isNext = p.nextStop?.id == stop.id
                    Button { openStop = stop } label: {
                        StopMarker(index: i + 1, done: done, isNext: isNext)
                    }
                    .buttonStyle(.plain)
                    .position(points[i])
                    .accessibilityLabel("\(stop.title), \(done ? "complete" : isNext ? "next" : "not yet")")
                    Text(stop.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(done || isNext ? Color.bodyText : Color.secondaryText)
                        .multilineTextAlignment(points[i].x < geo.size.width / 2 ? .leading : .trailing)
                        .frame(width: geo.size.width * 0.42, alignment: points[i].x < geo.size.width / 2 ? .leading : .trailing)
                        .position(x: points[i].x < geo.size.width / 2 ? points[i].x + 46 + geo.size.width * 0.21 : points[i].x - 46 - geo.size.width * 0.21,
                                  y: points[i].y)
                        .accessibilityHidden(true)
                }
                if let latestDone {
                    AvatarFigure(avatar: avatar)
                        .frame(width: 34, height: 54)
                        .position(x: points[latestDone].x + 26, y: points[latestDone].y - 30)
                        .accessibilityLabel("You are here")
                }
            }
        }
        .frame(height: CGFloat(journey.stops.count) * rowHeight + 20)
    }

    private func stopPoint(_ i: Int, width: CGFloat) -> CGPoint {
        let left = i % 2 == 0
        return CGPoint(x: width * (left ? 0.22 : 0.78), y: CGFloat(i) * rowHeight + 60)
    }
}

/// A stop on the map: filled and glowing when done, gently pulsing when next.
private struct StopMarker: View {
    let index: Int
    let done: Bool
    let isNext: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            if done { Circle().fill(Earthy.gold.opacity(0.3)).frame(width: 74, height: 74) }
            if isNext {
                Circle().stroke(Color.terracotta.opacity(0.5), lineWidth: 3)
                    .frame(width: 66, height: 66)
                    .scaleEffect(pulse ? 1.15 : 0.95)
                    .opacity(pulse ? 0.3 : 0.9)
            }
            Circle()
                .fill(done ? Color.terracotta : Color.cream)
                .frame(width: 52, height: 52)
                .overlay(Circle().stroke(done ? Color.terracotta : (isNext ? Color.terracotta : Color.lavender), lineWidth: 3))
            Text("\(index)").font(.headline.monospacedDigit()).foregroundStyle(done ? Color.onPrimary : Color.bodyText)
        }
        .frame(width: 80, height: 80)
        .contentShape(Circle())
        .onAppear {
            guard isNext, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// A stop's context card: the place, its chapters (with read counts), what happened there,
/// what it may have looked like, and a Read button.
struct StopCardView: View {
    let stop: JourneyStopData
    let journey: CharacterJourney
    @ProgressQuery private var progress: GameProgress
    @Environment(\.dismiss) private var dismiss

    /// Unreviewed text is shown only in DEBUG (with a Draft badge).
    private var showsText: Bool { stop.reviewed || ContentGate.showsDrafts }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !stop.placeType.isEmpty && showsText {
                            Text(stop.placeType.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(Color.terracotta)
                        }
                        Text(stop.title).font(.serifTitle(.title)).foregroundStyle(Color.bodyText)
                        Text(stop.place).font(.subheadline).foregroundStyle(Color.secondaryText)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chapters").font(.headline).foregroundStyle(Color.bodyText)
                        ForEach(chapters, id: \.self) { ref in
                            let n = progress.readCount(ref.bookID, chapter: ref.chapter)
                            NavigationLink(value: ref) {
                                HStack {
                                    Image(systemName: n > 0 ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(n > 0 ? Color.olive : Color.lavender)
                                    Text("\(BibleCatalog.book(id: ref.bookID)?.name ?? ref.bookID) \(ref.chapter)").foregroundStyle(Color.bodyText)
                                    Spacer()
                                    Text(n == 0 ? "Read" : n == 1 ? "Read once" : "Read \(n) times")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(n == 0 ? Color.primaryBrown : Color.secondaryText)
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cardStyle()
                    if showsText {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(stop.happened).font(.body).foregroundStyle(Color.bodyText)
                            if !stop.lookedLike.isEmpty {
                                Text("What it may have looked like").font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
                                Text(stop.lookedLike).font(.subheadline).italic().foregroundStyle(Color.secondaryText)
                            }
                            if !stop.whyItMatters.isEmpty {
                                Text("Why it matters").font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
                                Text(stop.whyItMatters).font(.subheadline).foregroundStyle(Color.bodyText)
                            }
                            HStack(spacing: 6) {
                                Text(stop.reference).font(.caption).foregroundStyle(Color.secondaryText)
                                DraftBadge(item: stop)
                            }
                        }
                        .cardStyle()
                    } else {
                        Text("Read these chapters to light this stop on \(journey.name)'s journey.")
                            .font(.subheadline).foregroundStyle(Color.secondaryText)
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationBarTitleDisplayMode(.inline)
            .readingDestinations()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(Color.primaryBrown) }
            }
        }
    }

    private var chapters: [ChapterRef] {
        var out: [ChapterRef] = []
        for span in stop.spans {
            for ch in span.chapters where out.count < 60 { out.append(ChapterRef(bookID: span.bookID, chapter: ch)) }
        }
        return out
    }
}

#Preview("Journeys") {
    CharacterJourneysView(onOpenWorld: {})
        .modelContainer(PreviewData.container)
}

#Preview("Ruth's map") {
    NavigationStack { JourneyMapView(journey: CharacterJourneys.all[0]) }
        .modelContainer(PreviewData.container)
}
