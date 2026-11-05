import SwiftUI

// Code-drawn Place pieces, in the same soft pastel isometric style as the rest of the island
// (see IslandArt.swift for the palette and `IsoPen`). Growable pieces are drawn as a cluster of
// small things laid on a gentle spiral: one more for every step of growth, the newest one
// fading and growing in (so a field or garden spreads rather than pops). Richness (rereads)
// makes everything fuller: more flowers, extra floors, banners, a warm glow.

enum PlaceArt {
    /// How big things are drawn for a Place of this many tiles.
    static func scale(_ span: CGFloat) -> CGFloat { min(1.45, max(0.95, span / 3.8)) }

    /// Half the ground a piece covers, in grid units (for its footprint and tap target).
    static func groundRadius(_ kind: PieceKind, span: CGFloat) -> CGFloat {
        kind.isGrowable ? radius(kind, span: span) + 0.12 : 0.32 * scale(span)
    }

    /// Radius of a growable piece's cluster, in grid units.
    static func radius(_ kind: PieceKind, span: CGFloat) -> CGFloat {
        switch kind {
        case .wall: span * 0.24
        case .river, .field, .garden: span * 0.2
        case .dock: 0.4
        default: span * 0.17
        }
    }

    /// The drawn size in u (width, height above the ground point), for tap targets.
    static func size(_ item: Island.Item) -> CGSize {
        guard case .piece(let kind) = item.kind else { return CGSize(width: 30, height: 30) }
        let k = scale(item.span)
        if kind.isGrowable {
            let r = radius(kind, span: item.span)
            return CGSize(width: max(30, r * 88), height: (tall(kind) ? 34 : 18) * k + r * 22)
        }
        return CGSize(width: 40 * k, height: tall(kind) ? 58 * k : 34 * k)
    }

    private static func tall(_ kind: PieceKind) -> Bool {
        switch kind {
        case .orchard, .grove, .cedars, .palms, .houses, .lamps, .wall, .tower, .lighthouse, .palace, .temple, .upperRoom,
             .tabernacle, .hall, .goldGate, .gate, .ship, .hill, .throneSeat, .lampstand, .tents: true
        default: false
        }
    }

    // MARK: Drawing

    /// - Parameters:
    ///   - side: which way (on screen, after turning and mirroring) the Place's bay lies.
    static func draw(_ pen: IsoPen, item: Island.Item, kind: PieceKind, side: Int) {
        let k = scale(item.span)
        let r = max(1, item.level)
        if kind.isGrowable {
            drawGrowable(pen, kind: kind, growth: item.growth, cap: item.cap, span: item.span, richness: r, seed: item.seed, side: side)
        } else {
            drawBuilt(pen, kind: kind, k: k, richness: r, seed: item.seed, side: side)
        }
    }

    /// Positions for a growable piece's elements: a golden-angle spiral filling `radius`.
    static func spiral(_ count: Int, cap: Int, radius: CGFloat, seed: Int) -> [CGPoint] {
        let n = max(cap, count)
        return (0..<count).map { i in
            let rr = radius * sqrt((CGFloat(i) + 0.5) / CGFloat(n))
            let a = CGFloat(i) * 2.39996 + CGFloat(seed % 7)
            return CGPoint(x: cos(a) * rr, y: sin(a) * rr)
        }
    }

    private static func drawGrowable(_ pen: IsoPen, kind: PieceKind, growth: CGFloat, cap: Int, span: CGFloat,
                                     richness r: Int, seed: Int, side: Int) {
        let k = scale(span)
        let R = radius(kind, span: span)
        let shown = Int(growth.rounded(.up))
        // Element i is full grown once growth passes i + 1; the newest grows in.
        func size(_ i: Int) -> CGFloat { min(1, max(0, growth - CGFloat(i))) }
        let fullness = min(1, growth / CGFloat(max(1, cap)))
        switch kind {
        case .field:
            patch(pen, radius: R * (0.35 + 0.65 * sqrt(fullness)), colour: Earthy.goldShine, shade: Earthy.goldDome)
            rows(pen, radius: R * (0.35 + 0.65 * sqrt(fullness)), count: 3 + shown, colour: Earthy.goldDome)
            for (i, p) in ordered(spiral(shown + (r - 1) * 2, cap: cap + 8, radius: R * 0.9 * sqrt(fullness) + 0.05, seed: seed)) {
                sheaf(pen, p.x, p.y, s: k * 0.8 * (i < shown ? size(i) : 1))
            }
        case .garden:
            patch(pen, radius: R * (0.4 + 0.6 * sqrt(fullness)), colour: Color(hex: "#D9C192"), shade: Color(hex: "#C9AE7E"))
            let pts = spiral(shown + (r - 1) * 3, cap: cap + 12, radius: R * (0.35 + 0.6 * sqrt(fullness)), seed: seed)
            for (i, p) in ordered(pts) {
                plant(pen, p.x, p.y, s: k * (i < shown ? size(i) : 0.7), flower: (i + seed) % 3 == 0 || r >= 3, seed: seed + i)
            }
        case .flowers:
            for (i, p) in ordered(spiral(shown * 2 + (r - 1) * 4, cap: cap * 2 + 16, radius: R, seed: seed)) {
                flower(pen, p.x, p.y, s: k * (i / 2 < shown ? size(i / 2) : 0.8), seed: seed + i)
            }
        case .orchard:
            for (i, p) in ordered(spiral(shown, cap: cap, radius: R, seed: seed)) {
                pen.shadow(p.x, p.y, rx: 5 * k)
                tree(pen, p.x, p.y, s: 0.5 * k * size(i), fruit: r >= 2 || i % 2 == 0, seed: seed + i)
            }
        case .grove:
            for (i, p) in ordered(spiral(shown, cap: cap, radius: R, seed: seed)) {
                tree(pen, p.x, p.y, s: 0.55 * k * size(i), fruit: r >= 4, seed: seed + i)
            }
        case .cedars:
            for (i, p) in ordered(spiral(shown, cap: cap, radius: R, seed: seed)) { cedar(pen, p.x, p.y, s: k * size(i)) }
        case .palms:
            for (i, p) in ordered(spiral(shown, cap: cap, radius: R, seed: seed)) { palm(pen, p.x, p.y, s: k * size(i)) }
        case .vineyard:
            for i in 0..<shown {
                let y = -R + CGFloat(i) * (2 * R / CGFloat(max(1, cap - 1)))
                vineRow(pen, y: y, length: R * 1.6, s: k * size(i), grapes: r >= 2)
            }
        case .tents:
            for (i, p) in ordered(spiral(shown, cap: cap, radius: R, seed: seed)) { tent(pen, p.x, p.y, s: k * size(i), seed: seed + i) }
        case .houses:
            for (i, p) in ordered(spiral(shown, cap: cap, radius: R, seed: seed)) {
                house(pen, p.x, p.y, s: 0.85 * k * size(i), floors: 1 + (r >= 3 && i % 2 == 0 ? 1 : 0), seed: seed + i, banner: r >= 4 && i == 0)
            }
        case .terraces:
            for (i, p) in ordered(spiral(shown, cap: cap, radius: R, seed: seed)) { terrace(pen, p.x, p.y, s: k * size(i), bloom: r >= 2) }
        case .flock:
            for (i, p) in ordered(spiral(shown + (r - 1), cap: cap + 4, radius: R, seed: seed)) { sheep(pen, p.x, p.y, s: k * (i < shown ? size(i) : 1)) }
        case .stalls:
            for (i, p) in ordered(spiral(shown, cap: cap, radius: R, seed: seed)) { stall(pen, p.x, p.y, s: k * size(i), seed: seed + i) }
        case .scrolls:
            for (i, p) in ordered(spiral(shown, cap: cap, radius: R, seed: seed)) { scrollStand(pen, p.x, p.y, s: k * size(i)) }
        case .lamps:
            for (i, p) in ordered(spiral(shown, cap: cap, radius: R, seed: seed)) { lamp(pen, p.x, p.y, s: k * size(i), glow: 0.25 + 0.1 * CGFloat(r)) }
        case .crowd:
            for (i, p) in ordered(spiral(shown * 2, cap: cap * 2, radius: R, seed: seed)) { person(pen, p.x, p.y, s: k * size(i / 2), seed: seed + i) }
        case .wall:
            wall(pen, segments: shown, cap: cap, radius: R, k: k, growing: size(shown - 1))
        case .river:
            river(pen, length: growth / CGFloat(max(1, cap)), radius: R, k: k, glow: r >= 5)
        case .dock:
            dock(pen, length: growth, cap: cap, k: k, side: side)
        default:
            break
        }
    }

