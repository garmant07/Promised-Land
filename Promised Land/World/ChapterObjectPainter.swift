import CoreGraphics
import Foundation

/// What to draw for a story object: its kind, how deep rereading has taken it (1...5), and its variant.
nonisolated struct ChapterObjectLook: Hashable, Sendable {
    let kind: ChapterObjectKind
    let depth: Int
    let variant: Int
    let size: Int
}

nonisolated enum ChapterObjectPainter {
    static func render(_ look: ChapterObjectLook, scale: CGFloat) -> LandmarkImage? {
        LandmarkPainter.canvas(size: look.size, scale: scale) { $0.storyObject(look) }
    }
}

/// Story objects, drawn in footprint units (the diamond spans ±65 × ±32.5, y down).
/// Each extra depth level adds one small, tasteful detail, often taken from the text.
nonisolated extension Painter {
    func storyObject(_ look: ChapterObjectLook) {
        let d = max(1, min(5, look.depth))
        switch look.kind {
        case .edenTrees: edenTrees(d)
        case .ark: ark(d)
        case .ladder: ladder(d)
        case .tower: tower(d)
        case .sinai: sinai(d)
        case .bush: burningBush(d)
        case .plague: plagueMarker(d, variant: look.variant)
        case .redSea: partedSea(d)
        case .fallenWalls: fallenWalls(d)
        case .valley: valleyOfElah(d)
        case .stronghold: stronghold(d)
        case .pasture: pasture(d)
        case .shipAndFish: shipAndFish(d)
        case .lionsDen: lionsDen(d)
        case .boats: boats(d)
        case .weddingHouse: weddingHouse(d)
        case .vineyard: vineyard(d)
        case .hillsideCrowd: hillside(d)
        case .pentecost: pentecost(d)
        case .shipwreck: shipwreck(d)
        }
    }

    // MARK: Small helpers

    private func stroke(_ points: [CGPoint], width: CGFloat, _ color: RGB, alpha: CGFloat = 1) {
        let path = CGMutablePath()
        path.addLines(between: points)
        ctx.addPath(path)
        ctx.setLineWidth(width * u)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(color.cgColor(alpha: alpha))
        ctx.strokePath()
    }

    private func softGlow(_ center: CGPoint, radius: CGFloat, _ color: RGB, alpha: CGFloat = 0.5) {
        let colors = [color.cgColor(alpha: alpha), color.cgColor(alpha: 0)] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) else { return }
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius * u, options: [])
    }

    private func flame(_ base: CGPoint, height h: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: base.x, y: base.y - h * u))
        path.addQuadCurve(to: CGPoint(x: base.x + h * 0.35 * u, y: base.y), control: CGPoint(x: base.x + h * 0.45 * u, y: base.y - h * 0.45 * u))
        path.addQuadCurve(to: CGPoint(x: base.x, y: base.y - h * u), control: CGPoint(x: base.x - h * 0.55 * u, y: base.y - h * 0.3 * u))
        ctx.addPath(path)
        ctx.setFillColor(RGB.terracotta.cgColor)
        ctx.fillPath()
        ellipse(CGPoint(x: base.x, y: base.y - h * 0.3 * u), h * 0.28, h * 0.36, .wheat)
    }

    private func sheep(_ p: CGPoint, _ s: CGFloat = 1) {
        shadow(CGPoint(x: p.x, y: p.y + u), 10 * s)
        for (dx, dy) in [(-2.5, -4.0), (0.5, -5.2), (2.6, -3.8), (0.0, -2.8)] {
            ellipse(CGPoint(x: p.x + dx * u * s, y: p.y + dy * u * s), 5.4 * s, 4.8 * s, .cream)
        }
        ellipse(CGPoint(x: p.x + 5.6 * u * s, y: p.y - 4.8 * u * s), 3.2 * s, 2.8 * s, RGB(hex: "#6A5640"))
    }

    private func person(_ p: CGPoint, robe: RGB, _ s: CGFloat = 1) {
        shadow(CGPoint(x: p.x, y: p.y + 0.6 * u), 6 * s)
        rounded(CGRect(x: p.x - 2.6 * u * s, y: p.y - 9 * u * s, width: 5.2 * u * s, height: 9 * u * s), radius: 2.4 * u * s, robe)
        ellipse(CGPoint(x: p.x, y: p.y - 10.6 * u * s), 4.2 * s, 4.2 * s, RGB(hex: "#E7C3A0"))
    }

    private func waterPatch(width w: CGFloat) {
        diamond(c, width: w * u * 1.08, .shallow)
        diamond(CGPoint(x: c.x, y: c.y + 1.5 * u), width: w * u * 0.88, .water)
    }

    /// Fixed scatter positions inside the footprint, so details never jump around between depths.
    private static let spots: [(CGFloat, CGFloat)] = [
        (-30, 6), (28, 4), (-8, 16), (14, -12), (-40, -2), (38, 12), (-18, -14), (24, 18), (2, 22), (-46, 10),
    ]

    // MARK: Genesis

    private func edenTrees(_ d: Int) {
        // The river that went out of Eden to water the garden.
        stroke([pt(-58, 6), pt(-24, 0), pt(6, 10), pt(36, 2), pt(60, 10)], width: 9, .shallow)
        stroke([pt(-58, 6), pt(-24, 0), pt(6, 10), pt(36, 2), pt(60, 10)], width: 5, .water)
        let trees: [(CGFloat, CGFloat, CGFloat)] = [(-30, -10, 1.1), (18, -14, 1.2), (-4, -22, 1.0), (40, -6, 0.9), (-44, 14, 0.85), (22, 22, 0.9), (-14, 20, 0.8)]
        for t in trees.prefix(2 + d).sorted(by: { $0.1 < $1.1 }) { tree(pt(t.0, t.1), t.2) }
        if d >= 3 {
            for (x, y) in [(-22.0, 6.0), (30.0, 14.0), (2.0, -4.0)] { ellipse(pt(x, y), 5, 4, .terracotta); ellipse(pt(x + 4, y + 2), 4, 3, .lavender) }
        }
        if d >= 5 { // fruit
            for (x, y) in [(-32.0, -38.0), (16.0, -44.0), (-6.0, -48.0), (22.0, -40.0)] { ellipse(pt(x, y), 3.6, 3.6, .terracotta) }
        }
    }

    private func ark(_ d: Int) {
        if d >= 3 { // God sets his bow in the cloud (9:13)
            let colors: [RGB] = [.terracotta, .wheat, .olive, .water, .lavender]
            for (i, color) in colors.enumerated() {
                let r = (70 - CGFloat(i) * 5) * u
                ctx.addArc(center: pt(0, 8), radius: r, startAngle: .pi, endAngle: 0, clockwise: false)
                ctx.setLineWidth(4.5 * u)
                ctx.setStrokeColor(color.cgColor(alpha: 0.45))
                ctx.strokePath()
            }
        }
        waterPatch(width: 120)
        // Hull and house
        fill([pt(-38, -2), pt(38, -2), pt(30, 12), pt(-30, 12)], RGB.trunk)
        fill([pt(-38, -2), pt(38, -2), pt(36, 2), pt(-36, 2)], RGB.trunk.shifted(0.08))
        box(pt(0, -2), w: 32, h: 12, top: RGB.trunk.shifted(0.1), left: RGB.trunk.shifted(0.06), right: RGB.trunk.shifted(-0.04))
        roof(pt(0, -14), w: 32, rise: 9)
        rounded(CGRect(x: c.x - 4 * u, y: c.y - 10 * u, width: 5 * u, height: 4 * u), radius: u, .brown, alpha: 0.3)
        if d >= 2 { // the dove
            ellipse(pt(26, -40), 7, 4, .cream)
            fill([pt(24, -41), pt(30, -48), pt(31, -41)], .cream)
            if d >= 5 { ellipse(pt(32, -40), 3, 1.6, .olive) } // an olive leaf (8:11)
        }
        if d >= 4 { // animals two by two on the shore
            for (x, s) in [(-52.0, 0.8), (-46.0, 0.8)] { sheep(pt(x, 14), s) }
        }
    }

    private func ladder(_ d: Int) {
        softGlow(pt(4, -60), radius: 60, .wheat, alpha: 0.45)
        let rails: [CGFloat] = [-4, 10]
        for x in rails { stroke([pt(x, 6), pt(x + 8, -110)], width: 1.6, .cream, alpha: 0.95) }
        for i in 0..<10 {
            let t = CGFloat(i) / 9
            stroke([pt(-4 + 8 * t, 6 - 116 * t), pt(10 + 8 * t, 6 - 116 * t)], width: 1.2, .cream, alpha: 0.9)
        }
        // Angels ascending and descending (28:12): one more with each reread.
        for i in 0..<d {
            let t = CGFloat(i + 1) / CGFloat(d + 1)
            softGlow(pt(3 + 8 * t, 6 - 116 * t), radius: 7, .cream, alpha: 0.95)
        }
        // Jacob asleep, a stone for a pillow (28:11)
        ellipse(pt(-26, 16), 9, 5, .stoneShade)
        rounded(CGRect(x: c.x - 22 * u, y: c.y + 12 * u, width: 22 * u, height: 7 * u), radius: 3.5 * u, .terracotta)
    }

    private func tower(_ d: Int) {
        var base = pt(0, 10)
        let tiers = 1 + d
        for i in 0..<tiers {
            let w = 70 - CGFloat(i) * 10
            box(base, w: w, h: 12)
            base.y -= 12 * u
        }
        // Unfinished top: scaffold poles
        for x in [-8.0, 8.0] {
            rounded(CGRect(x: base.x + x * u - 0.8 * u, y: base.y - 14 * u, width: 1.6 * u, height: 14 * u), radius: u, .trunk)
        }
    }

    // MARK: Exodus

    private func sinai(_ d: Int) {
        let apex = pt(-2, -62)
        fill([pt(-58, 8), pt(0, 30), apex], .stoneLight)
        fill([pt(0, 30), pt(58, 8), apex], .stoneShade)
        softGlow(pt(-2, -60), radius: 26, .terracotta, alpha: 0.55) // fire on the mount (19:18)
        for (x, y, w) in [(-14.0, -70.0, 26.0), (10.0, -74.0, 30.0), (-2.0, -80.0, 24.0)] { ellipse(pt(x, y), w, 12, .cream, alpha: 0.9) }
        // The camp before the mount (19:2): a tent per reread.
        let camp: [(CGFloat, CGFloat, RGB)] = [(-44, 20, .terracotta), (40, 20, .cream), (-28, 28, .lavender), (24, 28, .wheat)]
        for t in camp.prefix(d - 1) { _ = tent(pt(t.0, t.1), 0.55, t.2) }
    }

    private func burningBush(_ d: Int) {
        softGlow(pt(0, -20), radius: 30, .wheat, alpha: 0.6)
        ellipse(pt(2, -8), 30, 18, RGB.oliveDeep)
        ellipse(pt(-2, -11), 28, 17, .olive)
        flame(pt(-6, -12), height: 18)
        flame(pt(6, -14), height: 22)
        flame(pt(0, -8), height: 14)
        // Moses was keeping the flock (3:1).
        let flock: [(CGFloat, CGFloat)] = [(-36, 14), (32, 12), (-20, 22), (20, 22)]
        for s in flock.prefix(d - 1) { sheep(pt(s.0, s.1), 0.8) }
    }

    private func plagueMarker(_ d: Int, variant: Int) {
        let emblems: [RGB] = [RGB(hex: "#C96B5B"), .olive, RGB(hex: "#6A5640"), .wheat, .stoneShade, .terracotta]
        box(pt(0, 6), w: 30, h: 34)
        roof(pt(0, -28), w: 30, rise: 7, left: .stoneLight, right: .stoneShade)
        ellipse(pt(-8, -12), 10, 12, emblems[variant % emblems.count])
        // Small stones gather round with rereading.
        let stones: [(CGFloat, CGFloat)] = [(-34, 14), (32, 12), (-18, 24), (18, 24)]
        for s in stones.prefix(d - 1) { ellipse(pt(s.0, s.1), 9, 6, .stoneLight); ellipse(pt(s.0 + 2, s.1 + 1), 7, 4, .stoneShade, alpha: 0.6) }
    }

    private func partedSea(_ d: Int) {
        waterPatch(width: 125)
        // Dry ground through the midst of the sea (14:22), with walls of water either side.
        fill([pt(-56, -10), pt(-40, -18), pt(56, 10), pt(40, 18)], .beach)
        fill([pt(-50, -22), pt(-36, -29), pt(-36, -45), pt(-50, -38)], .shallow)
        fill([pt(-36, -29), pt(56, 17), pt(56, 1), pt(-36, -45)], RGB.water.shifted(0.03))
        fill([pt(-56, 2), pt(36, 46), pt(40, 30), pt(-52, -14)], RGB.waterDeep, alpha: 0.6)
        for i in 0..<d { // wave crests
            let x = -40 + CGFloat(i) * 20
            ellipse(pt(x, -36 + x * 0.45), 10, 3, .cream, alpha: 0.75)
        }
        if d >= 3 { // people crossing
            for i in 0..<(d - 2) { person(pt(-20 + CGFloat(i) * 18, -4 + CGFloat(i) * 9), robe: [.terracotta, .lavender, .wheat][i % 3], 0.8) }
        }
    }

    // MARK: Promised Land & Kingdom

    private func fallenWalls(_ d: Int) {
        // Broken wall and rubble
        box(pt(-30, -6), w: 14, h: 16)
        for (x, y) in [(-12.0, 4.0), (0.0, 10.0), (10.0, 0.0), (20.0, 12.0), (-20.0, 14.0), (32.0, 4.0)] { box(pt(x, y), w: 9, h: 5) }
        // Seven trumpets of rams' horns (6:4): more with each reread.
        let horns = min(7, d + 2)
        for i in 0..<horns {
            let p = pt(-44 + CGFloat(i) * 14, 24 - CGFloat(i % 2) * 6)
            let path = CGMutablePath()
            path.move(to: p)
            path.addQuadCurve(to: CGPoint(x: p.x + 9 * u, y: p.y - 6 * u), control: CGPoint(x: p.x + 2 * u, y: p.y - 8 * u))
            ctx.addPath(path)
            ctx.setLineWidth(2.6 * u)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(RGB.wheat.cgColor)
            ctx.strokePath()
        }
    }

    private func valleyOfElah(_ d: Int) {
        fill([pt(-62, 0), pt(-30, 16), pt(-20, -10), pt(-44, -20)], .olive)
        fill([pt(-30, 16), pt(-20, -10), pt(-34, -4)], RGB.oliveDeep)
        fill([pt(62, 0), pt(30, -16), pt(20, 10), pt(44, 20)], .olive)
        fill([pt(30, -16), pt(20, 10), pt(36, 6)], RGB.oliveDeep)
        // The brook between the hills
        stroke([pt(-30, -26), pt(-6, -2), pt(8, 6), pt(30, 28)], width: 6, .shallow)
        stroke([pt(-30, -26), pt(-6, -2), pt(8, 6), pt(30, 28)], width: 3, .water)
        // Five smooth stones out of the brook (17:40): one per depth.
        let stones: [(CGFloat, CGFloat)] = [(-10, 10), (-2, 14), (6, 16), (-14, 16), (2, 20)]
        for s in stones.prefix(d) { ellipse(pt(s.0, s.1), 5, 3.4, .stoneLight); ellipse(pt(s.0 + 1, s.1 + 0.8), 3.6, 1.8, .stoneShade, alpha: 0.7) }
    }

    private func stronghold(_ d: Int) {
        fill([pt(-58, 8), pt(0, 30), pt(58, 8), pt(0, -20)], .stoneShade, alpha: 0.5)
        box(pt(0, 4), w: 26, h: 40)
        roof(pt(0, -36), w: 26, rise: 14)
        // Wall segments grow out from the tower.
        let walls: [(CGFloat, CGFloat)] = [(-26, 10), (26, 10), (-40, 2), (40, 2)]
        for w in walls.prefix(d - 1) { box(pt(w.0, w.1), w: 14, h: 14) }
        if d >= 5 { // a banner
            rounded(CGRect(x: c.x - 0.8 * u, y: c.y - 66 * u, width: 1.6 * u, height: 16 * u), radius: u, .trunk)
            fill([pt(0, -66), pt(12, -62), pt(0, -58)], .lavender)
        }
    }

    private func pasture(_ d: Int) {
        diamond(c, width: W * 0.86, .olive, alpha: 0.55)
        ellipse(pt(16, 6), 44, 18, .shallow)
        ellipse(pt(16, 7), 36, 13, .water) // still waters
        let flock: [(CGFloat, CGFloat)] = [(-30, -4), (-14, 14), (-40, 10), (-22, 22), (36, -10), (-4, -12)]
        for s in flock.prefix(d + 1) { sheep(pt(s.0, s.1), 0.9) }
        if d >= 3 { // the shepherd's staff
            let path = CGMutablePath()
            path.move(to: pt(-50, 18))
            path.addLine(to: pt(-50, -20))
            path.addQuadCurve(to: pt(-42, -18), control: pt(-48, -28))
            ctx.addPath(path)
            ctx.setLineWidth(1.8 * u)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(RGB.trunk.cgColor)
            ctx.strokePath()
        }
    }

    // MARK: Prophets & Babylon

    private func shipAndFish(_ d: Int) {
        // The great fish, rising from the water
        ellipse(pt(20, 12), 58, 18, RGB(hex: "#8FA3B6"))
        fill([pt(46, 12), pt(60, 2), pt(58, 22)], RGB(hex: "#8FA3B6"))
        ellipse(pt(16, 8), 50, 10, RGB(hex: "#A9BDCC"))
        ellipse(pt(-2, 8), 3, 3, .brown, alpha: 0.6)
        _ = boat(pt(-26, -6), 1.2)
        for i in 0..<d { ellipse(pt(-48 + CGFloat(i) * 22, 22 - CGFloat(i % 2) * 8), 12, 3, .cream, alpha: 0.7) }
        if d >= 4 { // gulls
            for (x, y) in [(-10.0, -46.0), (6.0, -52.0)] { stroke([pt(x - 4, y), pt(x, y + 2), pt(x + 4, y)], width: 1.2, .brown, alpha: 0.5) }
        }
    }

    private func lionsDen(_ d: Int) {
        ellipse(pt(0, 4), 92, 40, .stoneShade)
        ellipse(pt(0, 6), 78, 32, RGB(hex: "#B9946C"))
        ellipse(pt(0, 8), 66, 24, RGB(hex: "#9C7A58"))
        // A stone laid upon the mouth of the den (6:17)
        box(pt(38, -10), w: 18, h: 6)
        // Lions, more with rereading
        let lions: [(CGFloat, CGFloat)] = [(-14, 6), (14, 10), (-26, 12), (24, 2), (0, 14)]
        for l in lions.prefix(min(5, d + 1)) {
            let p = pt(l.0, l.1)
            ellipse(CGPoint(x: p.x, y: p.y - 3 * u), 12, 6, .wheat)
            ellipse(CGPoint(x: p.x - 6 * u, y: p.y - 6 * u), 8, 8, .terracotta)
            ellipse(CGPoint(x: p.x - 6 * u, y: p.y - 6 * u), 4.6, 4.6, .wheat)
        }
    }

    // MARK: Gospels & Acts

    private func boats(_ d: Int) {
        let places: [(CGFloat, CGFloat, CGFloat)] = [(-6, 4, 1.1), (28, -8, 0.8), (-34, -8, 0.75), (24, 18, 0.7), (-28, 18, 0.65)]
        for b in places.prefix(d).sorted(by: { $0.1 < $1.1 }) { _ = boat(pt(b.0, b.1), b.2) }
    }

    private func weddingHouse(_ d: Int) {
        box(pt(-6, 4), w: 50, h: 22)
        roof(pt(-6, -18), w: 50, rise: 16)
        rounded(CGRect(x: c.x - 22 * u, y: c.y - 12 * u, width: 8 * u, height: 12 * u), radius: 4 * u, .brown, alpha: 0.2)
        // Lanterns strung for the feast
        stroke([pt(-34, -16), pt(-48, -4), pt(-58, 4)], width: 0.8, .trunk, alpha: 0.6)
        for (x, y) in [(-44.0, -6.0), (-54.0, 2.0)] { ellipse(pt(x, y), 4, 4, .wheat) }
        // Six waterpots of stone (2:6): more with each reread, up to six.
        let pots = min(6, d + 1)
        for i in 0..<pots {
            let p = pt(20 + CGFloat(i % 3) * 10, 12 + CGFloat(i / 3) * 8)
            cylinder(p, r: 3.6, h: 8, color: .stoneLight, shade: .stoneShade)
        }
    }

    private func vineyard(_ d: Int) {
        // A row of vines for each reading
        for row in 0..<d {
            for i in 0..<5 {
                let p = pt(-44 + CGFloat(i) * 14 + CGFloat(row) * 8, -20 + CGFloat(row) * 9 + CGFloat(i) * 4)
                rounded(CGRect(x: p.x - 0.8 * u, y: p.y - 12 * u, width: 1.6 * u, height: 12 * u), radius: u, .trunk)
                ellipse(CGPoint(x: p.x, y: p.y - 12 * u), 12, 8, .olive)
                ellipse(CGPoint(x: p.x + 2 * u, y: p.y - 9 * u), 3.4, 3.4, .lavender)
            }
        }
    }

    private func hillside(_ d: Int) {
        fill([pt(-60, 8), pt(0, 30), pt(60, 8), pt(10, -30)], .olive)
        fill([pt(0, 30), pt(60, 8), pt(10, -30)], RGB.oliveDeep, alpha: 0.6)
        person(pt(6, -18), robe: .cream, 1.1)
        // The multitudes: a few more each time.
        let robes: [RGB] = [.terracotta, .lavender, .wheat, .water, .stoneShade]
        for i in 0..<(3 * d) {
            let row = i / 5, col = i % 5
            person(pt(-30 + CGFloat(col) * 14 + CGFloat(row) * 6, -2 + CGFloat(row) * 8), robe: robes[i % robes.count], 0.7)
        }
    }

    private func pentecost(_ d: Int) {
        softGlow(pt(0, -30), radius: 46, .wheat, alpha: 0.4)
        box(pt(0, 8), w: 44, h: 22, top: .cream, left: .cream, right: Painter.creamShade)
        box(pt(0, -14), w: 30, h: 12, top: .cream, left: .cream, right: Painter.creamShade)
        // Tongues like as of fire (2:3), more with each reread.
        for i in 0..<(d * 2) {
            let x = -20 + CGFloat(i % 5) * 10, y = -36 - CGFloat(i / 5) * 10
            flame(pt(x, y), height: 9)
        }
    }

    private func shipwreck(_ d: Int) {
        waterPatch(width: 120)
        ellipse(pt(-14, 2), 70, 30, .beach)
        ellipse(pt(-18, -2), 54, 22, .olive, alpha: 0.75)
        // The broken stern on the rocks
        ellipse(pt(30, 14), 18, 8, .stoneShade)
        fill([pt(22, 10), pt(40, 4), pt(42, 12), pt(26, 16)], .trunk)
        rounded(CGRect(x: c.x + 32 * u, y: c.y - 14 * u, width: 1.6 * u, height: 20 * u), radius: u, .trunk)
        if d >= 2 { // they kindled a fire (28:2)
            softGlow(pt(-20, -6), radius: 16, .wheat, alpha: 0.6)
            flame(pt(-20, -4), height: 10)
        }
        // Planks washed ashore, and people safe on land
        let pieces: [(CGFloat, CGFloat)] = [(4, 16), (-40, 14), (14, 22)]
        for p in pieces.prefix(max(0, d - 2)) { rounded(CGRect(x: c.x + p.0 * u, y: c.y + p.1 * u, width: 10 * u, height: 2.4 * u), radius: u, .trunk) }
        if d >= 3 { for i in 0..<(d - 2) { person(pt(-34 + CGFloat(i) * 9, -2), robe: [.terracotta, .lavender, .water][i % 3], 0.7) } }
    }
}
