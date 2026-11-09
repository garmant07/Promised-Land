import SwiftUI
import QuartzCore

/// When the clouds part: once the island has loaded (the pictures around the first view are made)
/// and then run smoothly for a moment; never before a short minimum (so a quick load doesn't flash)
/// and never later than a maximum (so they can't get stuck). Pure, so it's testable.
struct LoadingGate: Equatable {
    /// Seconds the clouds always show for.
    static let minimum: Double = 0.9
    /// Seconds after which they part regardless.
    static let maximum: Double = 8
    /// Frames in a row at least this quick (seconds) count as running smoothly.
    static let smoothFrame: Double = 1.0 / 40
    static let smoothFramesNeeded = 12

    let started: Double
    private(set) var loaded = false
    private(set) var smoothFrames = 0

    init(started: Double) { self.started = started }

    /// The island says it's ready (pictures around the first view made, everything placed).
    mutating func markLoaded() { loaded = true }

    /// A frame went by, taking this long. Only counts once loaded; a slow frame starts the count again.
    mutating func frame(duration: Double) {
        guard loaded else { return }
        smoothFrames = duration <= Self.smoothFrame ? smoothFrames + 1 : 0
    }

    func shouldPart(at now: Double) -> Bool {
        let shown = now - started
        if shown >= Self.maximum { return true }
        return loaded && smoothFrames >= Self.smoothFramesNeeded && shown >= Self.minimum
    }
}

/// Soft pastel clouds over the whole screen while an island loads. They drift gently until it's ready,
/// then part and drift off the sides (about 1.2 s), and `onCleared` is called. With Reduce Motion
/// they fade instead.
struct CloudCover: View {
    /// The island has loaded (see `LoadingGate`).
    let loaded: Bool
    var onCleared: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gate = LoadingGate(started: CACurrentMediaTime())
    @State private var partStart: Double?

    static let partDuration: Double = 1.2