    /// Points sorted back to front, with their original index.
    private static func ordered(_ pts: [CGPoint]) -> [(Int, CGPoint)] {
        pts.enumerated().sorted { $0.element.x + $0.element.y < $1.element.x + $1.element.y }.map { ($0.offset, $0.element) }
    }

    // MARK: Built once

    private static func drawBuilt(_ pen: IsoPen, kind: PieceKind, k: CGFloat, richness r: Int, seed: Int, side: Int) {
        let walls = Earthy.walls(.sand), cream = Earthy.walls(.cream), wood = Earthy.walls(.wood), clay = Earthy.walls(.clay)
        let stone = Earthy.Walls(left: Earthy.stone, right: Earthy.stoneShade, top: Color(hex: "#F1E0BC"))
        let floors: CGFloat = r >= 3 ? 2 : 1
        let st = BuildingArt.storey * k
        var top: CGFloat = 0 // where a banner goes, if rich
        switch kind {
        case .soil:
            patch(pen, radius: 0.32 * k, colour: Color(hex: "#C9A577"), shade: Color(hex: "#B48F62"))
            rows(pen, radius: 0.32 * k, count: 5, colour: Color(hex: "#A98257"))
        case .tent:
            pen.shadow(0, 0, rx: 14 * k)
            top = pen.cone(0, 0, r: 0.26 * k, h: 22 * k, light: Earthy.cloth, dark: Earthy.clothShade)
            pen.arch(.left, box: 0, 0, hx: 0.12 * k, hy: 0.12 * k, t: 0.5, z: 0, width: 0.07 * k, h: 8 * k)
        case .tabernacle:
            pen.shadow(0, 0, rx: 20 * k)
            pen.box(0, 0, hx: 0.36 * k, hy: 0.2 * k, h: 13 * k, cream)
            pen.box(0, 0, hx: 0.38 * k, hy: 0.22 * k, z0: 13 * k, h: 3 * k,
                    Earthy.Walls(left: Earthy.roofLight, right: Earthy.roofDark, top: Color(hex: "#E9AE95")))
            pen.arch(.left, box: 0, 0, hx: 0.36 * k, hy: 0.2 * k, t: 0.75, z: 0, width: 0.12 * k, h: 10 * k, color: Earthy.dome)
            top = 16 * k
        case .altar:
            pen.shadow(0, 0, rx: 10 * k)
            pen.box(0, 0, hx: 0.16 * k, hy: 0.16 * k, h: 8 * k, stone)
            for (x, y) in [(-0.14, -0.14), (0.14, -0.14), (-0.14, 0.14), (0.14, 0.14)] {
                pen.box(x * k, y * k, hx: 0.025, hy: 0.025, z0: 8 * k, h: 2.5 * k, stone, soft: 0.3)
            }
            flame(pen, z: 9 * k, s: k)
        case .basin:
            pen.shadow(0, 0, rx: 9 * k)
            let o = pen.p(0, 0)
            pen.rect(-1.5 * k, -6 * k, 3 * k, 6 * k, Earthy.goldShade, at: o)
            pen.ellipse(CGPoint(x: o.x, y: o.y - 7 * k * pen.u), 9 * k, 4.5 * k, Earthy.goldShade)
            pen.ellipse(CGPoint(x: o.x, y: o.y - 7.6 * k * pen.u), 7 * k, 3.2 * k, Earthy.water)
        case .lampstand:
            let o = pen.p(0, 0)
            pen.shadow(0, 0, rx: 6 * k)
            pen.rect(-0.8 * k, -20 * k, 1.6 * k, 20 * k, Earthy.gold, at: o)
            for i in 0..<7 {
                let dx = (CGFloat(i) - 3) * 2.6 * k
                let h = 20 - abs(CGFloat(i) - 3) * 2
                pen.rect(dx - 0.5 * k, -h * k, 1 * k, (h - 12) * k, Earthy.gold, at: o)
                pen.ellipse(CGPoint(x: o.x + dx * pen.u, y: o.y - (h + 1.5) * k * pen.u), 1.3 * k, 2 * k, Color(hex: "#F6C66E"))
            }
            glow(pen, z: 20 * k, r: 14 * k, strength: 0.25)
        case .courtFence:
            let R = 0.42 * k
            for i in 0..<16 {
                let t = CGFloat(i) / 16 * 2 * .pi
                let x = cos(t) * R * 1.3, y = sin(t) * R
                pen.box(x, y, hx: 0.08 * k, hy: 0.02 * k, h: 7 * k, cream, soft: 0.4)
            }
        case .farmhouse:
            pen.shadow(0, 0, rx: 16 * k)
            pen.box(0, 0, hx: 0.24 * k, hy: 0.18 * k, h: st * floors, cream)
            pen.windows(box: 0, 0, hx: 0.24 * k, hy: 0.18 * k, storeys: Int(floors), storey: st)
            top = pen.gable(0, 0, hx: 0.24 * k, hy: 0.18 * k, z: st * floors, h: 9 * k, gableEnd: cream.right)
        case .barn:
            pen.shadow(0, 0, rx: 17 * k)
            pen.box(0, 0, hx: 0.26 * k, hy: 0.2 * k, h: st * 1.2, wood)
            pen.arch(.left, box: 0, 0, hx: 0.26 * k, hy: 0.2 * k, t: 0.5, z: 0, width: 0.18 * k, h: st, color: Earthy.woodDeep)
            top = pen.gable(0, 0, hx: 0.26 * k, hy: 0.2 * k, z: st * 1.2, h: 10 * k, gableEnd: Earthy.woodDark)
        case .threshingFloor:
            let o = pen.p(0, 0)
            pen.ellipse(o, 16 * k, 8 * k, Earthy.stoneShade)
            pen.ellipse(CGPoint(x: o.x, y: o.y - 1 * pen.u), 15 * k, 7.4 * k, Earthy.stone)
            for i in 0..<(2 + r) { sheaf(pen, -0.15 + CGFloat(i) * 0.1, 0.12, s: 0.8 * k) }
        case .mill:
            millstone(pen, x: -0.12 * k, y: 0, k: k)
            oven(pen, x: 0.14 * k, y: 0.1 * k, k: k)
        case .oven:
            oven(pen, x: 0, y: 0, k: k)
        case .gate:
            pen.shadow(0, 0, rx: 18 * k)
            let tw = 0.1 * k, gap = 0.2 * k, h = 22 * k
            pen.box(-gap - tw, 0, hx: tw, hy: tw, h: h, walls)
            pen.box(0, 0, hx: gap, hy: tw * 0.8, z0: 13 * k, h: 7 * k, walls)
            pen.box(gap + tw, 0, hx: tw, hy: tw, h: h, walls)
            pen.battlements(-gap - tw, 0, hx: tw, hy: tw, z: h, walls)
            pen.battlements(gap + tw, 0, hx: tw, hy: tw, z: h, walls)
            top = h + 3
        case .well:
            BuildingArt.wellShape(pen, x: 0, y: 0, size: 1.1 * k)
        case .hut:
            pen.shadow(0, 0, rx: 12 * k)
            pen.box(0, 0, hx: 0.17 * k, hy: 0.14 * k, h: 9 * k * floors, clay)
            pen.arch(.left, box: 0, 0, hx: 0.17 * k, hy: 0.14 * k, t: 0.5, z: 0, width: 0.08 * k, h: 7 * k)
            top = pen.pyramid(0, 0, hx: 0.17 * k, hy: 0.14 * k, z: 9 * k * floors, h: 8 * k,
                              light: Color(hex: "#E5C98F"), dark: Color(hex: "#CDAE74"))
        case .tower:
            pen.shadow(0, 0, rx: 10 * k)
            let h = st * (2.6 + floors * 0.4)
            pen.box(0, 0, hx: 0.12 * k, hy: 0.12 * k, h: h, walls)
            pen.arch(.left, box: 0, 0, hx: 0.12 * k, hy: 0.12 * k, t: 0.5, z: h * 0.55, width: 0.07 * k, h: st * 0.6)
            pen.battlements(0, 0, hx: 0.12 * k, hy: 0.12 * k, z: h, walls)
            top = h + 3 * k
        case .palace:
            pen.shadow(0, 0, rx: 22 * k)
            let h = st * (1 + floors)
            pen.box(0, 0, hx: 0.34 * k, hy: 0.24 * k, h: h, cream)
            pen.windows(box: 0, 0, hx: 0.34 * k, hy: 0.24 * k, storeys: Int(1 + floors), storey: st)
            top = pen.dome(0, 0, r: 0.15 * k, z: h, gold: r >= 3, drum: cream)
        case .temple:
            pen.shadow(0, 0, rx: 22 * k)
            pen.box(0, 0, hx: 0.36 * k, hy: 0.28 * k, h: 3 * k, stone)
            pen.box(0, 0, hx: 0.3 * k, hy: 0.22 * k, z0: 3 * k, h: st * 1.6, cream)
            for i in 0..<4 {
                let t = (CGFloat(i) + 0.5) / 4
                pen.arch(.left, box: 0, 0, hx: 0.3 * k, hy: 0.22 * k, t: t, z: 3 * k, width: 0.08 * k, h: st * 1.3, color: Earthy.window.opacity(0.8))
            }
            top = pen.gable(0, 0, hx: 0.3 * k, hy: 0.22 * k, z: 3 * k + st * 1.6, h: 8 * k, gableEnd: cream.right)
            if r >= 2 { glow(pen, z: top, r: 10 * k, strength: 0.18) }
        case .house:
            house(pen, 0, 0, s: 1.25 * k, floors: Int(floors) + 1, seed: seed, banner: r >= 4)
        case .upperRoom:
            pen.shadow(0, 0, rx: 15 * k)
            pen.box(0, 0, hx: 0.22 * k, hy: 0.2 * k, h: st * (1 + floors), walls)
            pen.windows(box: 0, 0, hx: 0.22 * k, hy: 0.2 * k, storeys: Int(1 + floors), storey: st)
            // An outside stair up the side and a lamp in the upper window.
            for i in 0..<5 {
                pen.box(0.25 * k, 0.14 * k - CGFloat(i) * 0.06 * k, hx: 0.04 * k, hy: 0.03 * k, h: CGFloat(i + 1) * st * 0.2, stone, soft: 0.3)
            }
            glow(pen, z: st * 1.5, r: 8 * k, strength: 0.3)
            top = st * (1 + floors) + 2
        case .fountain:
            let o = pen.p(0, 0)
            pen.ellipse(o, 15 * k, 7.5 * k, Earthy.stoneShade)
            pen.ellipse(CGPoint(x: o.x, y: o.y - 2 * pen.u), 14 * k, 7 * k, Earthy.stone)
            pen.ellipse(CGPoint(x: o.x, y: o.y - 2.5 * pen.u), 11 * k, 5.4 * k, Earthy.water)
            pen.ellipse(CGPoint(x: o.x - 3 * pen.u, y: o.y - 3 * pen.u), 5 * k, 1.6 * k, Earthy.waterShine)
            pen.rect(-1 * k, -10 * k, 2 * k, 8 * k, Earthy.stone, at: o)
            pen.ellipse(CGPoint(x: o.x, y: o.y - 11 * k * pen.u), 3 * k, 2 * k, Earthy.waterShine)
        case .pavilion:
            pen.shadow(0, 0, rx: 16 * k)
            for (x, y) in [(-0.2, -0.2), (0.2, -0.2), (-0.2, 0.2), (0.2, 0.2)] {
                pen.box(x * k, y * k, hx: 0.025, hy: 0.025, h: 14 * k, cream, soft: 0.4)
            }
            top = pen.pyramid(0, 0, hx: 0.24 * k, hy: 0.24 * k, z: 14 * k, h: 10 * k, light: Earthy.dome, dark: Color(hex: "#A792C4"))
            harp(pen, x: 0, y: 0.05, s: k)
        case .hall:
            pen.shadow(0, 0, rx: 20 * k)
            pen.box(0, 0, hx: 0.32 * k, hy: 0.22 * k, h: st * (floors + 0.5), cream)
            pen.windows(box: 0, 0, hx: 0.32 * k, hy: 0.22 * k, storeys: Int(floors), storey: st * 1.4)
            top = pen.dome(0, 0, r: 0.13 * k, z: st * (floors + 0.5), gold: r >= 4, drum: nil)
        case .lighthouse:
            pen.shadow(0, 0, rx: 9 * k)
            let o = pen.p(0, 0), rx = 6 * k, h = 34 * k
            pen.rect(-rx, -h, rx, h, cream.left, at: o)
            pen.rect(0, -h, rx, h, cream.right, at: o)
            pen.rect(-rx, -h * 0.55, 2 * rx, 2.5 * k, Earthy.roofLight.opacity(0.8), at: o)
            pen.ellipse(CGPoint(x: o.x, y: o.y - h * pen.u), rx, rx * 0.5, cream.top)
            pen.rect(-rx * 0.6, -h - 6 * k, rx * 1.2, 6 * k, Earthy.goldShine, radius: 2, at: o)
            glow(pen, z: h + 3 * k, r: 14 * k, strength: 0.2 + 0.05 * CGFloat(r))
            top = pen.dome(0, 0, r: 0.14 * k, z: h + 6 * k)
        case .pillar:
            pen.shadow(0, 0, rx: 9 * k)
            for (i, x) in [-0.1, 0.0, 0.1].enumerated() {
                pen.box(x * k, CGFloat(i % 2) * 0.05 * k, hx: 0.035 * k, hy: 0.035 * k, h: (12 + CGFloat(i % 2) * 5) * k, stone, soft: 0.5)
            }
        case .marketHall:
            pen.shadow(0, 0, rx: 20 * k)
            pen.box(0, 0, hx: 0.34 * k, hy: 0.16 * k, h: st, walls)
            for i in 0..<4 {
                pen.arch(.left, box: 0, 0, hx: 0.34 * k, hy: 0.16 * k, t: (CGFloat(i) + 0.5) / 4, z: 0, width: 0.1 * k, h: st * 0.8)
            }
            top = pen.gable(0, 0, hx: 0.34 * k, hy: 0.16 * k, z: st, h: 7 * k, gableEnd: walls.right)
            stall(pen, 0.2 * k, 0.32 * k, s: k, seed: seed)
        case .goldGate:
            pen.shadow(0, 0, rx: 20 * k)
            let pearl = Earthy.Walls(left: Color(hex: "#FBF4EA"), right: Color(hex: "#EFE4D6"), top: Color(hex: "#FFFAF2"))
            pen.box(-0.26 * k, 0, hx: 0.1 * k, hy: 0.1 * k, h: 26 * k, pearl)
            pen.box(0, 0, hx: 0.16 * k, hy: 0.08 * k, z0: 16 * k, h: 10 * k, pearl)
            pen.box(0.26 * k, 0, hx: 0.1 * k, hy: 0.1 * k, h: 26 * k, pearl)
            for x in [-0.26, 0.26] { pen.dome(CGFloat(x) * k, 0, r: 0.09 * k, z: 26 * k, gold: true) }
            glow(pen, z: 20 * k, r: 26 * k, strength: 0.18 + 0.05 * CGFloat(r))
            top = 34 * k
        case .ship:
            let o = pen.p(0, 0)
            pen.ellipse(o, 18 * k, 8 * k, Earthy.water.opacity(0.8))
            BuildingArt.boat(pen, x: 0, y: 0, size: 1.6 * k)
        case .olivePress, .winepress:
            pen.shadow(0, 0, rx: 10 * k)
            pen.box(0, 0, hx: 0.16 * k, hy: 0.16 * k, h: 4 * k, stone)
            let o = pen.p(0, 0, 4 * k)
            pen.ellipse(o, 8 * k, 4 * k, kind == .winepress ? Color(hex: "#9C6A8E") : Color(hex: "#C7B66A"))
            pen.rect(-12 * k, -14 * k, 24 * k, 2 * k, Earthy.woodDark, at: o)
            pen.rect(9 * k, -14 * k, 2 * k, 14 * k, Earthy.woodDark, at: o)
        case .meetingHouse:
            pen.shadow(0, 0, rx: 17 * k)
            pen.box(0, 0, hx: 0.26 * k, hy: 0.2 * k, h: st * 1.3, walls)
            pen.windows(box: 0, 0, hx: 0.26 * k, hy: 0.2 * k, storeys: 1, storey: st * 1.3)
            top = pen.gable(0, 0, hx: 0.26 * k, hy: 0.2 * k, z: st * 1.3, h: 9 * k, gableEnd: walls.right)
            if r >= 2 { glow(pen, z: st * 0.7, r: 9 * k, strength: 0.18) }
        case .nets:
            let o = pen.p(0, 0)
            for i in 0..<3 {
                let dx = (CGFloat(i) - 1) * 9 * k
                pen.rect(dx - 0.6 * k, -12 * k, 1.2 * k, 12 * k, Earthy.woodDark, at: o)
            }
            var net = Path()
            for j in 0..<5 {
                let y = o.y - (11 - CGFloat(j) * 1.6) * k * pen.u
                net.move(to: CGPoint(x: o.x - 9 * k * pen.u, y: y)); net.addLine(to: CGPoint(x: o.x + 9 * k * pen.u, y: y + 1.5 * pen.u))
            }
            for j in 0..<7 {
                let x = o.x + (-9 + CGFloat(j) * 3) * k * pen.u
                net.move(to: CGPoint(x: x, y: o.y - 11 * k * pen.u)); net.addLine(to: CGPoint(x: x, y: o.y - 4 * k * pen.u))
            }
            pen.c.stroke(net, with: .color(Earthy.woodLight.opacity(0.8)), lineWidth: 0.5 * pen.u)
        case .hill:
            let o = pen.p(0, 0), w = 26 * k, h = 24 * k
            let hill = Path { pp in
                pp.move(to: CGPoint(x: o.x - w * pen.u, y: o.y))
                pp.addQuadCurve(to: CGPoint(x: o.x + w * pen.u, y: o.y), control: CGPoint(x: o.x, y: o.y - 2 * h * pen.u))
                pp.addQuadCurve(to: CGPoint(x: o.x - w * pen.u, y: o.y), control: CGPoint(x: o.x, y: o.y + 10 * k * pen.u))
            }
            pen.c.fill(hill, with: .color(Earthy.strataLeftTop))
            pen.c.fill(Path { pp in
                pp.move(to: CGPoint(x: o.x, y: o.y - h * pen.u))
                pp.addQuadCurve(to: CGPoint(x: o.x + w * pen.u, y: o.y), control: CGPoint(x: o.x + w * 0.6 * pen.u, y: o.y - h * 0.8 * pen.u))
                pp.addLine(to: CGPoint(x: o.x, y: o.y + 4 * pen.u))
            }, with: .color(Earthy.strataRightTop))
            pen.ellipse(CGPoint(x: o.x - 6 * pen.u, y: o.y - h * 0.7 * pen.u), 6 * k, 3 * k, Earthy.bush)
            top = h
        case .cave:
            let o = pen.p(0, 0)
            pen.ellipse(o, 18 * k, 12 * k, Earthy.strataLeft)
            pen.ellipse(CGPoint(x: o.x, y: o.y - 5 * pen.u), 16 * k, 11 * k, Earthy.strataLeftTop)
            pen.ellipse(CGPoint(x: o.x - 2 * pen.u, y: o.y - 2 * pen.u), 5 * k, 5 * k, Earthy.window)
        case .throneSeat:
            pen.shadow(0, 0, rx: 16 * k)
            let gold = Earthy.Walls(left: Earthy.goldDome, right: Earthy.goldShade, top: Earthy.goldShine)
            pen.box(0, 0, hx: 0.24 * k, hy: 0.24 * k, h: 4 * k, Earthy.Walls(left: Color(hex: "#FBF4EA"), right: Color(hex: "#EFE4D6"), top: Color(hex: "#FFFAF2")))
            pen.box(0, -0.05 * k, hx: 0.1 * k, hy: 0.04 * k, z0: 4 * k, h: 16 * k, gold)
            pen.box(0, 0.04 * k, hx: 0.1 * k, hy: 0.08 * k, z0: 4 * k, h: 6 * k, gold)
            glow(pen, z: 12 * k, r: 22 * k, strength: 0.25 + 0.05 * CGFloat(r))
            top = 20 * k
        default:
            break
        }
        if r >= 4, top > 0 { banner(pen, z: top, k: k, seed: seed) }
        if r >= 5 { glow(pen, z: 8 * k, r: 22 * k, strength: 0.12) }
    }

