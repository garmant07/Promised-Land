import SwiftUI

/// The Library on the island, drawn in code for each stage (see LibraryData.swift): sandstone
/// walls, lavender roofs and domes, book spines in the windows. It gets wider and taller with
/// every stage; small touches (benches, lamps, notes…) appear around it in between. Hand-made art
/// can replace any stage: `bld_library_<stage>` (with `_r0`…`_r3`), see ART_ASSETS.md.
enum LibraryArt {
    /// The stage an item shows (its growth is stage + 1).
    static func stage(of item: Island.Item) -> LibraryStage {
        LibraryStage(rawValue: max(0, min(LibraryStage.grand.rawValue, Int(item.growth.rounded()) - 1))) ?? .hut
    }

    static func touches(of item: Island.Item) -> Set<LibraryTouch> {
        Set(LibraryTouch.allCases.enumerated().filter { item.libraryTouches & (1 << $0.offset) != 0 }.map(\.element))
    }

    /// Roughly what's drawn, in u (for tapping): width and height above the ground point.
    static func size(_ stage: LibraryStage) -> CGSize {
        let w = CGFloat(stage.size) * 44 * 0.92
        let h: CGFloat = [62, 78, 96, 128, 190, 230][stage.rawValue]
        return CGSize(width: w, height: h)
    }

    /// The art-swap image for a stage, if there is one.
    @MainActor
    static func custom(_ stage: LibraryStage, rotation: Int) -> ArtAssets.Art? {
        ArtAssets.image("bld_library_\(stage.rawValue)", rotation: rotation)
    }

    // MARK: Drawing

    /// Draws the Library around its ground point (the middle of its footprint). `item.span` is its
    /// footprint now; an older stage (mid-reveal) is drawn where it stood, at the hut's corner.
    static func draw(_ pen: IsoPen, item: Island.Item) {
        let stage = stage(of: item)
        let touches = touches(of: item)
        let shift = max(0, (item.span - CGFloat(stage.size)) / 2)
        var g = pen.c
        if shift > 0 {
            let o = pen.p(shift, shift)
            g.translateBy(x: o.x, y: o.y)
        }
        let p = IsoPen(c: g, u: pen.u)
        let s = CGFloat(stage.size) / 2
        let detailed = pen.u >= 0.62
        p.shadow(0, 0, rx: s * 30, ry: s * 14)
        // Things behind the building first.
        if touches.contains(.olives) {
            p.tree(-s + 0.35, -s + 0.4, size: 0.7, seed: 3)
            p.tree(-s + 0.4, s - 0.6, size: 0.6, seed: 5)
        }
        switch stage {
        case .hut: hut(p)
        case .room: room(p)
        case .wings: wings(p, glow: true)
        case .upperFloor: upperFloor(p)
        case .tower: tower(p)
        case .grand: grand(p)
        }
        drawTouches(p, touches, half: s, stage: stage)
        if detailed, stage >= .upperFloor { readers(p, half: s, count: stage == .upperFloor ? 2 : 3) }
    }

    private static let walls = Earthy.walls(.cream)
    private static let lavLight = Earthy.dome, lavDark = Color(hex: "#A792C4")
    private static let spines: [Color] = [Earthy.roofLight, Earthy.dome, Earthy.leaf, Color.wheat, Color(hex: "#93AECF")]

    /// Arched windows along a face, lit warmly from inside at later stages, with book spines.
    private static func windowRow(_ p: IsoPen, _ face: IsoPen.Face, x: CGFloat, y: CGFloat, hx: CGFloat, hy: CGFloat,
                                  z: CGFloat, h: CGFloat, count: Int, glow: Bool, door: Bool = false) {
        for i in 0..<count {
            let t = (CGFloat(i) + 0.5) / CGFloat(count)
            let isDoor = door && i == count / 2
            let width: CGFloat = isDoor ? 0.2 : 0.13
            p.arch(face, box: x, y, hx: hx, hy: hy, t: t, z: isDoor ? 0 : z, width: width, h: isDoor ? h * 1.35 + z : h,
                   color: isDoor ? Earthy.woodDeep : glow ? Color(hex: "#F3C979") : Earthy.window)
            guard !isDoor, h > 8 else { continue }
            // Spines on a shelf inside the window.
            let length = face == .left ? 2 * hx : 2 * hy
            let s0 = length * t - width / 2
            for k in 0..<3 {
                let along = s0 + width * (0.18 + CGFloat(k) * 0.28)
                let base: CGPoint = face == .left ? p.p(x - hx + along, y + hy + 0.002, z + 1) : p.p(x + hx + 0.002, y + hy - along, z + 1)
                p.rect(-0.9, -h * 0.42, 1.8, h * 0.42, spines[(i + k) % spines.count], radius: 0.6, at: base)
            }
        }
    }

