import CoreGraphics
import Foundation

/// What to draw for a landmark: its style, how far it is built, and its level.
nonisolated struct LandmarkLook: Hashable, Sendable {
    let style: BuildingStyle
    let stage: BuildStage
    let level: GrowthLevel
    let size: Int
}

/// Where the footprint's centre sits inside a rendered landmark image (for sprite anchoring).
nonisolated struct LandmarkImage: @unchecked Sendable {
    let image: CGImage
    let pointSize: CGSize
    /// Footprint centre, as a fraction of the image (SpriteKit anchor point, y up).
    let anchor: CGPoint
}

/// Draws landmark artwork with soft shapes, no outlines: left faces lighter, right faces darker.
nonisolated enum LandmarkPainter {

    static func render(_ look: LandmarkLook, scale: CGFloat) -> LandmarkImage? {
        let W = CGFloat(look.size) * Iso.tileWidth
        let H = W / 2
        let u = W / 130
        let pad = 16 * u
        let top = 112 * u
        let size = CGSize(width: W + pad * 2, height: H + pad + top)
        let pw = Int(ceil(size.width * scale)), ph = Int(ceil(size.height * scale))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Flip to y-down so drawing reads top-to-bottom.
        ctx.translateBy(x: 0, y: CGFloat(ph))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.setShouldAntialias(true)

        let center = CGPoint(x: size.width / 2, y: size.height - pad - H / 2)
        var painter = Painter(ctx: ctx, c: center, u: u, W: W)
        painter.draw(look)

        guard let image = ctx.makeImage() else { return nil }
        return LandmarkImage(image: image, pointSize: size,
                             anchor: CGPoint(x: 0.5, y: (pad + H / 2) / size.height))
    }
}

// MARK: - Painter