    // MARK: Small things

    private static func patch(_ pen: IsoPen, radius r: CGFloat, colour: Color, shade: Color) {
        let pts = [pen.p(-r, -r), pen.p(r, -r), pen.p(r, r), pen.p(-r, r)]
        pen.fill(pts.map { CGPoint(x: $0.x, y: $0.y + 1.2 * pen.u) }, shade, soft: 4)
        pen.fill(pts, colour, soft: 4)
    }

    private static func rows(_ pen: IsoPen, radius r: CGFloat, count: Int, colour: Color) {
        var path = Path()
        let n = max(2, min(12, count))
        for i in 1..<n {
            let t = -r + 2 * r * CGFloat(i) / CGFloat(n)
            path.move(to: pen.p(-r * 0.9, t)); path.addLine(to: pen.p(r * 0.9, t))
        }
        pen.c.stroke(path, with: .color(colour.opacity(0.7)), style: StrokeStyle(lineWidth: 1.1 * pen.u, lineCap: .round))
    }

    private static func sheaf(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat) {
        guard s > 0.05 else { return }
        let o = pen.p(x, y)
        for i in -1...1 {
            pen.rect(CGFloat(i) * 1.2 * s - 0.4 * s, -8 * s, 0.8 * s, 8 * s, Earthy.goldShade, at: o)
            pen.ellipse(CGPoint(x: o.x + CGFloat(i) * 1.6 * s * pen.u, y: o.y - 9 * s * pen.u), 1.2 * s, 2.4 * s, Earthy.gold)
        }
    }