    /// A small reading hut: one room, one shelf, a lavender roof.
    private static func hut(_ p: IsoPen) {
        p.box(0, 0, hx: 0.55, hy: 0.5, h: 26, walls)
        windowRow(p, .left, x: 0, y: 0, hx: 0.55, hy: 0.5, z: 8, h: 11, count: 3, glow: false, door: true)
        windowRow(p, .right, x: 0, y: 0, hx: 0.55, hy: 0.5, z: 8, h: 11, count: 1, glow: false)
        p.pyramid(0, 0, hx: 0.55, hy: 0.5, z: 26, h: 24, light: lavLight, dark: lavDark)
    }

    /// A bigger room with a pitched roof.
    private static func room(_ p: IsoPen) {
        p.box(0, 0, hx: 0.95, hy: 0.85, h: 32, walls)
        windowRow(p, .left, x: 0, y: 0, hx: 0.95, hy: 0.85, z: 9, h: 14, count: 5, glow: false, door: true)
        windowRow(p, .right, x: 0, y: 0, hx: 0.95, hy: 0.85, z: 9, h: 14, count: 3, glow: false)
        p.gable(0, 0, hx: 0.95, hy: 0.85, z: 32, h: 26, gableEnd: walls.right)
        // Lavender over the terracotta, to keep the Library's colour.
        p.fill([p.p(-1, 0.9, 32), p.p(1, 0.9, 32), p.p(1, 0, 58), p.p(-1, 0, 58)], lavLight)
    }

    /// The main hall with a wing on each front side.
    private static func wings(_ p: IsoPen, glow: Bool) {
        hall(p, x: -0.35, y: -0.35, hx: 0.95, hy: 0.95, h: 40, storeys: 1, glow: glow)
        wing(p, x: -0.35, y: 1.3, hx: 0.9, hy: 0.45, glow: glow)
        wing(p, x: 1.3, y: -0.35, hx: 0.45, hy: 0.9, glow: glow)
    }

    private static func hall(_ p: IsoPen, x: CGFloat, y: CGFloat, hx: CGFloat, hy: CGFloat, h: CGFloat, storeys: Int, glow: Bool) {
        p.box(x, y, hx: hx, hy: hy, h: h, walls)
        let storey = h / CGFloat(storeys)
        for k in 0..<storeys {
            let z = CGFloat(k) * storey + storey * 0.25
            windowRow(p, .left, x: x, y: y, hx: hx, hy: hy, z: z, h: storey * 0.45, count: 5, glow: glow, door: k == 0)
            windowRow(p, .right, x: x, y: y, hx: hx, hy: hy, z: z, h: storey * 0.45, count: 5, glow: glow)
        }
        p.pyramid(x, y, hx: hx, hy: hy, z: h, h: 30, light: lavLight, dark: lavDark)
    }

    private static func wing(_ p: IsoPen, x: CGFloat, y: CGFloat, hx: CGFloat, hy: CGFloat, glow: Bool, h: CGFloat = 26) {
        p.box(x, y, hx: hx, hy: hy, h: h, walls)
        windowRow(p, .left, x: x, y: y, hx: hx, hy: hy, z: 8, h: 11, count: max(1, Int(hx * 4)), glow: glow)
        windowRow(p, .right, x: x, y: y, hx: hx, hy: hy, z: 8, h: 11, count: max(1, Int(hy * 4)), glow: glow)
        p.gable(x, y, hx: hx, hy: hy, z: h, h: 14, gableEnd: walls.right)
    }

    /// Wings, and a second floor on the hall.
    private static func upperFloor(_ p: IsoPen) {
        hall(p, x: -0.5, y: -0.5, hx: 1.2, hy: 1.2, h: 70, storeys: 2, glow: true)
        wing(p, x: -0.5, y: 1.6, hx: 1.15, hy: 0.55, glow: true, h: 30)
        wing(p, x: 1.6, y: -0.5, hx: 0.55, hy: 1.15, glow: true, h: 30)
    }

    /// A tall round-topped reading tower beside the two-storey hall.
    private static func tower(_ p: IsoPen) {
        readingTower(p, x: -1.85, y: 0.9, h: 120)
        hall(p, x: -0.55, y: -0.55, hx: 1.45, hy: 1.45, h: 74, storeys: 2, glow: true)
        wing(p, x: -0.55, y: 1.95, hx: 1.4, hy: 0.6, glow: true, h: 32)
        wing(p, x: 1.95, y: -0.55, hx: 0.6, hy: 1.4, glow: true, h: 32)
    }