private nonisolated struct Painter {
    let ctx: CGContext
    let c: CGPoint
    let u: CGFloat
    let W: CGFloat

    // Extra palette
    static let terraDark = RGB(hex: "#CF8569")
    static let lavDark = RGB(hex: "#A893C6")
    static let creamShade = RGB(hex: "#EADFCB")
    static let gold = RGB(hex: "#EBCB7E")
    static let palm = RGB(hex: "#9DAE6C")

    mutating func draw(_ look: LandmarkLook) {
        switch look.stage {
        case .plot:
            plot()
        case .foundations:
            if look.level >= .flourishing { glow() }
            groundPatch()
            foundations()
            if look.level >= .growing { decorations() }
            if look.level >= .flourishing { flag(at: pt(0, -2)) }
        case .rising:
            if look.level >= .flourishing { glow() }
            groundPatch()
            foundations()
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: c.y - 24 * u, width: 10_000, height: 10_000))
            _ = building(look.style)
            ctx.restoreGState()
            scaffolding()
            if look.level >= .growing { decorations() }
            if look.level >= .flourishing { flag(at: pt(30, -44)) }
        case .complete:
            if look.level >= .flourishing || look.style == .glowCity { glow() }
            groundPatch()
            shadow(pt(0, 8), 96)
            let topPoint = building(look.style)
            if look.level >= .growing { decorations() }
            if look.level >= .flourishing { flag(at: topPoint) }
        }
    }

    // MARK: Primitives

    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + x * u, y: c.y + y * u) }

    func fill(_ points: [CGPoint], _ color: RGB, alpha: CGFloat = 1) {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor(alpha: alpha))
        ctx.fillPath()
    }

    func ellipse(_ center: CGPoint, _ w: CGFloat, _ h: CGFloat, _ color: RGB, alpha: CGFloat = 1) {
        ctx.setFillColor(color.cgColor(alpha: alpha))
        ctx.fillEllipse(in: CGRect(x: center.x - w * u / 2, y: center.y - h * u / 2, width: w * u, height: h * u))
    }

    func rounded(_ rect: CGRect, radius: CGFloat, _ color: RGB, alpha: CGFloat = 1) {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: min(radius, rect.width / 2), cornerHeight: min(radius, rect.height / 2), transform: nil))
        ctx.setFillColor(color.cgColor(alpha: alpha))
        ctx.fillPath()
    }

    func diamond(_ center: CGPoint, width w: CGFloat, _ color: RGB, alpha: CGFloat = 1) {
        fill([CGPoint(x: center.x, y: center.y - w / 4), CGPoint(x: center.x + w / 2, y: center.y),
              CGPoint(x: center.x, y: center.y + w / 4), CGPoint(x: center.x - w / 2, y: center.y)], color, alpha: alpha)
    }

    /// Isometric box standing on `base` (centre of its footprint); sizes in units.
    func box(_ base: CGPoint, w: CGFloat, h: CGFloat, top: RGB = .stoneLight, left: RGB = .stoneLight, right: RGB = .stoneShade) {
        let Wb = w * u, Hb = h * u
        fill([CGPoint(x: base.x - Wb / 2, y: base.y), CGPoint(x: base.x, y: base.y + Wb / 4),
              CGPoint(x: base.x, y: base.y + Wb / 4 - Hb), CGPoint(x: base.x - Wb / 2, y: base.y - Hb)], left)
        fill([CGPoint(x: base.x, y: base.y + Wb / 4), CGPoint(x: base.x + Wb / 2, y: base.y),
              CGPoint(x: base.x + Wb / 2, y: base.y - Hb), CGPoint(x: base.x, y: base.y + Wb / 4 - Hb)], right)
        diamond(CGPoint(x: base.x, y: base.y - Hb), width: Wb, top.shifted(0.02))
    }

    /// Pyramid roof on a box top; returns the apex.
    @discardableResult
    func roof(_ topCenter: CGPoint, w: CGFloat, rise: CGFloat, left: RGB = .terracotta, right: RGB = Painter.terraDark) -> CGPoint {
        let Wr = (w + 4) * u
        let apex = CGPoint(x: topCenter.x, y: topCenter.y - rise * u)
        fill([CGPoint(x: topCenter.x - Wr / 2, y: topCenter.y), CGPoint(x: topCenter.x, y: topCenter.y + Wr / 4), apex], left)
        fill([CGPoint(x: topCenter.x, y: topCenter.y + Wr / 4), CGPoint(x: topCenter.x + Wr / 2, y: topCenter.y), apex], right)
        return apex
    }

    /// Half-sphere dome; returns its top.
    @discardableResult
    func dome(_ base: CGPoint, r: CGFloat, color: RGB = .lavender) -> CGPoint {
        let R = r * u
        let path = CGMutablePath()
        path.addArc(center: base, radius: R, startAngle: .pi, endAngle: 0, clockwise: false)
        path.addEllipse(in: CGRect(x: base.x - R, y: base.y - R * 0.3, width: 2 * R, height: R * 0.6))
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
        ellipse(CGPoint(x: base.x - R * 0.35, y: base.y - R * 0.55), r * 0.4, r * 0.28, .cream, alpha: 0.4)
        return CGPoint(x: base.x, y: base.y - R)
    }

    func cylinder(_ base: CGPoint, r: CGFloat, h: CGFloat, color: RGB = .stoneLight, shade: RGB = .stoneShade) {
        let R = r * u, Hc = h * u
        rounded(CGRect(x: base.x - R, y: base.y - Hc, width: R, height: Hc), radius: 0, color)
        rounded(CGRect(x: base.x, y: base.y - Hc, width: R, height: Hc), radius: 0, shade)
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: base.x - R, y: base.y - R * 0.5, width: 2 * R, height: R))
        ctx.setFillColor(shade.cgColor)
        ctx.addPath(CGPath(ellipseIn: CGRect(x: base.x - R, y: base.y - R * 0.5, width: 2 * R, height: R), transform: nil))
        ctx.saveGState(); ctx.clip(to: CGRect(x: base.x, y: base.y - R, width: R, height: 2 * R)); ctx.fillPath(); ctx.restoreGState()
        ctx.setFillColor(color.shifted(0.03).cgColor)
        ctx.fillEllipse(in: CGRect(x: base.x - R, y: base.y - Hc - R * 0.5, width: 2 * R, height: R))
    }

    func shadow(_ at: CGPoint, _ w: CGFloat) {
        ellipse(at, w, w * 0.42, .brown, alpha: 0.09)
    }

    func tree(_ p: CGPoint, _ s: CGFloat = 1) {
        shadow(CGPoint(x: p.x, y: p.y + u), 20 * s)
        rounded(CGRect(x: p.x - 2.5 * u * s, y: p.y - 16 * u * s, width: 5 * u * s, height: 16 * u * s), radius: 2.5 * u * s, .trunk)
        ellipse(CGPoint(x: p.x + 3 * u * s, y: p.y - 22 * u * s), 22 * s, 18 * s, .oliveDeep)
        ellipse(CGPoint(x: p.x - 2 * u * s, y: p.y - 25 * u * s), 22 * s, 19 * s, .olive)
    }

    func cypress(_ p: CGPoint, _ s: CGFloat = 1) {
        shadow(CGPoint(x: p.x, y: p.y + u), 12 * s)
        ellipse(CGPoint(x: p.x + 1.5 * u * s, y: p.y - 16 * u * s), 11 * s, 32 * s, .oliveDeep)
        ellipse(CGPoint(x: p.x - 1 * u * s, y: p.y - 17 * u * s), 10 * s, 32 * s, .olive)
    }

    func palm(_ p: CGPoint, _ s: CGFloat = 1) -> CGPoint {
        rounded(CGRect(x: p.x - 1.6 * u * s, y: p.y - 26 * u * s, width: 3.2 * u * s, height: 26 * u * s), radius: 1.6 * u * s, .trunk)
        let top = CGPoint(x: p.x, y: p.y - 27 * u * s)
        for (dx, dy) in [(-11.0, 3.0), (11.0, 3.0), (-7.0, -4.0), (7.0, -4.0)] {
            ellipse(CGPoint(x: top.x + dx * u * s, y: top.y + dy * u * s), 15 * s, 6 * s, Painter.palm)
        }
        return top
    }

    func tent(_ p: CGPoint, _ s: CGFloat, _ color: RGB) -> CGPoint {
        shadow(CGPoint(x: p.x, y: p.y + 3 * u * s), 30 * s)
        let apex = CGPoint(x: p.x, y: p.y - 20 * u * s)
        fill([CGPoint(x: p.x - 15 * u * s, y: p.y), CGPoint(x: p.x, y: p.y + 7 * u * s), apex], color)
        fill([CGPoint(x: p.x, y: p.y + 7 * u * s), CGPoint(x: p.x + 15 * u * s, y: p.y), apex], color.shifted(-0.08))
        fill([CGPoint(x: p.x - 3 * u * s, y: p.y + 5.6 * u * s), CGPoint(x: p.x + 1 * u * s, y: p.y + 6.6 * u * s),
              CGPoint(x: p.x - 1 * u * s, y: p.y - 4 * u * s)], .brown, alpha: 0.25)
        return apex
    }

    func boat(_ p: CGPoint, _ s: CGFloat) -> CGPoint {
        ellipse(CGPoint(x: p.x, y: p.y + 3 * u * s), 34 * s, 7 * s, .waterDeep)
        fill([CGPoint(x: p.x - 16 * u * s, y: p.y - 4 * u * s), CGPoint(x: p.x + 16 * u * s, y: p.y - 4 * u * s),
              CGPoint(x: p.x + 11 * u * s, y: p.y + 3 * u * s), CGPoint(x: p.x - 11 * u * s, y: p.y + 3 * u * s)], .terracotta)
        rounded(CGRect(x: p.x - 0.8 * u * s, y: p.y - 30 * u * s, width: 1.6 * u * s, height: 26 * u * s), radius: u, .trunk)
        fill([CGPoint(x: p.x + 1.5 * u * s, y: p.y - 29 * u * s), CGPoint(x: p.x + 14 * u * s, y: p.y - 7 * u * s),
              CGPoint(x: p.x + 1.5 * u * s, y: p.y - 7 * u * s)], .cream)
        return CGPoint(x: p.x, y: p.y - 30 * u * s)
    }

    func house(_ p: CGPoint, _ s: CGFloat, roofColor: RGB = .terracotta) -> CGPoint {
        shadow(CGPoint(x: p.x, y: p.y + 4 * u * s), 34 * s)
        box(p, w: 24 * s, h: 16 * s)
        rounded(CGRect(x: p.x - 8 * u * s, y: p.y - 9 * u * s, width: 4 * u * s, height: 7 * u * s), radius: 2 * u * s, .brown, alpha: 0.18)
        return roof(CGPoint(x: p.x, y: p.y - 16 * u * s), w: 24 * s, rise: 12 * s, left: roofColor, right: roofColor.shifted(-0.07))
    }

    // MARK: Stages

    func plot() {
        let inner = W * 0.86
        diamond(c, width: inner, .sand, alpha: 0.35)
        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: c.x, y: c.y - inner / 4), CGPoint(x: c.x + inner / 2, y: c.y),
                                CGPoint(x: c.x, y: c.y + inner / 4), CGPoint(x: c.x - inner / 2, y: c.y)])
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setStrokeColor(RGB.brown.cgColor(alpha: 0.38))
        ctx.setLineWidth(2.2 * u)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineDash(phase: 0, lengths: [7 * u, 6 * u])
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
    }

    func groundPatch() {
        diamond(c, width: W * 0.9, .stoneLight, alpha: 0.45)
    }

    func foundations() {
        let inner = W * 0.62
        let corners = [CGPoint(x: c.x, y: c.y - inner / 4), CGPoint(x: c.x + inner / 2, y: c.y),
                       CGPoint(x: c.x, y: c.y + inner / 4), CGPoint(x: c.x - inner / 2, y: c.y)]
        diamond(c, width: inner, .stoneShade, alpha: 0.35)
        var stones: [CGPoint] = []
        for i in 0..<4 {
            let a = corners[i], b = corners[(i + 1) % 4]
            for t in stride(from: 0.0, to: 1.0, by: 0.2) {
                stones.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        for p in stones.sorted(by: { $0.y < $1.y }) {
            box(p, w: 9, h: 5)
        }
        // A small pile of cut stones waiting nearby.
        box(pt(-44, 10), w: 8, h: 4); box(pt(-38, 13), w: 8, h: 4); box(pt(-41, 8), w: 7, h: 4)
    }

    func scaffolding() {
        let poles: [CGFloat] = [-30, -12, 12, 30]
        for x in poles {
            let y = abs(x) > 20 ? 0 : 12
            rounded(CGRect(x: c.x + x * u - 0.9 * u, y: c.y + CGFloat(y) * u - 44 * u, width: 1.8 * u, height: 44 * u), radius: u, .trunk)
        }
        for y in [-18.0, -32.0] {
            fill([pt(-32, y), pt(0, y + 13), pt(32, y), pt(32, y - 2), pt(0, y + 11), pt(-32, y - 2)], .trunk, alpha: 0.85)
        }
    }

    func glow() {
        let colors = [Painter.gold.cgColor(alpha: 0.5), Painter.gold.cgColor(alpha: 0)] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) else { return }
        let center = pt(0, -26)
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: 1, y: 0.75)
        ctx.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 78 * u, options: [])
        ctx.restoreGState()
    }

    func decorations() {
        tree(pt(-52, 2), 0.75)
        cypress(pt(50, 4), 0.85)
        tree(pt(18, 27), 0.6)
        for (x, y) in [(-34.0, 18.0), (36.0, 18.0), (-8.0, 30.0)] {
            ellipse(pt(x, y), 5, 4, .terracotta)
            ellipse(pt(x + 4, y + 2), 4, 3, .lavender)
        }
    }

    func flag(at top: CGPoint) {
        let pole = CGRect(x: top.x - 0.8 * u, y: top.y - 18 * u, width: 1.6 * u, height: 18 * u)
        rounded(pole, radius: u, .trunk)
        fill([CGPoint(x: top.x, y: top.y - 18 * u), CGPoint(x: top.x + 13 * u, y: top.y - 14 * u),
              CGPoint(x: top.x, y: top.y - 10 * u)], .lavender)
    }

    // MARK: Buildings — each returns its highest point (for the flag)

    func building(_ style: BuildingStyle) -> CGPoint {
        switch style {
        case .garden: return garden()
        case .pyramid: return pyramid()
        case .tabernacle: return tabernacle()
        case .tents: return tents()
        case .mountain: return mountain()
        case .walls: return walls(color: .stoneLight, shade: .stoneShade, roofs: .terracotta)
        case .village: return village()
        case .field: return field()
        case .palace: return palace()
        case .temple: return temple()
        case .tower: return tower()
        case .gate: return gate()
        case .harbour: return harbour()
        case .house: return upperHouse()
        case .outpost: return outpost()
        case .portCity: return portCity()
        case .hill: return hill()
        case .glowCity: return glowCity()
        case .well: return well()
        case .vineyard: return vineyard()
        }
    }

    func garden() -> CGPoint {
        ellipse(pt(6, 8), 40, 18, .shallow)
        ellipse(pt(6, 8), 30, 12, .water)
        let spots: [(CGFloat, CGFloat, CGFloat)] = [(-30, -10, 1.0), (24, -14, 1.1), (-6, -20, 1.2), (-40, 8, 0.9), (36, 6, 0.9), (-16, 20, 0.8), (22, 22, 0.85)]
        for s in spots.sorted(by: { $0.1 < $1.1 }) { tree(pt(s.0, s.1), s.2) }
        for (x, y) in [(-22.0, 2.0), (14.0, -2.0), (40.0, 16.0), (-34.0, 22.0)] {
            ellipse(pt(x, y), 5, 4, .terracotta); ellipse(pt(x + 4, y + 2), 4, 3, .lavender)
        }
        return pt(-6, -50)
    }

    func pyramid() -> CGPoint {
        func pyr(_ b: CGPoint, _ s: CGFloat) -> CGPoint {
            let apex = CGPoint(x: b.x, y: b.y - 50 * u * s)
            fill([CGPoint(x: b.x - 34 * u * s, y: b.y), CGPoint(x: b.x, y: b.y + 17 * u * s), apex], .stoneLight)
            fill([CGPoint(x: b.x, y: b.y + 17 * u * s), CGPoint(x: b.x + 34 * u * s, y: b.y), apex], .stoneShade)
            return apex
        }
        _ = pyr(pt(-28, -10), 0.6)
        let apex = pyr(pt(6, 2), 1)
        _ = palm(pt(40, 14), 0.8)
        box(pt(-36, 18), w: 7, h: 22, top: .stoneLight)
        return apex
    }

    func tabernacle() -> CGPoint {
        diamond(c, width: 104 * u, .cream)
        diamond(pt(0, -2), width: 96 * u, .sand)
        box(pt(4, -2), w: 36, h: 18, top: .cream, left: .cream, right: Painter.creamShade)
        let apex = roof(pt(4, -20), w: 36, rise: 14, left: .lavender, right: Painter.lavDark)
        box(pt(-22, 14), w: 10, h: 7, top: .terracotta, left: .terracotta, right: Painter.terraDark)
        return apex
    }

    func tents() -> CGPoint {
        let spots: [(CGFloat, CGFloat, CGFloat, RGB)] = [(-26, -10, 1.0, .terracotta), (16, -16, 1.1, .cream), (-4, 4, 1.2, .lavender), (30, 8, 0.9, .wheat), (-34, 14, 0.8, .cream)]
        var highest = pt(0, -30)
        for s in spots.sorted(by: { $0.1 < $1.1 }) {
            let apex = tent(pt(s.0, s.1), s.2, s.3)
            if apex.y < highest.y { highest = apex }
        }
        ellipse(pt(8, 20), 8, 4, .terracotta, alpha: 0.8)
        return highest
    }

    func mountain() -> CGPoint {
        let apex = pt(-4, -66)
        fill([pt(-58, 6), pt(0, 30), apex], .stoneLight)
        fill([pt(0, 30), pt(58, 6), apex], .stoneShade)
        fill([pt(-12, -44), pt(-1, -38), apex], .cream)
        fill([pt(-1, -38), pt(9, -45), apex], Painter.creamShade)
        cypress(pt(-36, 14), 0.7); cypress(pt(40, 14), 0.6)
        box(pt(14, 22), w: 9, h: 6)
        return apex
    }

    func walls(color: RGB, shade: RGB, roofs: RGB) -> CGPoint {
        let wallH: CGFloat = 20
        let towerW: CGFloat = 18, towerH: CGFloat = 34
        let back = pt(0, -20)
        box(back, w: towerW, h: towerH, top: color, left: color, right: shade)
        let backApex = roof(CGPoint(x: back.x, y: back.y - towerH * u), w: towerW, rise: 12, left: roofs, right: roofs.shifted(-0.07))
        box(pt(-40, 0), w: towerW, h: towerH, top: color, left: color, right: shade)
        roof(pt(-40, -towerH), w: towerW, rise: 12, left: roofs, right: roofs.shifted(-0.07))
        box(pt(40, 0), w: towerW, h: towerH, top: color, left: color, right: shade)
        roof(pt(40, -towerH), w: towerW, rise: 12, left: roofs, right: roofs.shifted(-0.07))
        // Wall ring with an open courtyard.
        box(pt(0, 2), w: 76, h: wallH, top: color, left: color, right: shade)
        diamond(pt(0, 2 - wallH), width: 60 * u, .sand)
        box(pt(0, 22), w: towerW, h: towerH, top: color, left: color, right: shade)
        roof(pt(0, 22 - towerH), w: towerW, rise: 12, left: roofs, right: roofs.shifted(-0.07))
        rounded(CGRect(x: c.x - 22 * u, y: c.y + 4 * u, width: 8 * u, height: 12 * u), radius: 4 * u, .brown, alpha: 0.2)
        return backApex
    }

    func village() -> CGPoint {
        let spots: [(CGFloat, CGFloat, CGFloat)] = [(-24, -10, 1.0), (18, -14, 0.9), (-2, 6, 1.15), (30, 10, 0.85), (-34, 14, 0.8)]
        var highest = pt(0, -30)
        for s in spots.sorted(by: { $0.1 < $1.1 }) {
            let apex = house(pt(s.0, s.1), s.2)
            if apex.y < highest.y { highest = apex }
        }
        _ = palm(pt(42, -4), 0.7)
        return highest
    }

    func field() -> CGPoint {
        diamond(c, width: W * 0.8, .wheat, alpha: 0.35)
        var spots: [CGPoint] = []
        for a in -4...4 { for b in -4...4 { spots.append(pt(CGFloat(a - b) * 6.5, CGFloat(a + b) * 3.25 + 4)) } }
        for p in spots.sorted(by: { $0.y < $1.y }) where abs(p.x - c.x) + 2 * abs(p.y - c.y - 4 * u) < 52 * u {
            rounded(CGRect(x: p.x - 0.8 * u, y: p.y - 12 * u, width: 1.6 * u, height: 12 * u), radius: u, .olive)
            ellipse(CGPoint(x: p.x, y: p.y - 14 * u), 4, 8, .wheat)
        }
        let apex = house(pt(-40, -14), 0.8)
        ellipse(pt(40, -18), 11, 16, RGB(hex: "#DDB466"))
        ellipse(pt(40, -18), 12, 3, .terracotta)
        return apex
    }

    func palace() -> CGPoint {
        box(pt(0, 6), w: 84, h: 22)
        box(pt(0, -16), w: 54, h: 18)
        let top = dome(pt(0, -34), r: 12, color: .terracotta)
        dome(pt(-30, -10), r: 7)
        dome(pt(30, -10), r: 7)
        for i in 0..<4 {
            let x = -36 + CGFloat(i) * 9, y = 10 + CGFloat(i) * 4.5
            rounded(CGRect(x: c.x + x * u - 1.6 * u, y: c.y + y * u - 15 * u, width: 3.2 * u, height: 15 * u), radius: 1.6 * u, .cream)
        }
        rounded(CGRect(x: c.x + 10 * u, y: c.y + 2 * u, width: 9 * u, height: 14 * u), radius: 4.5 * u, .brown, alpha: 0.2)
        return top
    }

    func temple() -> CGPoint {
        let base = pt(0, 6)
        box(base, w: 64, h: 26)
        rounded(CGRect(x: base.x - 18 * u, y: base.y - 15 * u, width: 7 * u, height: 12 * u), radius: 3.5 * u, .brown, alpha: 0.18)
        rounded(CGRect(x: base.x + 11 * u, y: base.y - 15 * u, width: 7 * u, height: 12 * u), radius: 3.5 * u, .brown, alpha: 0.22)
        let top = dome(CGPoint(x: base.x, y: base.y - 26 * u), r: 19)
        for i in 0..<3 {
            let x = base.x - 27 * u + CGFloat(i) * 8 * u, y = base.y + (CGFloat(i) * 4 + 3) * u
            rounded(CGRect(x: x - 1.5 * u, y: y - 14 * u, width: 3 * u, height: 14 * u), radius: 1.5 * u, .cream)
        }
        ellipse(CGPoint(x: top.x, y: top.y - 3 * u), 6, 6, .wheat)
        return CGPoint(x: top.x, y: top.y - 6 * u)
    }

    func tower() -> CGPoint {
        let base = pt(0, 8)
        let h: CGFloat = 56
        shadow(CGPoint(x: base.x, y: base.y + 6 * u), 50)
        box(base, w: 36, h: h)
        ellipse(CGPoint(x: base.x - 9 * u, y: base.y - h * u * 0.55), 5, 8, .stoneShade)
        ellipse(CGPoint(x: base.x + 9 * u, y: base.y - h * u * 0.55), 5, 8, .brown, alpha: 0.18)
        ellipse(pt(-28, 14), 14, 8, .stoneShade)
        ellipse(pt(24, -14), 10, 6, .stoneShade)
        return roof(CGPoint(x: base.x, y: base.y - h * u), w: 38, rise: 24)
    }

    func gate() -> CGPoint {
        let base = pt(0, 10)
        let halfW = 32 * u, wallH = 52 * u, dx = 12 * u, dy = 6 * u
        fill([CGPoint(x: base.x + halfW, y: base.y), CGPoint(x: base.x + halfW + dx, y: base.y - dy),
              CGPoint(x: base.x + halfW + dx, y: base.y - dy - wallH), CGPoint(x: base.x + halfW, y: base.y - wallH)], .stoneShade)
        fill([CGPoint(x: base.x - halfW, y: base.y - wallH), CGPoint(x: base.x + halfW, y: base.y - wallH),
              CGPoint(x: base.x + halfW + dx, y: base.y - wallH - dy), CGPoint(x: base.x - halfW + dx, y: base.y - wallH - dy)], RGB(hex: "#F7E2C0"))
        let wall = CGMutablePath()
        wall.addRoundedRect(in: CGRect(x: base.x - halfW, y: base.y - wallH, width: 2 * halfW, height: wallH), cornerWidth: 3 * u, cornerHeight: 3 * u)
        let archW = 22 * u, archH = 34 * u
        let arch = CGMutablePath()
        arch.move(to: CGPoint(x: base.x - archW / 2, y: base.y))
        arch.addLine(to: CGPoint(x: base.x - archW / 2, y: base.y - archH + archW / 2))
        arch.addArc(center: CGPoint(x: base.x, y: base.y - archH + archW / 2), radius: archW / 2, startAngle: .pi, endAngle: 0, clockwise: false)
        arch.addLine(to: CGPoint(x: base.x + archW / 2, y: base.y))
        arch.closeSubpath()
        ctx.addPath(arch); ctx.setFillColor(RGB.brown.cgColor(alpha: 0.16)); ctx.fillPath()
        wall.addPath(arch)
        ctx.addPath(wall); ctx.setFillColor(RGB.stoneLight.cgColor); ctx.fillPath(using: .evenOdd)
        rounded(CGRect(x: base.x - halfW, y: base.y - wallH + 10 * u, width: 2 * halfW, height: 5 * u), radius: 0, .lavender, alpha: 0.9)
        for i in 0..<4 {
            let x = base.x - halfW + 4 * u + CGFloat(i) * 16 * u
            rounded(CGRect(x: x, y: base.y - wallH - 7 * u, width: 8 * u, height: 8 * u), radius: 2 * u, .terracotta)
        }
        return CGPoint(x: base.x, y: base.y - wallH - 7 * u)
    }

    func harbour() -> CGPoint {
        diamond(pt(10, 4), width: 86 * u, .shallow)
        diamond(pt(12, 6), width: 66 * u, .water)
        fill([pt(-44, -4), pt(-4, 16), pt(-4, 20), pt(-44, 0)], .trunk, alpha: 0.9)
        for x in stride(from: -40.0, through: -8.0, by: 8.0) {
            rounded(CGRect(x: c.x + x * u, y: c.y + (x * 0.5 + 18) * u, width: 2 * u, height: 6 * u), radius: u, .trunk)
        }
        let mast = boat(pt(14, 2), 1)
        _ = boat(pt(36, -10), 0.6)
        for (x, y) in [(-6.0, 14.0), (30.0, 18.0)] { ellipse(pt(x, y), 10, 2.5, .cream, alpha: 0.6) }
        return mast
    }

    func upperHouse() -> CGPoint {
        let base = pt(0, 8)
        box(base, w: 54, h: 26)
        rounded(CGRect(x: base.x - 20 * u, y: base.y - 14 * u, width: 8 * u, height: 12 * u), radius: 4 * u, .brown, alpha: 0.2)
        for i in 0..<4 {
            box(pt(22 + CGFloat(i) * 3, 14 - CGFloat(i) * 1.5 - CGFloat(i) * 5), w: 8, h: 4)
        }
        box(pt(-4, -18), w: 28, h: 16)
        rounded(CGRect(x: c.x - 12 * u, y: c.y - 31 * u, width: 5 * u, height: 7 * u), radius: 2.5 * u, .wheat, alpha: 0.8)
        return roof(pt(-4, -34), w: 28, rise: 12)
    }

    func outpost() -> CGPoint {
        _ = tent(pt(-10, 2), 1.2, .cream)
        let top = palm(pt(30, -8), 1)
        ellipse(pt(-36, 14), 12, 7, .stoneShade)
        ellipse(pt(-28, 18), 8, 5, .stoneLight)
        ellipse(pt(16, 18), 7, 4, .terracotta, alpha: 0.8)
        ellipse(pt(16, 16), 4, 3, .wheat)
        return top
    }

    func portCity() -> CGPoint {
        diamond(pt(28, 14), width: 50 * u, .water)
        _ = house(pt(-28, -8), 0.9)
        _ = house(pt(-6, 4), 1.0, roofColor: .lavender)
        cylinder(pt(18, -10), r: 7, h: 46, color: .cream, shade: Painter.creamShade)
        let lampTop = pt(18, -62)
        ellipse(pt(18, -60), 9, 9, .wheat)
        roof(pt(18, -64), w: 12, rise: 8)
        _ = boat(pt(34, 16), 0.5)
        return lampTop
    }

    func hill() -> CGPoint {
        let apex = pt(-4, -40)
        fill([pt(-56, 6), pt(0, 30), pt(56, 6), pt(30, -20), apex, pt(-30, -18)], .olive)
        fill([pt(0, 30), pt(56, 6), pt(30, -20), apex], .oliveDeep)
        tree(pt(-6, -36), 0.8)
        for (x, y) in [(-20.0, 10.0), (-10.0, 14.0), (8.0, 12.0), (18.0, 16.0)] {
            ellipse(pt(x, y), 4, 4, .cream); ellipse(pt(x, y + 3), 5, 4, .terracotta, alpha: 0.7)
        }
        return pt(-6, -62)
    }

    func glowCity() -> CGPoint {
        let top = walls(color: .cream, shade: Painter.creamShade, roofs: .lavender)
        dome(pt(0, -18), r: 10, color: Painter.gold)
        return top
    }

    func well() -> CGPoint {
        shadow(pt(0, 10), 40)
        cylinder(pt(0, 6), r: 12, h: 14)
        ellipse(pt(0, -8), 18, 8, .water)
        for x in [-11.0, 11.0] {
            rounded(CGRect(x: c.x + x * u - u, y: c.y - 30 * u, width: 2 * u, height: 26 * u), radius: u, .trunk)
        }
        let apex = roof(pt(0, -30), w: 28, rise: 10)
        tree(pt(-36, 0), 0.8)
        return apex
    }

    func vineyard() -> CGPoint {
        for row in 0..<4 {
            for i in 0..<5 {
                let p = pt(-36 + CGFloat(i) * 12 + CGFloat(row) * 6, -18 + CGFloat(row) * 9 + CGFloat(i) * 3)
                rounded(CGRect(x: p.x - 0.8 * u, y: p.y - 10 * u, width: 1.6 * u, height: 10 * u), radius: u, .trunk)
                ellipse(CGPoint(x: p.x, y: p.y - 10 * u), 10, 7, .olive)
                ellipse(CGPoint(x: p.x + 2 * u, y: p.y - 8 * u), 3, 3, .lavender)
            }
        }
        box(pt(36, -18), w: 14, h: 26)
        return roof(pt(36, -44), w: 14, rise: 10)
    }
}