    static func plant(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat, flower: Bool, seed: Int) {
        guard s > 0.05 else { return }
        let o = pen.p(x, y)
        pen.ellipse(CGPoint(x: o.x, y: o.y - 3 * s * pen.u), 4 * s, 3.2 * s, seed % 2 == 0 ? Earthy.leaf : Earthy.bush)
        if flower {
            let colours = [Earthy.roofLight, Earthy.dome, Earthy.goldShine, Color(hex: "#F2B6B6")]
            pen.ellipse(CGPoint(x: o.x + 1.2 * s * pen.u, y: o.y - 5 * s * pen.u), 1.4 * s, 1.4 * s, colours[abs(seed) % colours.count])
        }
    }

    static func flower(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat, seed: Int) {
        guard s > 0.05 else { return }
        let o = pen.p(x, y)
        let colours = [Earthy.roofLight, Earthy.dome, Earthy.goldShine, Color(hex: "#F2B6B6"), Earthy.cloth]
        pen.rect(-0.3 * s, -4 * s, 0.6 * s, 4 * s, Earthy.leafShade, at: o)
        pen.ellipse(CGPoint(x: o.x, y: o.y - 4.5 * s * pen.u), 1.8 * s, 1.6 * s, colours[abs(seed) % colours.count])
    }