    private static func readingTower(_ p: IsoPen, x: CGFloat, y: CGFloat, h: CGFloat, gold: Bool = false) {
        p.box(x, y, hx: 0.42, hy: 0.42, h: h, walls)
        for k in 0..<4 {
            let z = 14 + CGFloat(k) * (h - 20) / 4
            windowRow(p, .left, x: x, y: y, hx: 0.42, hy: 0.42, z: z, h: 12, count: 1, glow: true)
            windowRow(p, .right, x: x, y: y, hx: 0.42, hy: 0.42, z: z, h: 12, count: 1, glow: true)
        }
        p.battlements(x, y, hx: 0.42, hy: 0.42, z: h, walls)
        p.dome(x, y, r: 0.36, z: h, gold: gold)
    }

    /// The grand central library: a great golden dome on a columned hall, two reading towers and
    /// two-storey wings.
    private static func grand(_ p: IsoPen) {
        readingTower(p, x: -2.4, y: 1.1, h: 140, gold: true)
        readingTower(p, x: 1.1, y: -2.4, h: 140, gold: true)
        p.box(-0.6, -0.6, hx: 1.7, hy: 1.7, h: 84, walls)
        for k in 0..<2 {
            let z = CGFloat(k) * 42 + 10
            windowRow(p, .left, x: -0.6, y: -0.6, hx: 1.7, hy: 1.7, z: z, h: 20, count: 7, glow: true, door: k == 0)
            windowRow(p, .right, x: -0.6, y: -0.6, hx: 1.7, hy: 1.7, z: z, h: 20, count: 7, glow: true)
        }
        p.dome(-0.6, -0.6, r: 1.15, z: 84, gold: true, drum: walls)
        // A columned porch at the front.
        p.box(-0.6, 1.35, hx: 1.1, hy: 0.22, z0: 0, h: 4, Earthy.walls(.sand))
        for i in 0..<6 {
            let x = -1.55 + CGFloat(i) * 0.38
            p.box(x, 1.45, hx: 0.05, hy: 0.05, z0: 4, h: 40, walls, soft: 0.4)
        }
        p.box(-0.6, 1.35, hx: 1.12, hy: 0.24, z0: 44, h: 7, walls)
        wing(p, x: -0.6, y: 2.45, hx: 1.6, hy: 0.55, glow: true, h: 40)
        wing(p, x: 2.45, y: -0.6, hx: 0.55, hy: 1.6, glow: true, h: 40)
    }

    // MARK: Touches and readers

