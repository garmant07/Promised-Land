import SwiftUI

/// An unlocked Bible character on the island: who they are and where they stroll.
struct IslandCharacter: Identifiable, Equatable {
    let id: String
    let name: String
    let line: String
    let story: ChapterRef
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

    /// Characters to show, from those unlocked, each beside one of their books' plots.
    static func make(_ unlocked: [BibleCharacter], island: Island) -> [IslandCharacter] {
        unlocked.map { c in
            let plot = ([c.homeBook] + c.books).lazy.compactMap { id in island.plots.first { $0.bookID == id } }.first
            let home = plot?.centre ?? CGPoint(x: 1, y: 1)
            return IslandCharacter(id: c.id, name: c.name, line: c.line, story: ChapterRef(bookID: c.storyBook, chapter: c.storyChapter),
                                   look: c.look, home: home, radius: CGFloat(plot?.size ?? 2) / 2 + 0.25)
        }
    }
}

/// A character's picture: the hand-drawn `char_<id>` art when there is some, otherwise the
/// code-drawn chibi figure in their look.
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

/// What a character says when tapped, with a link to their story.
struct SpeechBubble: View {
    let name: String
    let line: String
    /// The content behind the line (for the Draft badge).
    var content: (any ReviewableContent)?
    var onRead: () -> Void

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
            Button("Read their story", action: onRead)
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

/// Shown once when a character first comes to your island.
struct CharacterUnlockView: View {
    let character: BibleCharacter
    var onRead: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = Date.now

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            if !reduceMotion { Confetti(start: appeared).ignoresSafeArea().allowsHitTesting(false) }
            VStack(spacing: 14) {
                Spacer(minLength: 10)
                Text(character.rarity.title.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(rarityColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(rarityColor.opacity(0.14), in: Capsule())
                CharacterFigure(id: character.id, look: character.look)
                    .frame(width: 170, height: 220)
                Text("\(character.name) has come to your island")
                    .font(.serifTitle(.title))
                    .foregroundStyle(Color.bodyText)
                    .multilineTextAlignment(.center)
                Text(character.line)
                    .font(.body)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                HStack(spacing: 6) {
                    Text(character.reference).font(.footnote).foregroundStyle(Color.secondaryText)
                    DraftBadge(item: character)
                }
                Text(character.unlockText + ".")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 10)
                Button("Read their story") { dismiss(); onRead() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Back to the island") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primaryBrown)
                    .frame(minHeight: 44)
            }
            .padding(24)
        }
    }

    private var rarityColor: Color {
        switch character.rarity {
        case .common: Color.olive
        case .rare: Color(hex: "#7C67A8")
        case .legendary: Color(hex: "#B07A2A")
        }
    }
}

/// Soft paper confetti drifting down for a few seconds.
private struct Confetti: View {
    let start: Date

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { c, size in
                let t = context.date.timeIntervalSince(start)
                guard t < 6 else { return }
                let colours = [Color.terracotta, Color.lavender, Color.wheat, Color.olive, Earthy.gold]
                for i in 0..<70 {
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