    static func tree(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat, fruit: Bool, seed: Int) {
        guard s > 0.03 else { return }
        pen.tree(x, y, size: s, fruit: fruit, seed: seed)
    }

    static func cedar(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat) {
        guard s > 0.05 else { return }
        let o = pen.p(x, y)
        pen.shadow(x, y, rx: 6 * s)
        pen.rect(-1 * s, -6 * s, 2 * s, 6 * s, Earthy.trunk, at: o)
        for (i, w) in [8.0, 6.5, 4.5].enumerated() {
            let base = o.y - (5 + CGFloat(i) * 7) * s * pen.u
            pen.fill([CGPoint(x: o.x - CGFloat(w) * s * pen.u, y: base), CGPoint(x: o.x, y: base - 11 * s * pen.u),
                      CGPoint(x: o.x + CGFloat(w) * s * pen.u, y: base)], i % 2 == 0 ? Earthy.leafShade : Color(hex: "#8C9862"))
        }
    }

    static func palm(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat) {
        guard s > 0.05 else { return }
        let o = pen.p(x, y)
        pen.shadow(x, y, rx: 6 * s)
        pen.rect(-0.9 * s, -20 * s, 1.8 * s, 20 * s, Earthy.trunk, radius: 0.9 * s, at: o)
        let top = CGPoint(x: o.x, y: o.y - 20 * s * pen.u)
        for i in 0..<5 {
            let a = CGFloat(i) / 5 * .pi * 2
            let tip = CGPoint(x: top.x + cos(a) * 9 * s * pen.u, y: top.y + (sin(a) * 3 + 3) * s * pen.u)
            var leaf = Path()
            leaf.move(to: top)
            leaf.addQuadCurve(to: tip, control: CGPoint(x: (top.x + tip.x) / 2, y: top.y - 4 * s * pen.u))
            pen.c.stroke(leaf, with: .color(Earthy.leaf), style: StrokeStyle(lineWidth: 2.4 * s * pen.u, lineCap: .round))
        }
    }