    private static func drawTouches(_ p: IsoPen, _ t: Set<LibraryTouch>, half s: CGFloat, stage: LibraryStage) {
        let front = s - 0.3 // just inside the front edges
        if t.contains(.gardenPath) {
            p.fill([p.p(-0.25, front - 0.6), p.p(0.1, front - 0.6), p.p(0.1, s), p.p(-0.25, s)], Earthy.path, soft: 4)
        }
        if t.contains(.flowerPots) {
            for (i, x) in [-s + 0.4, s - 0.5].enumerated() {
                let o = p.p(x, front)
                p.rect(-2.5, -4, 5, 4, Earthy.roofDark, radius: 1, at: o)
                p.ellipse(CGPoint(x: o.x, y: o.y - 6 * p.u), 3.5, 3, i == 0 ? Earthy.roofLight : Earthy.dome)
            }
        }
        if t.contains(.fountain) {
            let o = p.p(s - 0.7, s - 0.6)
            p.ellipse(o, 13, 6.5, Earthy.stoneShade)
            p.ellipse(CGPoint(x: o.x, y: o.y - 1.5 * p.u), 11, 5.2, Earthy.water)
            p.rect(-1.2, -11, 2.4, 10, Earthy.stone, radius: 1, at: o)
            p.ellipse(CGPoint(x: o.x, y: o.y - 12 * p.u), 2.5, 1.6, Earthy.waterShine)
        }
        if t.contains(.bookStack) {
            let o = p.p(0.35, front)
            for k in 0..<4 { p.rect(-3 + CGFloat(k % 2) * 0.6, -2.2 * CGFloat(k + 1), 6, 2, spines[k % spines.count], radius: 0.5, at: o) }
        }
        if t.contains(.bookCart) {
            let o = p.p(front, 0.4)
            p.rect(-5, -7, 10, 5, Earthy.wood, radius: 1, at: o)
            for k in 0..<5 { p.rect(-4.5 + CGFloat(k) * 1.9, -11, 1.6, 4.5, spines[k % spines.count], radius: 0.4, at: o) }
            p.ellipse(CGPoint(x: o.x - 3 * p.u, y: o.y - 1.2 * p.u), 1.6, 1.6, Earthy.woodDeep)
            p.ellipse(CGPoint(x: o.x + 3 * p.u, y: o.y - 1.2 * p.u), 1.6, 1.6, Earthy.woodDeep)
        }
        if t.contains(.bench) { bench(p, x: -s + 0.55, y: front) }
        if t.contains(.writingDesk) {
            let o = p.p(front, -s + 0.6)
            p.rect(-5, -6, 10, 2, Earthy.woodLight, radius: 0.6, at: o)
            p.rect(-4, -4, 1.2, 4, Earthy.woodDark, at: o)
            p.rect(2.8, -4, 1.2, 4, Earthy.woodDark, at: o)
            p.rect(-2.5, -7.4, 5, 1.4, Color.white.opacity(0.9), radius: 0.3, at: o)
            if t.contains(.inkwell) {
                p.ellipse(CGPoint(x: o.x + 3.4 * p.u, y: o.y - 7 * p.u), 0.9, 0.9, Earthy.woodDeep)
                p.c.stroke(Path { $0.move(to: CGPoint(x: o.x + 3.4 * p.u, y: o.y - 7 * p.u)); $0.addLine(to: CGPoint(x: o.x + 5 * p.u, y: o.y - 11 * p.u)) },
                           with: .color(Color.white), lineWidth: 0.8 * p.u)
            }
        }
        if t.contains(.noticeBoard) {
            let o = p.p(-s + 0.35, -0.2)
            p.rect(-0.6, -14, 1.2, 14, Earthy.woodDark, at: o)
            p.rect(-6, -18, 12, 8, Earthy.woodLight, radius: 1, at: o)
            for k in 0..<4 { p.rect(-5 + CGFloat(k % 2) * 5.2, -17.2 + CGFloat(k / 2) * 3.4, 4.4, 2.8, Color.white.opacity(0.92), radius: 0.3, at: o) }
        }
        if t.contains(.noteGarden) {
            for k in 0..<5 {
                let o = p.p(-s + 0.5 + CGFloat(k) * 0.35, s - 0.15)
                p.rect(-0.3, -6, 0.6, 6, Earthy.woodDark, at: o)
                p.rect(-1.8, -8.5, 3.6, 2.6, Color.white.opacity(0.92), radius: 0.3, at: o)
            }
        }
        if t.contains(.doorNote) {
            // A paper note by the door (front-left face).
            let o = p.p(0.25, s - 0.45, 10)
            p.rect(-1.6, -2, 3.2, 3, Color.white.opacity(0.95), radius: 0.3, at: o)
        }
        if t.contains(.lamp) { PlaceArt.lamp(p, -0.6, front, s: 0.9, glow: 0.55) }
        if t.contains(.secondLamp) { PlaceArt.lamp(p, front, -0.6, s: 0.9, glow: 0.55) }
        if t.contains(.window), stage <= .room {
            // A round window high on the right face.
            let o = p.p(s * 0.55, -0.1, stage == .hut ? 20 : 26)
            p.ellipse(o, 2.6, 2.6, Color(hex: "#F3C979"))
        }
    }

    private static func bench(_ p: IsoPen, x: CGFloat, y: CGFloat) {
        let wood = Earthy.walls(.wood)
        p.box(x - 0.1, y, hx: 0.02, hy: 0.04, h: 3, wood, soft: 0.3)
        p.box(x + 0.1, y, hx: 0.02, hy: 0.04, h: 3, wood, soft: 0.3)
        p.box(x, y, hx: 0.14, hy: 0.05, z0: 3, h: 1.2, wood, soft: 0.3)
    }

    /// A few readers sitting outside with open books.
    private static func readers(_ p: IsoPen, half s: CGFloat, count: Int) {
        let spots: [(CGFloat, CGFloat)] = [(-s + 0.9, s - 0.25), (s - 0.25, -s + 1.1), (0.9, s - 0.2)]
        let robes: [Color] = [Earthy.roofLight, Earthy.dome, Earthy.leaf]
        for (i, spot) in spots.prefix(count).enumerated() {
            let o = p.p(spot.0, spot.1)
            p.ellipse(o, 3.4, 1.4, Earthy.shadow)
            p.rect(-2.6, -6, 5.2, 6, robes[i], radius: 2.4, at: o)
            p.ellipse(CGPoint(x: o.x, y: o.y - 9 * p.u), 2.4, 2.4, Color(hex: i % 2 == 0 ? "#DDAE8C" : "#C99474"))
            // An open book on the lap.
            p.fill([CGPoint(x: o.x - 3 * p.u, y: o.y - 4.5 * p.u), CGPoint(x: o.x, y: o.y - 3.6 * p.u),
                    CGPoint(x: o.x + 3 * p.u, y: o.y - 4.5 * p.u), CGPoint(x: o.x + 3 * p.u, y: o.y - 3 * p.u),
                    CGPoint(x: o.x, y: o.y - 2.2 * p.u), CGPoint(x: o.x - 3 * p.u, y: o.y - 3 * p.u)], Color.white, soft: 0.3)
        }
    }
}
