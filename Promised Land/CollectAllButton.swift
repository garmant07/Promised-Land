import SwiftUI
import AVFoundation

/// One "Collect all": what was collected from which Places (the island flies the on-screen ones
/// into the basket button).
struct CollectFlight: Equatable {
    let id: Int
    let entries: [CollectAll.Entry]
}

/// The floating basket that collects every Place's produce at once. It only shows while something
/// is waiting; the badge says how much.
struct CollectAllButton: View {
    let total: Int
    /// Bumped when the produce lands, for a little bounce.
    let bounce: Int
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var squash = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "basket.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.primaryBrown)
                .frame(width: 54, height: 54)
                .background(Color.cream.opacity(0.97), in: Circle())
                .overlay(Circle().strokeBorder(Color.wheat.opacity(0.7), lineWidth: 1.5))
                .shadow(color: Color.primaryBrown.opacity(0.16), radius: 10, y: 3)
                .overlay(alignment: .topTrailing) {
                    Text("\(total)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(Color.terracotta, in: Capsule())
                        .offset(x: 4, y: -4)
                        .contentTransition(.numericText())
                }
                .scaleEffect(squash ? 1.14 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CollectAll.accessibilityLabel(total: total))
        .accessibilityHint("Collects the produce from every Place on the island")
        .onChange(of: bounce) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { squash = true }
            Task {
                try? await Task.sleep(for: .milliseconds(170))
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { squash = false }
            }
        }
    }
}

/// The summary after collecting: "+3 fish, +2 bread, +1 grapes".
struct CollectSummaryToast: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "basket.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.olive)
            .lineLimit(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.cream.opacity(0.97), in: Capsule())
            .shadow(color: Color.primaryBrown.opacity(0.12), radius: 8, y: 3)
            .accessibilityElement(children: .combine)
    }
}

// MARK: - Flight

/// Produce flying from the baskets on screen into the button: at most `maxSprites`, the rest of
/// the on-screen baskets flying together as one bundle with a "+N". Pure, so it's testable.
enum CollectFlightPlan {
    static let maxSprites = 12
    static let duration: Double = 0.75
    static let stagger: Double = 0.05

    struct Sprite: Equatable {
        /// Where it starts, in grid units (it follows the camera if you pan mid-flight).
        let grid: CGPoint
        let kind: ProduceKind
        /// How many it carries (more than the basket's own when it's the bundle).
        let count: Int
        let delay: Double
    }

    /// - Parameter onScreen: the baskets on screen (grid point, kind, count), nearest the button first.
    static func sprites(_ onScreen: [(grid: CGPoint, kind: ProduceKind, count: Int)]) -> [Sprite] {
        guard !onScreen.isEmpty else { return [] }
        let solo = onScreen.count <= maxSprites ? onScreen : Array(onScreen.prefix(maxSprites - 1))
        var out = solo.enumerated().map { i, b in Sprite(grid: b.grid, kind: b.kind, count: b.count, delay: Double(i) * stagger) }
        if onScreen.count > maxSprites {
            let rest = onScreen.dropFirst(maxSprites - 1)
            let n = CGFloat(rest.count)
            let centre = CGPoint(x: rest.map(\.grid.x).reduce(0, +) / n, y: rest.map(\.grid.y).reduce(0, +) / n)
            out.append(Sprite(grid: centre, kind: rest.first!.kind, count: rest.map(\.count).reduce(0, +),
                              delay: Double(maxSprites - 1) * stagger))
        }
        return out
    }

    /// Seconds until the last one lands.
    static func length(_ sprites: [Sprite]) -> Double { (sprites.map(\.delay).max() ?? 0) + (sprites.isEmpty ? 0 : duration) }

    /// A point along a gentle arc from `a` to `b` (t 0…1, eased).
    static func point(from a: CGPoint, to b: CGPoint, t: Double) -> CGPoint {
        let e = CGFloat(t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2)
        let lift = min(160, max(60, hypot(b.x - a.x, b.y - a.y) * 0.35))
        let c = CGPoint(x: (a.x + b.x) / 2 + (a.x < b.x ? -30 : 30), y: min(a.y, b.y) - lift)
        let q = 1 - e
        return CGPoint(x: q * q * a.x + 2 * q * e * c.x + e * e * b.x, y: q * q * a.y + 2 * q * e * c.y + e * e * b.y)
    }

    /// Draws the sprites in flight. `target` is the button's centre in the canvas.
    static func draw(_ c: inout GraphicsContext, sprites: [Sprite], elapsed: Double, layout: IslandLayout, target: CGPoint) -> Int {
        var drawn = 0
        for s in sprites {
            let t = (elapsed - s.delay) / duration
            guard t >= 0, t < 1 else { continue }
            let start = IslandLife.basketPoint(layout.point(s.grid.x, s.grid.y), u: layout.u, time: 0)
            let p = point(from: start, to: target, t: t)
            let r: CGFloat = 13 * (1 - 0.35 * CGFloat(t))
            c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(Color.cream.opacity(0.96)))
            var symbol = c.resolve(Image(systemName: s.kind.symbol))
            symbol.shading = .color(IslandLife.colour(s.kind).mix(with: Color.primaryBrown, by: 0.25))
            c.draw(symbol, in: CGRect(x: p.x - r * 0.6, y: p.y - r * 0.6, width: r * 1.2, height: r * 1.2))
            if s.count > 1 {
                let b = CGPoint(x: p.x + r * 0.8, y: p.y - r * 0.8)
                c.fill(Path(ellipseIn: CGRect(x: b.x - 7, y: b.y - 7, width: 14, height: 14)), with: .color(Color.terracotta))
                c.draw(Text("\(s.count)").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.white), at: b)
            }
            drawn += 1
        }
        return drawn
    }
}

// MARK: - Sound

/// A soft whoosh, made on the device (no sound files): a short burst of filtered noise that rises
/// and falls. It plays with the "ambient" session, so the silent switch mutes it.
@MainActor
enum SoftSound {
    private static var engine: AVAudioEngine?
    private static var player: AVAudioPlayerNode?
    private static var buffer: AVAudioPCMBuffer?

    static func whoosh() {
        do {
            if engine == nil {
                try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
                let engine = AVAudioEngine()
                let player = AVAudioPlayerNode()
                engine.attach(player)
                let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
                engine.connect(player, to: engine.mainMixerNode, format: format)
                self.engine = engine
                self.player = player
                self.buffer = makeWhoosh(format: format)
            }
            guard let engine, let player, let buffer else { return }
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
        } catch {
            // No sound is fine: the flight and the haptic still say it worked.
        }
    }

    private static func makeWhoosh(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let seconds = 0.55
        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var low: Float = 0, seed: UInt32 = 12345
        for i in 0..<Int(frames) {
            let t = Float(i) / Float(frames)
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let noise = Float(Int32(bitPattern: seed)) / Float(Int32.max)
            // A low-pass that opens and closes, so it sweeps like air.
            let k = 0.02 + 0.16 * sin(Float.pi * t)
            low += k * (noise - low)
            let envelope = pow(sin(Float.pi * t), 2)
            data[i] = low * envelope * 0.55
        }
        return buffer
    }
}