    private static func vineRow(_ pen: IsoPen, y: CGFloat, length: CGFloat, s: CGFloat, grapes: Bool) {
        guard s > 0.05 else { return }
        let a = pen.p(-length / 2, y), b = pen.p(length / 2, y)
        for t in stride(from: CGFloat(0), through: 1, by: 0.5) {
            let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            pen.rect(-0.5, -8 * s, 1, 8 * s, Earthy.woodDark, at: p)
        }
        var band = Path()
        band.move(to: CGPoint(x: a.x, y: a.y - 6 * s * pen.u))
        band.addLine(to: CGPoint(x: b.x, y: b.y - 6 * s * pen.u))
        pen.c.stroke(band, with: .color(Earthy.leaf), style: StrokeStyle(lineWidth: 4.5 * s * pen.u, lineCap: .round))
        if grapes {
            for t in [0.2, 0.45, 0.7, 0.9] {
                let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t - 4 * s * pen.u)
                pen.ellipse(p, 1.3 * s, 1.8 * s, Color(hex: "#9C7AB0"))
            }
        }
    }

    static func tent(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat, seed: Int) {
        guard s > 0.05 else { return }
        let colours: [(Color, Color)] = [(Earthy.cloth, Earthy.clothShade), (Earthy.roofLight, Earthy.roofDark),
                                         (Color(hex: "#E8D4B0"), Color(hex: "#D3BC94")), (Earthy.dome, Color(hex: "#A792C4"))]
        let (l, d) = colours[abs(seed) % colours.count]
        pen.shadow(x, y, rx: 7 * s)
        pen.cone(x, y, r: 0.12 * s, h: 12 * s, light: l, dark: d)
    }

    static func house(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat, floors: Int, seed: Int, banner hasBanner: Bool) {
        guard s > 0.05 else { return }
        let tones: [WallTone] = [.sand, .cream, .clay]
        let w = Earthy.walls(tones[abs(seed) % tones.count])
        let hx = 0.11 * s, h = 9 * s * CGFloat(floors)
        pen.shadow(x, y, rx: 8 * s)
        pen.box(x, y, hx: hx, hy: hx, h: h, w, soft: 0.6)
        pen.arch(.left, box: x, y, hx: hx, hy: hx, t: 0.5, z: 0, width: 0.06 * s, h: 6 * s)
        if floors > 1 { pen.arch(.right, box: x, y, hx: hx, hy: hx, t: 0.5, z: 10 * s, width: 0.05 * s, h: 4 * s) }
        let top: CGFloat
        if seed % 2 == 0 {
            top = pen.pyramid(x, y, hx: hx, hy: hx, z: h, h: 6 * s)
        } else {
            pen.box(x, y, hx: hx + 0.01, hy: hx + 0.01, z0: h, h: 1.2 * s, w, soft: 0.3)
            top = h + 1.2 * s
        }
        if hasBanner {
            var g = pen
            g.c.translateBy(x: pen.p(x, y).x, y: pen.p(x, y).y)
            banner(g, z: top, k: s * 0.8, seed: seed)
        }
    }

    private static func terrace(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat, bloom: Bool) {
        guard s > 0.05 else { return }
        let stone = Earthy.Walls(left: Earthy.stone, right: Earthy.stoneShade, top: Color(hex: "#F1E0BC"))
        pen.box(x, y, hx: 0.13 * s, hy: 0.09 * s, h: 3 * s, stone, soft: 0.5)
        harp(pen, x: x, y: y, s: s * 0.8, z: 3 * s)
        if bloom { flower(pen, x + 0.08 * s, y + 0.06 * s, s: s * 0.8, seed: Int(x * 100)) }
    }

    private static func harp(_ pen: IsoPen, x: CGFloat, y: CGFloat, s: CGFloat, z: CGFloat = 0) {
        let o = pen.p(x, y, z)
        var frame = Path()
        frame.move(to: CGPoint(x: o.x - 3 * s * pen.u, y: o.y))
        frame.addLine(to: CGPoint(x: o.x - 3 * s * pen.u, y: o.y - 11 * s * pen.u))
        frame.addQuadCurve(to: CGPoint(x: o.x + 3 * s * pen.u, y: o.y - 2 * s * pen.u), control: CGPoint(x: o.x + 4 * s * pen.u, y: o.y - 11 * s * pen.u))
        frame.addLine(to: CGPoint(x: o.x - 3 * s * pen.u, y: o.y))
        pen.c.stroke(frame, with: .color(Earthy.gold), style: StrokeStyle(lineWidth: 1.2 * s * pen.u, lineJoin: .round))
        var strings = Path()
        for i in 1..<4 {
            let xx = o.x + (-3 + CGFloat(i) * 1.5) * s * pen.u
            strings.move(to: CGPoint(x: xx, y: o.y - 1 * s * pen.u)); strings.addLine(to: CGPoint(x: xx, y: o.y - (9 - CGFloat(i) * 1.5) * s * pen.u))
        }
        pen.c.stroke(strings, with: .color(Earthy.goldShine), lineWidth: 0.4 * pen.u)
    }

    static func sheep(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat) {
        guard s > 0.05 else { return }
        let o = pen.p(x, y)
        pen.shadow(x, y, rx: 4 * s)
        pen.rect(-2 * s, -2.5 * s, 0.8 * s, 2.5 * s, Earthy.woodDeep, at: o)
        pen.rect(1.2 * s, -2.5 * s, 0.8 * s, 2.5 * s, Earthy.woodDeep, at: o)
        pen.ellipse(CGPoint(x: o.x, y: o.y - 4 * s * pen.u), 4 * s, 2.8 * s, Color(hex: "#FBF6EC"))
        pen.ellipse(CGPoint(x: o.x + 3.6 * s * pen.u, y: o.y - 5 * s * pen.u), 1.4 * s, 1.6 * s, Earthy.woodDeep)
    }

    private static func stall(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat, seed: Int) {
        guard s > 0.05 else { return }
        let wood = Earthy.walls(.wood)
        pen.shadow(x, y, rx: 6 * s)
        pen.box(x, y, hx: 0.09 * s, hy: 0.06 * s, h: 4 * s, wood, soft: 0.4)
        let colour = [Earthy.roofLight, Earthy.dome, Earthy.goldDome][abs(seed) % 3]
        pen.box(x, y, hx: 0.1 * s, hy: 0.07 * s, z0: 9 * s, h: 1.2 * s, Earthy.Walls(left: colour, right: colour.opacity(0.8), top: Earthy.cloth), soft: 0.4)
        let o = pen.p(x, y, 4 * s)
        for i in 0..<3 { pen.ellipse(CGPoint(x: o.x + (CGFloat(i) - 1) * 2.2 * s * pen.u, y: o.y - 1 * s * pen.u), 1.1 * s, 1 * s,
                                     [Earthy.gold, Earthy.roofLight, Earthy.leaf][i]) }
    }

    private static func scrollStand(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat) {
        guard s > 0.05 else { return }
        pen.box(x, y, hx: 0.07 * s, hy: 0.05 * s, h: 7 * s, Earthy.walls(.wood), soft: 0.4)
        let o = pen.p(x, y, 7 * s)
        pen.rect(-3.5 * s, -2 * s, 7 * s, 2 * s, Earthy.cloth, radius: 1 * s, at: o)
        pen.ellipse(CGPoint(x: o.x - 3.5 * s * pen.u, y: o.y - 1 * s * pen.u), 0.9 * s, 1.2 * s, Earthy.clothShade)
    }

    static func lamp(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat, glow strength: CGFloat) {
        guard s > 0.05 else { return }
        let o = pen.p(x, y)
        pen.ellipse(CGPoint(x: o.x, y: o.y - 13 * s * pen.u), 6 * s, 5 * s, Earthy.gold.opacity(Double(min(0.6, strength))))
        pen.rect(-0.5 * s, -12 * s, 1 * s, 12 * s, Earthy.woodDeep, at: o)
        pen.rect(-1.6 * s, -15 * s, 3.2 * s, 3.4 * s, Earthy.goldShine, radius: 0.8 * s, at: o)
    }

    static func person(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, s: CGFloat, seed: Int) {
        guard s > 0.05 else { return }
        let o = pen.p(x, y)
        let robes = [Earthy.roofLight, Earthy.dome, Earthy.cloth, Earthy.leaf, Earthy.goldDome]
        pen.ellipse(o, 2.4 * s, 1.1 * s, Earthy.shadow.opacity(0.6))
        pen.rect(-2 * s, -7 * s, 4 * s, 7 * s, robes[abs(seed) % robes.count], radius: 1.8 * s, at: o)
        pen.ellipse(CGPoint(x: o.x, y: o.y - 8.6 * s * pen.u), 2 * s, 2 * s, Color(hex: "#D9A88A"))
    }

    private static func wall(_ pen: IsoPen, segments n: Int, cap: Int, radius R: CGFloat, k: CGFloat, growing: CGFloat) {
        let walls = Earthy.walls(.sand)
        // Segments run round the back of the Place from the left to the right corner.
        let count = max(1, cap)
        var segs: [(x: CGFloat, y: CGFloat, i: Int)] = []
        for i in 0..<n {
            let t = CGFloat(i) / CGFloat(max(1, count - 1))
            let a = .pi * 0.75 + t * .pi * 1.5 // around the back
            segs.append((cos(a) * R, sin(a) * R * 0.98, i))
        }
        for s in segs.sorted(by: { $0.x + $0.y < $1.x + $1.y }) {
            let h = 13 * k * (s.i == n - 1 ? growing : 1)
            guard h > 0.5 else { continue }
            pen.box(s.x, s.y, hx: 0.13 * k, hy: 0.13 * k, h: h, walls, soft: 0.5)
            if s.i % 3 == 0 { pen.battlements(s.x, s.y, hx: 0.13 * k, hy: 0.13 * k, z: h, walls) }
        }
    }

    private static func river(_ pen: IsoPen, length: CGFloat, radius R: CGFloat, k: CGFloat, glow: Bool) {
        let steps = 24
        let shown = max(2, Int(CGFloat(steps) * min(1, max(0.1, length))))
        var path = Path()
        for i in 0...shown {
            let t = CGFloat(i) / CGFloat(steps)
            let x = -R + 2 * R * t
            let y = sin(t * .pi * 2) * R * 0.35
            let p = pen.p(x, y)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        pen.c.stroke(path, with: .color(Earthy.stoneShade), style: StrokeStyle(lineWidth: 11 * k * pen.u, lineCap: .round, lineJoin: .round))
        pen.c.stroke(path, with: .color(glow ? Color(hex: "#CFE7EE") : Earthy.water), style: StrokeStyle(lineWidth: 8 * k * pen.u, lineCap: .round, lineJoin: .round))
        pen.c.stroke(path, with: .color(Earthy.waterShine), style: StrokeStyle(lineWidth: 2 * k * pen.u, lineCap: .round, lineJoin: .round, dash: [6 * pen.u, 9 * pen.u]))
    }

    /// A jetty out over the bay (`side`, on screen), lengthening with growth, boats moored along it.
    private static func dock(_ pen: IsoPen, length g: CGFloat, cap: Int, k: CGFloat, side: Int) {
        let dir: (CGFloat, CGFloat) = [(0, 1), (1, 0), (0, -1), (-1, 0)][((side % 4) + 4) % 4]
        let planks = 3 + Int(g.rounded(.up))
        let wood = Earthy.walls(.wood)
        let order = (0..<planks).sorted { a, b in
            (CGFloat(a) * (dir.0 + dir.1)) < (CGFloat(b) * (dir.0 + dir.1))
        }
        for i in order {
            let d = CGFloat(i) * 0.14
            let grow = i >= planks - 1 ? min(1, max(0.2, g - CGFloat(planks - 4))) : 1
            pen.box(dir.0 * d, dir.1 * d, hx: dir.0 == 0 ? 0.09 : 0.07, hy: dir.1 == 0 ? 0.09 : 0.07, h: 1.6 * grow,
                    wood, soft: 0.3)
        }
        let boats = Int(g / 2)
        for b in 0..<boats {
            let d = 0.3 + CGFloat(b / 2) * 0.32
            let off: CGFloat = b % 2 == 0 ? 0.24 : -0.24
            BuildingArt.boat(pen, x: dir.0 * d + (dir.0 == 0 ? off : 0), y: dir.1 * d + (dir.1 == 0 ? off : 0), size: 0.7 * k)
        }
    }

    private static func millstone(_ pen: IsoPen, x: CGFloat, y: CGFloat, k: CGFloat) {
        let o = pen.p(x, y)
        pen.shadow(x, y, rx: 8 * k)
        pen.ellipse(o, 8 * k, 4 * k, Earthy.stoneShade)
        pen.rect(-8 * k, -3 * k, 16 * k, 3 * k, Earthy.stone, at: o)
        pen.ellipse(CGPoint(x: o.x, y: o.y - 3 * k * pen.u), 8 * k, 4 * k, Color(hex: "#F1E0BC"))
        pen.rect(-1 * k, -10 * k, 2 * k, 7 * k, Earthy.woodDark, at: o)
        pen.rect(-1 * k, -10 * k, 12 * k, 1.6 * k, Earthy.woodDark, at: o)
    }

    private static func oven(_ pen: IsoPen, x: CGFloat, y: CGFloat, k: CGFloat) {
        let o = pen.p(x, y)
        pen.shadow(x, y, rx: 7 * k)
        let path = Path { pp in
            pp.move(to: CGPoint(x: o.x - 7 * k * pen.u, y: o.y))
            pp.addQuadCurve(to: CGPoint(x: o.x + 7 * k * pen.u, y: o.y), control: CGPoint(x: o.x, y: o.y - 16 * k * pen.u))
        }
        pen.c.fill(path, with: .color(Color(hex: "#DDA987")))
        pen.ellipse(CGPoint(x: o.x - 1 * pen.u, y: o.y - 3 * k * pen.u), 2.4 * k, 2.4 * k, Earthy.window)
    }

    private static func flame(_ pen: IsoPen, z: CGFloat, s: CGFloat) {
        let o = pen.p(0, 0, z)
        pen.ellipse(CGPoint(x: o.x, y: o.y - 3 * s * pen.u), 3 * s, 4 * s, Color(hex: "#F3B36B"))
        pen.ellipse(CGPoint(x: o.x, y: o.y - 2.4 * s * pen.u), 1.6 * s, 2.4 * s, Color(hex: "#FBE2A0"))
    }

    private static func glow(_ pen: IsoPen, z: CGFloat, r: CGFloat, strength: CGFloat) {
        let o = pen.p(0, 0, z)
        pen.c.fill(Path(ellipseIn: CGRect(x: o.x - r * pen.u, y: o.y - r * pen.u, width: 2 * r * pen.u, height: 2 * r * pen.u)),
                   with: .radialGradient(Gradient(colors: [Earthy.goldShine.opacity(Double(strength)), Earthy.goldShine.opacity(0)]),
                                         center: o, startRadius: 0, endRadius: r * pen.u))
    }

    private static func banner(_ pen: IsoPen, z: CGFloat, k: CGFloat, seed: Int) {
        let o = pen.p(0, 0, z)
        pen.rect(-0.4 * k, -10 * k, 0.8 * k, 10 * k, Earthy.woodDeep, at: o)
        let colour = [Earthy.roofLight, Earthy.dome, Earthy.goldDome][abs(seed) % 3]
        pen.fill([CGPoint(x: o.x + 0.4 * k * pen.u, y: o.y - 10 * k * pen.u), CGPoint(x: o.x + 7 * k * pen.u, y: o.y - 8.5 * k * pen.u),
                  CGPoint(x: o.x + 0.4 * k * pen.u, y: o.y - 6 * k * pen.u)], colour, soft: 0.5)
    }

    // MARK: Flourish, forest and extras

    /// Extra flowers and grass tufts scattered across a Place.
    static func flourish(_ pen: IsoPen, count: Int, span: CGFloat, seed: Int) {
        let pts = spiral(count, cap: PlaceGrowth.flourishCap, radius: span * 0.45, seed: seed + 3)
        for (i, p) in ordered(pts) { flower(pen, p.x, p.y, s: 0.8 * scale(span), seed: seed + i) }
    }

    static func forestTree(_ pen: IsoPen, seed: Int) {
        switch seed % 4 {
        case 0: cedar(pen, 0, 0, s: 0.9)
        case 1: palm(pen, 0, 0, s: 0.85)
        default: pen.tree(0, 0, size: 0.6 + CGFloat(seed % 3) * 0.08, fruit: seed % 5 == 0, seed: seed)
        }
    }

    static func extra(_ pen: IsoPen, _ kind: ExtraKind, seed: Int) {
        switch kind {
        case .path:
            patch(pen, radius: 0.28, colour: Earthy.path, shade: Earthy.groundWarm)
        case .fence:
            let wood = Earthy.walls(.wood)
            for i in -2...2 { pen.box(CGFloat(i) * 0.1, 0, hx: 0.015, hy: 0.015, h: 6, wood, soft: 0.3) }
            pen.box(0, 0, hx: 0.22, hy: 0.01, z0: 4, h: 1, wood, soft: 0.3)
        case .bench:
            let wood = Earthy.walls(.wood)
            pen.shadow(0, 0, rx: 6)
            for x in [-0.1, 0.1] { pen.box(CGFloat(x), 0, hx: 0.02, hy: 0.04, h: 3, wood, soft: 0.3) }
            pen.box(0, 0, hx: 0.14, hy: 0.05, z0: 3, h: 1.2, wood, soft: 0.3)
        case .tree:
            pen.tree(0, 0, size: 0.65, fruit: seed % 2 == 0, seed: seed)
        case .lamp:
            lamp(pen, 0, 0, s: 1, glow: 0.45)
        }
    }

    static func extraSize(_ kind: ExtraKind) -> CGSize {
        switch kind {
        case .tree: CGSize(width: 20, height: 34)
        case .lamp: CGSize(width: 12, height: 18)
        default: CGSize(width: 24, height: 10)
        }
    }
}