    var body: some View {
        TimelineView(.animation) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let p = partStart.map { min(1, (CACurrentMediaTime() - $0) / Self.partDuration) } ?? 0
            let eased = p * p * (3 - 2 * p)
            Canvas { c, size in
                // The sky behind them thins out first, so the island shows between the clouds.
                let sky = Gradient(colors: [Color(hex: "#DCEBF2"), Color(hex: "#F6EEDF")])
                var g = c
                g.opacity = reduceMotion ? 1 - eased : max(0, 1 - eased * 1.8)
                g.fill(Path(CGRect(origin: .zero, size: size)),
                       with: .linearGradient(sky, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                for cloud in Self.clouds {
                    var cg = c
                    // Left-hand clouds go left, right-hand ones right; each drifts a little meanwhile.
                    let away = (cloud.x < 0.5 ? -1.0 : 1.0) * Double(size.width) * (0.75 + cloud.depth * 0.5) * eased
                    let drift = sin(now * 0.25 * cloud.speed + cloud.phase) * 14
                    cg.translateBy(x: CGFloat(Double(cloud.x) * Double(size.width) + drift + (reduceMotion ? 0 : away)),
                                   y: cloud.y * size.height)
                    cg.opacity = reduceMotion ? 1 - eased : 1
                    let scale = cloud.scale * size.width / 390
                    if let picture = Self.picture(of: cloud, scale: scale) {
                        // Drawn once (with its soft blur) and then only moved.
                        let r = Self.pictureRect(scale: scale)
                        cg.draw(Image(decorative: picture, scale: Self.pictureScale), in: r)
                    } else {
                        Self.drawCloud(&cg, scale: scale, tint: cloud.tint)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(partStart == nil)
        .accessibilityElement()
        .accessibilityLabel("Loading your island")
        .onChange(of: loaded, initial: true) { _, isLoaded in if isLoaded { gate.markLoaded() } }
        .task {
            // Count smooth frames once loaded, part when ready, clear when they've drifted off.
            var last = CACurrentMediaTime()
            while !Task.isCancelled {
                await FrameTicker.shared.nextFrame()
                let now = CACurrentMediaTime()
                gate.frame(duration: now - last)
                last = now
                if partStart == nil, gate.shouldPart(at: now) { partStart = now }
                if let partStart, now - partStart >= Self.partDuration { onCleared(); return }
            }
        }
    }

    // MARK: Drawing

    struct Cloud {
        let x: Double, y: CGFloat, scale: CGFloat
        let depth: Double, speed: Double, phase: Double
        let tint: Color
    }

    /// Big soft clouds, overlapping enough to cover a phone screen: mostly white and cream, the
    /// island's pastels only as a faint tint.
    static let clouds: [Cloud] = {
        let tints = [Color(hex: "#FFFFFF"), Color(hex: "#FFFCF6"), Color(hex: "#FBF7FC"), Color(hex: "#FFFFFF"), Color(hex: "#FFF8F2")]
        var out: [Cloud] = []
        let rows = 5
        for row in 0..<rows {
            for col in 0..<2 {
                let k = row * 2 + col
                let x = (Double(col) + 0.5) / 2 + (row % 2 == 0 ? -0.12 : 0.12)
                let y = (CGFloat(row) + 0.5) / CGFloat(rows)
                out.append(Cloud(x: x, y: y, scale: 1.55 + CGFloat((k * 7) % 4) * 0.1,
                                 depth: Double((k * 3) % 4) / 4, speed: 0.5 + Double(k % 3) * 0.2,
                                 phase: Double(k) * 1.7, tint: tints[k % tints.count]))
            }
        }
        // Back to front by size, so the biggest are behind.
        return out.sorted { $0.scale > $1.scale }
    }()

    // MARK: Pictures

    /// Each cloud drawn once into a picture (the blur is the costly part), by tint and size.
    private static var pictures: [String: CGImage] = [:]
    static let pictureScale: CGFloat = 2

    /// The area a cloud's picture covers, around its centre (room for the blur and shade).
    static func pictureRect(scale s: CGFloat) -> CGRect { CGRect(x: -160 * s, y: -110 * s, width: 320 * s, height: 220 * s) }

    static func picture(of cloud: Cloud, scale s: CGFloat) -> CGImage? {
        let key = "\(cloud.tint.description)|\(Int(s * 100))"
        if let known = pictures[key] { return known }
        let r = pictureRect(scale: s)
        let renderer = ImageRenderer(content: Canvas { c, _ in
            c.translateBy(x: -r.minX, y: -r.minY)
            drawCloud(&c, scale: s, tint: cloud.tint)
        }.frame(width: r.width, height: r.height))
        renderer.scale = pictureScale
        let image = renderer.cgImage
        if let image { pictures[key] = image }
        return image
    }

    /// One soft cloud, centred on the origin: puffs on a flat-ish base, a faint lavender shade
    /// underneath, all slightly blurred so the edges are soft.
    static func drawCloud(_ c: inout GraphicsContext, scale s: CGFloat, tint: Color) {
        let puffs: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
            (-78, 14, 40), (-38, -8, 54), (12, -24, 62), (62, -8, 50), (98, 12, 38), (-10, 18, 50), (44, 20, 44),
        ]
        var shade = c
        shade.addFilter(.blur(radius: 9 * s))
        for p in puffs {
            shade.fill(Path(ellipseIn: CGRect(x: (p.x - p.r) * s, y: (p.y - p.r + 12) * s, width: 2 * p.r * s, height: 2 * p.r * s)),
                       with: .color(Color(hex: "#D9CCE6").opacity(0.45)))
        }
        var body = c
        body.addFilter(.blur(radius: 1.5 * s))
        for p in puffs {
            body.fill(Path(ellipseIn: CGRect(x: (p.x - p.r) * s, y: (p.y - p.r) * s, width: 2 * p.r * s, height: 2 * p.r * s)),
                      with: .color(tint))
        }
    }
}
