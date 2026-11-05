import SwiftUI

/// A character whose journey is complete, strolling on the island near their story's buildings.
struct IslandCharacter: Identifiable, Equatable {
    /// The journey's id (also the character's).
    let id: String
    let characterId: String
    let name: String
    let line: String
    let look: Avatar
    /// Grid centre of the plot they walk around, and how far out they walk.
    let home: CGPoint
    let radius: CGFloat

    /// Where they are at a moment: a slow loop around their home, easing and pausing.
    func position(at time: TimeInterval) -> CGPoint {
        let phase = Double(Island.hash(id) % 628) / 100
        let t = time * 0.16 + phase
        let theta = t + 0.6 * sin(t * 0.7)
        return CGPoint(x: home.x + cos(theta) * radius, y: home.y + sin(theta) * radius)
    }

    /// Facing left when moving left on screen (before any mirroring).
    func facingLeft(at time: TimeInterval) -> Bool {
        let a = position(at: time), b = position(at: time + 0.1)
        return (b.x - b.y) < (a.x - a.y)
    }

    /// Characters to show, from the journeys completed, each beside one of their story's plots.
    static func make(_ journeys: [CharacterJourney], island: Island) -> [IslandCharacter] {
        journeys.map { j in
            let plot = j.homeBooks.lazy.compactMap { id in island.plots.first { $0.bookID == id } }.first
            let line = j.reviewed || ContentGate.showsDrafts ? "\u{201C}\(j.unlockLine)\u{201D} (\(j.unlockReference))" : "Finished \(j.name)'s journey."
            return IslandCharacter(id: j.id, characterId: j.characterId, name: j.name, line: line,
                                   look: Avatar(config: AvatarPresets.config(for: j.characterId)),
                                   home: plot?.centre ?? CGPoint(x: 1, y: 1), radius: CGFloat(plot?.size ?? 2) / 2 + 0.25)
        }
    }
}

/// A character's picture: the hand-drawn `char_<id>` art when there is some, otherwise their
/// look drawn by the avatar renderer.
struct CharacterFigure: View {
    let id: String
    let look: Avatar

    var body: some View {
        if ArtAssets.character(id) != nil {
            Image("char_\(id)")
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            AvatarFigure(avatar: look)
        }
    }
}

/// What a character says when tapped, with a link to their journey.
struct SpeechBubble: View {
    let name: String
    let line: String
    /// The content behind the line (for the Draft badge).
    var content: (any ReviewableContent)?
    var onView: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(name).font(.subheadline.weight(.bold)).foregroundStyle(Color.bodyText)
                if let content { DraftBadge(item: content) }
            }
            Text(line)
                .font(.footnote)
                .foregroundStyle(Color.bodyText)
                .fixedSize(horizontal: false, vertical: true)
            Button("View journey", action: onView)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.primaryBrown)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .frame(width: 220, alignment: .leading)
        .background(Color.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottom) {
            Triangle().fill(Color.cream).frame(width: 16, height: 9).offset(y: 8)
        }
        .shadow(color: Color.primaryBrown.opacity(0.15), radius: 8, y: 3)
    }

    private struct Triangle: Shape {
        func path(in r: CGRect) -> Path {
            Path { p in p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); p.closeSubpath() }
        }
    }
}

// MARK: - Unlock celebration

/// Shown once when a journey is completed and its character comes to your island. Scaled to
/// rarity: a soft sparkle for common, a burst for rare, a golden glow for legendary.
struct CharacterUnlockView: View {
    let journey: CharacterJourney
    var onView: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = Date.now
    @State private var revealed = false

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            if journey.rarity == .legendary {
                RadialGradient(colors: [Earthy.gold.opacity(revealed ? 0.45 : 0), .clear], center: .center, startRadius: 10, endRadius: 360)
                    .ignoresSafeArea()
            }
            if !reduceMotion {
                Confetti(start: appeared, count: journey.rarity == .common ? 18 : journey.rarity == .rare ? 70 : 110,
                         golden: journey.rarity == .legendary)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            VStack(spacing: 14) {
                Spacer(minLength: 10)
                RarityBadge(rarity: journey.rarity).scaleEffect(1.4)
                CharacterFigure(id: journey.characterId, look: Avatar(config: AvatarPresets.config(for: journey.characterId)))
                    .frame(width: 170, height: 220)
                    .scaleEffect(revealed ? 1 : 0.6)
                    .opacity(revealed ? 1 : 0)
                Text("\(journey.name) has come to your island")
                    .font(.serifTitle(.title))
                    .foregroundStyle(Color.bodyText)
                    .multilineTextAlignment(.center)
                if journey.reviewed || ContentGate.showsDrafts {
                    Text("\u{201C}\(journey.unlockLine)\u{201D}")
                        .font(.body).italic()
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 6) {
                        Text(journey.unlockReference).font(.footnote).foregroundStyle(Color.secondaryText)
                        DraftBadge(item: journey)
                    }
                }
                Text("You finished \(journey.title.lowercased().replacingOccurrences(of: journey.name.lowercased(), with: journey.name)).")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                Spacer(minLength: 10)
                Button("View journey") { dismiss(); onView() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Back to the island") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primaryBrown)
                    .frame(minHeight: 44)
            }
            .padding(24)
        }
        .onAppear {
            // Legendary characters are revealed slowly and reverently.
            withAnimation(.easeOut(duration: reduceMotion ? 0 : journey.rarity == .legendary ? 1.6 : 0.6)) { revealed = true }
        }
    }
}

/// Soft paper confetti drifting down for a few seconds.
private struct Confetti: View {
    let start: Date
    var count = 70
    var golden = false

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { c, size in
                let t = context.date.timeIntervalSince(start)
                guard t < 6 else { return }
                let colours = golden ? [Earthy.gold, Earthy.goldShine, Color.wheat] : [Color.terracotta, Color.lavender, Color.wheat, Color.olive, Earthy.gold]
                for i in 0..<count {
                    let seed = Double(i)
                    let x = (sin(seed * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let speed = 120 + 80 * abs(sin(seed * 3.1))
                    let y = -20 + (t - abs(sin(seed)) * 0.8) * speed
                    guard y > -20, y < size.height + 20 else { continue }
                    let px = abs(x) * size.width + sin(t * 2 + seed) * 18
                    var g = c
                    g.translateBy(x: px, y: y)
                    g.rotate(by: .radians(t * 3 + seed))
                    g.opacity = max(0, min(1, (6 - t) / 1.5))
                    g.fill(Path(roundedRect: CGRect(x: -4, y: -2.5, width: 8, height: 5), cornerRadius: 1.5),
                           with: .color(colours[i % colours.count]))
                }
            }
        }
    }
}
