import SwiftUI

// Code-drawn island art, in the "warm earthy, soft isometric" style from the Promised Land
// art direction: no outlines, soft rounded corners, lighter left faces and darker right faces,
// sandstone walls with dark arched windows, terracotta roofs, lavender and golden domes,
// olive "lollipop" trees and soft shadows on sand.
//
// Everything is drawn around an item's ground point. Positions are in grid units (one tile
// is 1 × 1, drawn 44u wide and 22u deep) and heights in units `u`, so art scales with zoom.

/// The art direction's palette.
enum Earthy {
    static let wallLeft = Color(hex: "#F4D6AA"), wallRight = Color(hex: "#E8C192"), wallTop = Color(hex: "#F9E4C0")
    static let window = Color(hex: "#9C6E4E")
    static let roofLight = Color(hex: "#E39A7E"), roofDark = Color(hex: "#C97A60")
    static let dome = Color(hex: "#BFA9DA"), domeShine = Color(hex: "#D7C9EC")
    static let goldDome = Color(hex: "#F0C88C"), goldShine = Color(hex: "#F8DFB2"), goldShade = Color(hex: "#DDAA6E")
    static let gold = Color(hex: "#E1B067")
    static let leaf = Color(hex: "#A9B47C"), leafShade = Color(hex: "#97A26B"), bush = Color(hex: "#B3BE88")
    static let trunk = Color(hex: "#8E6A4C")
    static let woodLight = Color(hex: "#C99466"), wood = Color(hex: "#C08A5C"), woodDark = Color(hex: "#A06A44"), woodDeep = Color(hex: "#8A5A38")
    static let ground = Color(hex: "#F3DFB5"), groundLight = Color(hex: "#F7E7C6"), groundWarm = Color(hex: "#EFD8AA"), path = Color(hex: "#F8EBCD")
    static let strataLeftTop = Color(hex: "#E9C793"), strataLeft = Color(hex: "#D7A973")
    static let strataRightTop = Color(hex: "#DBB37D"), strataRight = Color(hex: "#C4935E")
    static let shadow = Color(hex: "#DCC193")
    static let stone = Color(hex: "#E9D3AA"), stoneShade = Color(hex: "#D9BD8E")
    static let water = Color(hex: "#B9D3DA"), waterShine = Color(hex: "#D5E6EA")
    static let sea = Color(hex: "#BFD9DE"), shallow = Color(hex: "#D3E6E5"), foam = Color(hex: "#F5F1E6")
    static let cloth = Color(hex: "#F1E6D7"), clothShade = Color(hex: "#E2D3BF")
    static let sky = Color(hex: "#FCF3DC")

    struct Walls { let left, right, top: Color }

    static func walls(_ tone: WallTone) -> Walls {
        switch tone {
        case .sand: Walls(left: wallLeft, right: wallRight, top: wallTop)
        case .cream: Walls(left: Color(hex: "#F7E9D2"), right: Color(hex: "#EBD8BD"), top: Color(hex: "#FBF1E0"))
        case .clay: Walls(left: Color(hex: "#EDC3A4"), right: Color(hex: "#DDA987"), top: Color(hex: "#F5D5BC"))
        case .wood: Walls(left: wood, right: woodDark, top: woodLight)
        }
    }
}

/// A drawing helper for isometric shapes around an item's ground point.
struct IsoPen {
    var c: GraphicsContext
    let u: CGFloat

    /// Grid offset (x, y) and height z (in u) to a point.
    func p(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat = 0) -> CGPoint {
        CGPoint(x: (x - y) * 22 * u, y: ((x + y) * 11 - z) * u)
    }

    /// Fills a shape with soft rounded corners (a same-colour round-joined edge, as in the art).
    func fill(_ pts: [CGPoint], _ color: Color, soft: CGFloat = 1) {
        let path = Path { $0.addLines(pts); $0.closeSubpath() }
        c.fill(path, with: .color(color))
        if soft > 0 { c.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: soft * u, lineJoin: .round)) }
    }

    func ellipse(_ centre: CGPoint, _ rx: CGFloat, _ ry: CGFloat, _ color: Color) {
        c.fill(Path(ellipseIn: CGRect(x: centre.x - rx * u, y: centre.y - ry * u, width: 2 * rx * u, height: 2 * ry * u)), with: .color(color))
    }

    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color, radius: CGFloat = 0, at o: CGPoint = .zero) {
        c.fill(Path(roundedRect: CGRect(x: o.x + x * u, y: o.y + y * u, width: w * u, height: h * u), cornerRadius: radius * u),
               with: .color(color))
    }

    /// A soft shadow on the ground (no blur needed: a fading ellipse).
    func shadow(_ x: CGFloat, _ y: CGFloat, rx: CGFloat, ry: CGFloat? = nil) {
        let o = p(x, y)
        let ry = ry ?? rx * 0.45
        let rect = CGRect(x: o.x - rx * u, y: o.y - ry * u, width: 2 * rx * u, height: 2 * ry * u)
        c.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [Earthy.shadow.opacity(0.8), Earthy.shadow.opacity(0)]),
            center: o, startRadius: 0, endRadius: rx * u))
    }

    // MARK: Boxes and roofs

    /// An upright box centred at (x, y), half-sizes hx × hy in grid units, from z0 up by h.
    func box(_ x: CGFloat, _ y: CGFloat, hx: CGFloat, hy: CGFloat, z0: CGFloat = 0, h: CGFloat, _ w: Earthy.Walls, soft: CGFloat = 1) {
        let a = (x - hx, y + hy), b = (x + hx, y + hy), cc = (x + hx, y - hy), d = (x - hx, y - hy)
        fill([p(a.0, a.1, z0), p(b.0, b.1, z0), p(b.0, b.1, z0 + h), p(a.0, a.1, z0 + h)], w.left, soft: soft)
        fill([p(b.0, b.1, z0), p(cc.0, cc.1, z0), p(cc.0, cc.1, z0 + h), p(b.0, b.1, z0 + h)], w.right, soft: soft)
        fill([p(a.0, a.1, z0 + h), p(b.0, b.1, z0 + h), p(cc.0, cc.1, z0 + h), p(d.0, d.1, z0 + h)], w.top, soft: soft)
    }

    enum Face { case left, right }

    /// An arched window or door on a box face. `t` runs 0…1 along the face (left to right on
    /// screen); `width` is in grid units, `z` and `h` in u.
    func arch(_ face: Face, box x: CGFloat, _ y: CGFloat, hx: CGFloat, hy: CGFloat, t: CGFloat, z: CGFloat,
              width: CGFloat, h: CGFloat, color: Color = Earthy.window) {
        func at(_ s: CGFloat, _ zz: CGFloat) -> CGPoint {
            switch face {
            case .left: p(x - hx + s, y + hy + 0.001, zz)
            case .right: p(x + hx + 0.001, y + hy - s, zz)
            }
        }
        let length = face == .left ? 2 * hx : 2 * hy
        let s0 = length * t - width / 2, s1 = s0 + width
        let r = width / 2, rz = r * 22 // the arch's height in u, roughly round on screen
        var pts = [at(s0, z), at(s0, z + h - rz)]
        for i in 1..<8 {
            let a = CGFloat.pi * CGFloat(i) / 8
            pts.append(at(s0 + r - cos(a) * r, z + h - rz + sin(a) * rz))
        }
        pts += [at(s1, z + h - rz), at(s1, z)]
        fill(pts, color, soft: 0)
    }

    /// Rows of arched windows on both visible faces of a box.
    func windows(box x: CGFloat, _ y: CGFloat, hx: CGFloat, hy: CGFloat, z0: CGFloat = 0, storeys: Int, storey: CGFloat,
                 door: Bool = true) {
        for s in 0..<storeys {
            let z = z0 + CGFloat(s) * storey + storey * 0.22
            let h = storey * 0.6
            let leftCount = max(1, Int((2 * hx) / 0.26)), rightCount = max(1, Int((2 * hy) / 0.3))
            for i in 0..<leftCount {
                let t = (CGFloat(i) + 0.5) / CGFloat(leftCount)
                let isDoor = door && s == 0 && i == leftCount / 2
                arch(.left, box: x, y, hx: hx, hy: hy, t: t, z: isDoor ? z0 : z,
                     width: min(0.13, 1.4 * hx / CGFloat(leftCount)), h: isDoor ? storey * 0.78 : h)
            }
            for i in 0..<rightCount {
                let t = (CGFloat(i) + 0.5) / CGFloat(rightCount)
                arch(.right, box: x, y, hx: hx, hy: hy, t: t, z: z, width: min(0.12, 1.4 * hy / CGFloat(rightCount)), h: h)
            }
        }
    }

    /// A four-sided pointed roof; returns the apex height.
    @discardableResult
    func pyramid(_ x: CGFloat, _ y: CGFloat, hx: CGFloat, hy: CGFloat, z: CGFloat, h: CGFloat,
                 light: Color = Earthy.roofLight, dark: Color = Earthy.roofDark) -> CGFloat {
        let o: CGFloat = 0.05 // eaves
        let a = p(x - hx - o, y + hy + o, z), b = p(x + hx + o, y + hy + o, z)
        let cc = p(x + hx + o, y - hy - o, z), d = p(x - hx - o, y - hy - o, z)
        let apex = p(x, y, z + h)
        fill([d, a, apex], light)
        fill([cc, d, apex], dark)
        fill([a, b, apex], light)
        fill([b, cc, apex], dark)
        return z + h
    }

    /// A pitched roof with its ridge along x; returns the ridge height.
    @discardableResult
    func gable(_ x: CGFloat, _ y: CGFloat, hx: CGFloat, hy: CGFloat, z: CGFloat, h: CGFloat, gableEnd: Color) -> CGFloat {
        let o: CGFloat = 0.05
        let r1 = p(x - hx - o, y, z + h), r2 = p(x + hx + o, y, z + h)
        fill([p(x - hx - o, y - hy - o, z), p(x + hx + o, y - hy - o, z), r2, r1], Earthy.roofDark)
        fill([p(x - hx - o, y + hy + o, z), p(x + hx + o, y + hy + o, z), r2, r1], Earthy.roofLight)
        fill([p(x + hx, y + hy, z), p(x + hx, y - hy, z), p(x + hx, y, z + h)], gableEnd)
        return z + h
    }

    /// A dome on a short drum; returns the top height.
    @discardableResult
    func dome(_ x: CGFloat, _ y: CGFloat, r: CGFloat, z: CGFloat, gold: Bool = false, drum: Earthy.Walls? = nil) -> CGFloat {
        let rx = r * 31, ry = r * 15.5 // a circle of radius r grid units, on screen
        var base = z
        if let drum {
            let o = p(x, y, z), dh: CGFloat = 5
            rect(-rx * 0.82, -dh - 0.1, rx * 1.64, dh, drum.left, at: o)
            rect(0, -dh - 0.1, rx * 0.82, dh, drum.right, at: o)
            ellipse(o, rx * 0.82, ry * 0.82, drum.right)
            ellipse(CGPoint(x: o.x, y: o.y - dh * u), rx * 0.82, ry * 0.82, drum.top)
            for i in 0..<3 {
                let dx = (CGFloat(i) - 1) * rx * 0.45
                rect(dx - 1, -dh + 1.2, 2, 3, Earthy.window, radius: 1, at: o)
            }
            base = z + dh
        }
        let o = p(x, y, base)
        let h = rx * 1.05
        let k: CGFloat = 0.5523
        let path = Path { pp in
            pp.move(to: CGPoint(x: o.x - rx * u, y: o.y))
            pp.addCurve(to: CGPoint(x: o.x, y: o.y - h * u), control1: CGPoint(x: o.x - rx * u, y: o.y - h * k * u),
                        control2: CGPoint(x: o.x - rx * k * u, y: o.y - h * u))
            pp.addCurve(to: CGPoint(x: o.x + rx * u, y: o.y), control1: CGPoint(x: o.x + rx * k * u, y: o.y - h * u),
                        control2: CGPoint(x: o.x + rx * u, y: o.y - h * k * u))
            pp.addCurve(to: CGPoint(x: o.x - rx * u, y: o.y), control1: CGPoint(x: o.x + rx * u, y: o.y + ry * 1.3 * u),
                        control2: CGPoint(x: o.x - rx * u, y: o.y + ry * 1.3 * u))
        }
        c.fill(path, with: .color(gold ? Earthy.goldDome : Earthy.dome))
        // Shine, upper left.
        let shine = Path { pp in
            pp.move(to: CGPoint(x: o.x - rx * 0.6 * u, y: o.y - h * 0.45 * u))
            pp.addQuadCurve(to: CGPoint(x: o.x + rx * 0.05 * u, y: o.y - h * 0.86 * u),
                            control: CGPoint(x: o.x - rx * 0.5 * u, y: o.y - h * 0.9 * u))
        }
        c.stroke(shine, with: .color(gold ? Earthy.goldShine : Earthy.domeShine), style: StrokeStyle(lineWidth: max(1, rx * 0.16) * u, lineCap: .round))
        if gold {
            let lower = Path { pp in
                pp.move(to: CGPoint(x: o.x - rx * 0.92 * u, y: o.y + ry * 0.2 * u))
                pp.addQuadCurve(to: CGPoint(x: o.x + rx * 0.92 * u, y: o.y + ry * 0.2 * u), control: CGPoint(x: o.x, y: o.y + ry * 1.2 * u))
            }
            c.stroke(lower, with: .color(Earthy.goldShade.opacity(0.6)), style: StrokeStyle(lineWidth: rx * 0.14 * u, lineCap: .round))
        }
        return base + h
    }

    /// Small battlements along the front edges of a flat top.
    func battlements(_ x: CGFloat, _ y: CGFloat, hx: CGFloat, hy: CGFloat, z: CGFloat, _ w: Earthy.Walls) {
        let n = max(2, Int(2 * hx / 0.16)), m = max(2, Int(2 * hy / 0.16))
        let s: CGFloat = 0.045
        for i in 0..<m { // back-right edge first, so the front ones overlap
            let yy = y + hy - (CGFloat(i) + 0.5) * 2 * hy / CGFloat(m)
            box(x + hx - s, yy, hx: s, hy: s, z0: z, h: 3.2, w, soft: 0.4)
        }
        for i in 0..<n {
            let xx = x - hx + (CGFloat(i) + 0.5) * 2 * hx / CGFloat(n)
            box(xx, y + hy - s, hx: s, hy: s, z0: z, h: 3.2, w, soft: 0.4)
        }
    }

    /// A cone (tent); returns the apex height.
    @discardableResult
    func cone(_ x: CGFloat, _ y: CGFloat, r: CGFloat, z: CGFloat = 0, h: CGFloat, light: Color, dark: Color) -> CGFloat {
        let o = p(x, y, z), rx = r * 31, ry = r * 15.5
        let apex = p(x, y, z + h)
        ellipse(o, rx, ry, dark)
        fill([CGPoint(x: o.x - rx * u, y: o.y), apex, CGPoint(x: o.x, y: o.y + ry * u)], light)
        fill([CGPoint(x: o.x, y: o.y + ry * u), apex, CGPoint(x: o.x + rx * u, y: o.y)], dark)
        return z + h
    }

    /// An olive-style "lollipop" tree.
    func tree(_ x: CGFloat, _ y: CGFloat, size s: CGFloat = 1, fruit: Bool = false, seed: Int = 0) {
        let o = p(x, y)
        shadow(x, y, rx: 8 * s)
        rect(-1.5 * s, -16 * s, 3 * s, 16 * s, Earthy.trunk, radius: 1.5 * s, at: o)
        let centre = CGPoint(x: o.x, y: o.y - 22 * s * u)
        ellipse(CGPoint(x: centre.x + 1.2 * s * u, y: centre.y + 0.8 * s * u), 9 * s, 13 * s, Earthy.leafShade)
        ellipse(centre, 9 * s, 13 * s, Earthy.leaf)
        if fruit {
            for i in 0..<7 {
                let a = CGFloat(i) * 2.3 + CGFloat(seed % 5), r = 3 + CGFloat(i % 3) * 2
                ellipse(CGPoint(x: centre.x + cos(a) * r * 1.1 * s * u, y: centre.y + sin(a) * r * 1.4 * s * u),
                        1.7 * s, 1.7 * s, i % 2 == 0 ? Earthy.roofLight : Earthy.gold)
            }
        }
    }
}

// MARK: - Buildings

/// Draws a book's building from its `BuildingSpec`.
enum BuildingArt {
    static let storey: CGFloat = 11.5

    /// The main body's half-sizes, in grid units.
    static func body(_ spec: BuildingSpec) -> (hx: CGFloat, hy: CGFloat) {
        let w: CGFloat = [0.3, 0.37, 0.45][max(0, min(2, spec.width - 1))]
        switch spec.family {
        case .hall: return (w * 1.3, w * 0.8)
        case .tower, .lighthouse: return (w * 0.6, w * 0.6)
        case .temple: return (w * 1.15, w * 0.85)
        default: return (w, w)
        }
    }

    /// Storeys drawn: the spec's, plus one per full reread (at most three extra, so it stays on screen).
    static func storeys(_ spec: BuildingSpec, extraFloors: Int) -> Int { spec.storeys + min(3, max(0, extraFloors)) }

    /// Rough height of the finished building in u (for tap targets).
    static func height(_ spec: BuildingSpec, built: Bool, extraFloors: Int) -> CGFloat {
        guard built else { return storey * CGFloat(spec.storeys) * 0.6 + 10 }
        let s = CGFloat(storeys(spec, extraFloors: extraFloors))
        let body = body(spec)
        let roof: CGFloat = switch spec.roof {
        case .pyramid: 16
        case .spire: 28
        case .dome, .goldDome: body.hx * 32 + 6
        case .tent: 20
        case .gable: 12
        case .flat, .crenellated: 4
        }
        let crest: CGFloat = spec.crest == .none ? 0 : 8
        let bodyH: CGFloat = switch spec.family {
        case .tower, .lighthouse: s * storey * 1.25
        case .ziggurat: (s + 1) * storey * 0.8
        case .pavilion: 14 + s * 6
        case .garden: s * storey * 0.8 + 18
        case .mountain: 22 + s * storey
        case .harbour, .well: s * storey
        case .gate: s * storey + 8
        default: s * storey
        }
        return bodyH + roof + crest
    }

    /// Half the drawn width in grid units (screen x extent is ±(hx + hy) × 22u).
    static func halfSpan(_ spec: BuildingSpec) -> CGFloat {
        let b = body(spec)
        let wings: CGFloat = spec.wings > 0 ? 0.3 : 0
        switch spec.family {
        case .fort, .garden, .gate, .harbour, .well, .mountain, .pavilion: return max(b.hx, b.hy) * 1.25 + 0.45 + wings
        default: return (b.hx + b.hy) / 2 + 0.05 + wings
        }
    }

    /// - Parameters:
    ///   - progress: chapters read (distinct), out of `total`.
    ///   - extraFloors: full rereads beyond the first (each adds a floor).
    static func draw(_ pen: IsoPen, spec: BuildingSpec, progress: Int, total: Int, extraFloors: Int, seed: Int) {
        let built = total > 0 && progress >= total
        let walls = Earthy.walls(spec.walls)
        let b = body(spec)
        pen.shadow(0.1, 0.1, rx: (b.hx + b.hy) * 26 + 10)
        guard built else {
            foundations(pen, spec: spec, fraction: total > 0 ? CGFloat(progress) / CGFloat(total) : 0, walls: walls)
            return
        }
        let s = storeys(spec, extraFloors: extraFloors)
        wings(pen, spec: spec, walls: walls)
        let top: (x: CGFloat, y: CGFloat, z: CGFloat)
        switch spec.family {
        case .hall, .house, .temple:
            if spec.family == .temple {
                pen.box(0, 0, hx: b.hx + 0.12, hy: b.hy + 0.12, h: 3, Earthy.Walls(left: Earthy.stone, right: Earthy.stoneShade, top: walls.top))
            }
            let z0: CGFloat = spec.family == .temple ? 3 : 0
            pen.box(0, 0, hx: b.hx, hy: b.hy, z0: z0, h: CGFloat(s) * storey, walls)
            pen.windows(box: 0, 0, hx: b.hx, hy: b.hy, z0: z0, storeys: s, storey: storey, door: spec.family != .temple)
            if spec.family == .temple { columns(pen, hx: b.hx, hy: b.hy, z0: z0, h: CGFloat(s) * storey, walls: walls) }
            top = (0, 0, roof(pen, spec, hx: b.hx, hy: b.hy, z: z0 + CGFloat(s) * storey, walls: walls))
        case .tower:
            let h = CGFloat(s) * storey * 1.25
            pen.box(0, 0, hx: b.hx, hy: b.hy, h: h, walls)
            for i in 0..<s {
                let z = CGFloat(i) * storey * 1.25 + storey * 0.35
                pen.arch(.left, box: 0, 0, hx: b.hx, hy: b.hy, t: 0.5, z: z, width: 0.1, h: storey * 0.6)
                if i % 2 == 0 { pen.arch(.right, box: 0, 0, hx: b.hx, hy: b.hy, t: 0.5, z: z, width: 0.09, h: storey * 0.6) }
            }
            top = (0, 0, roof(pen, spec, hx: b.hx, hy: b.hy, z: h, walls: walls))
        case .lighthouse:
            let h = CGFloat(s) * storey * 1.25
            let o = pen.p(0, 0), rx = b.hx * 31, ry = b.hx * 15.5
            pen.rect(-rx, -h, rx, h, walls.left, at: o)
            pen.rect(0, -h, rx, h, walls.right, at: o)
            pen.ellipse(o, rx, ry, walls.right)
            for i in stride(from: 1, to: s, by: 1) {
                pen.rect(-rx, -CGFloat(i) * storey * 1.25 - 2, rx * 2, 2.5, Earthy.roofLight.opacity(0.8), at: o)
            }
            pen.ellipse(CGPoint(x: o.x, y: o.y - h * pen.u), rx, ry, walls.top)
            pen.ellipse(CGPoint(x: o.x, y: o.y - (h + 4) * pen.u), rx * 0.7, ry * 0.7, Earthy.gold.opacity(0.45))
            pen.rect(-rx * 0.6, -h - 7, rx * 1.2, 7, Earthy.goldShine, radius: 2, at: o)
            pen.arch(.left, box: 0, 0, hx: b.hx * 0.7, hy: b.hy * 0.7, t: 0.5, z: 0, width: 0.1, h: storey * 0.8)
            top = (0, 0, pen.dome(0, 0, r: b.hx * 0.75, z: h + 7, gold: spec.roof == .goldDome))
        case .ziggurat:
            var z: CGFloat = 0
            let levels = s + 1
            for i in 0..<levels {
                let k = 1 - CGFloat(i) * 0.7 / CGFloat(levels)
                let h = storey * 0.8
                pen.box(0, 0, hx: b.hx * k, hy: b.hy * k, z0: z, h: h, walls)
                pen.arch(.left, box: 0, 0, hx: b.hx * k, hy: b.hy * k, t: 0.5, z: z + 1, width: 0.08, h: h * 0.7)
                z += h
            }
            let k = 1 - CGFloat(levels - 1) * 0.7 / CGFloat(levels)
            top = (0, 0, roof(pen, spec, hx: b.hx * k, hy: b.hy * k, z: z, walls: walls))
        case .fort:
            let h = CGFloat(s) * storey * 0.8 + 4, r = b.hx * 1.25, t: CGFloat = 0.07
            // Back walls, then the keep, then the front walls and corner towers.
            pen.box(0, -r + t, hx: r, hy: t, h: h, walls)
            pen.box(-r + t, 0, hx: t, hy: r, h: h, walls)
            corner(pen, -r, -r, h: h + 6, walls: walls)
            pen.box(0, 0, hx: r * 0.4, hy: r * 0.4, h: h + 6, walls)
            pen.battlements(0, 0, hx: r * 0.4, hy: r * 0.4, z: h + 6, walls)
            pen.box(r - t, 0, hx: t, hy: r, h: h, walls)
            pen.box(0, r - t, hx: r, hy: t, h: h, walls)
            pen.arch(.left, box: 0, r - t, hx: r, hy: t, t: 0.5, z: 0, width: 0.18, h: h * 0.75)
            corner(pen, r, -r, h: h + 6, walls: walls)
            corner(pen, -r, r, h: h + 6, walls: walls)
            corner(pen, r, r, h: h + 6, walls: walls)
            if spec.roof != .crenellated && spec.roof != .flat {
                top = (0, 0, roof(pen, spec, hx: r * 0.4, hy: r * 0.4, z: h + 6, walls: walls))
            } else {
                top = (r, r, h + 9)
            }
        case .gate:
            let h = CGFloat(s) * storey + 8, r = b.hx * 1.1, tw: CGFloat = 0.2
            pen.box(-r, 0, hx: tw, hy: tw, h: h, walls)
            pen.box(0, 0, hx: r - tw, hy: tw * 0.8, z0: 0, h: h * 0.7, walls)
            pen.arch(.left, box: 0, 0, hx: r - tw, hy: tw * 0.8, t: 0.5, z: 0, width: 0.26, h: h * 0.55)
            pen.box(r, 0, hx: tw, hy: tw, h: h, walls)
            for x in [-r, r] {
                pen.arch(.left, box: x, 0, hx: tw, hy: tw, t: 0.5, z: h * 0.55, width: 0.08, h: storey * 0.6)
                _ = roof(pen, spec, hx: tw, hy: tw, z: h, walls: walls)
            }
            top = (0, 0, h * 0.7 + 2)
        case .pavilion:
            // The main tent, with smaller ones behind it for wings and extra floors.
            let extra = min(5, spec.wings + s - 1)
            let tents = [(x: CGFloat(0), y: CGFloat(0), r: b.hx * 1.1)] + (0..<extra).map { i in
                (x: CGFloat(-0.62 + Double(i % 3) * 0.5), y: CGFloat(-0.62 - Double(i / 3) * 0.3), r: b.hx * 0.6)
            }
            for t in tents.dropFirst() {
                pen.cone(t.x, t.y, r: t.r, h: 14, light: Earthy.cloth, dark: Earthy.clothShade)
            }
            let colours: [(Color, Color)] = [(Earthy.roofLight, Earthy.roofDark), (Earthy.cloth, Earthy.clothShade), (Earthy.dome, Color(hex: "#A792C4"))]
            let (light, dark) = colours[seed % colours.count]
            top = (0, 0, pen.cone(0, 0, r: tents[0].r, h: 16 + CGFloat(s) * 6, light: light, dark: dark))
            if spec.crest == .flame { fence(pen, r: b.hx * 1.6) }
        case .garden:
            let r = b.hx * 1.3
            pen.ellipse(pen.p(0, 0), r * 31, r * 15.5, Earthy.groundWarm)
            let trees: [(CGFloat, CGFloat)] = [(-r * 0.7, -r * 0.5), (r * 0.5, -r * 0.75), (-r * 0.8, r * 0.45)]
            for (x, y) in trees { pen.tree(x, y, size: 0.75) }
            let gz = CGFloat(s) * storey * 0.8
            let gw = Earthy.walls(.cream)
            for (x, y) in [(-0.14, -0.14), (0.14, -0.14), (-0.14, 0.14), (0.14, 0.14)] {
                pen.box(x * b.hx * 3, y * b.hx * 3, hx: 0.03, hy: 0.03, h: gz, gw, soft: 0.4)
            }
            top = (0, 0, roof(pen, spec, hx: b.hx * 0.5, hy: b.hx * 0.5, z: gz, walls: gw))
            pen.tree(r * 0.75, r * 0.6, size: 0.7)
            if spec.crest == .grapes || spec.theme.contains(.vine) { vines(pen, r: r) }
            fence(pen, r: r * 1.25)
        case .harbour:
            let o = pen.p(b.hx * 1.2, 0)
            pen.ellipse(o, b.hx * 40, b.hx * 20, Earthy.water)
            pen.ellipse(CGPoint(x: o.x - 4 * pen.u, y: o.y - 2 * pen.u), b.hx * 22, b.hx * 8, Earthy.waterShine)
            for i in 0..<4 { // a jetty
                pen.box(b.hx * 0.6 + CGFloat(i) * 0.14, b.hx * 0.3, hx: 0.07, hy: 0.09, h: 1.5,
                        Earthy.Walls(left: Earthy.wood, right: Earthy.woodDark, top: Earthy.woodLight), soft: 0.3)
            }
            boat(pen, x: b.hx * 1.45, y: -b.hx * 0.25, size: 1)
            let hx = b.hx * 0.6
            pen.box(-b.hx * 0.4, -b.hx * 0.2, hx: hx, hy: hx, h: CGFloat(s) * storey, walls)
            pen.windows(box: -b.hx * 0.4, -b.hx * 0.2, hx: hx, hy: hx, storeys: s, storey: storey)
            top = (-b.hx * 0.4, -b.hx * 0.2, roof(pen, spec, hx: hx, hy: hx, x: -b.hx * 0.4, y: -b.hx * 0.2, z: CGFloat(s) * storey, walls: walls))
        case .well:
            let r = b.hx * 1.2
            pen.fill([pen.p(-r, -r), pen.p(r, -r), pen.p(r, r), pen.p(-r, r)], Earthy.path, soft: 2)
            let hx = b.hx * 0.55
            pen.box(-r * 0.45, -r * 0.45, hx: hx, hy: hx, h: CGFloat(s) * storey, walls)
            pen.windows(box: -r * 0.45, -r * 0.45, hx: hx, hy: hx, storeys: s, storey: storey)
            _ = roof(pen, spec, hx: hx, hy: hx, x: -r * 0.45, y: -r * 0.45, z: CGFloat(s) * storey, walls: walls)
            wellShape(pen, x: r * 0.35, y: r * 0.35, size: 1.2)
            top = (-r * 0.45, -r * 0.45, CGFloat(s) * storey + 14)
        case .mountain:
            let r = b.hx * 1.35, hh = 22 + CGFloat(s) * storey
            let o = pen.p(0, 0)
            let hill = Path { pp in
                pp.move(to: CGPoint(x: o.x - r * 31 * pen.u, y: o.y))
                pp.addCurve(to: CGPoint(x: o.x, y: o.y - hh * pen.u),
                            control1: CGPoint(x: o.x - r * 20 * pen.u, y: o.y - hh * 0.5 * pen.u),
                            control2: CGPoint(x: o.x - r * 12 * pen.u, y: o.y - hh * pen.u))
                pp.addCurve(to: CGPoint(x: o.x + r * 31 * pen.u, y: o.y),
                            control1: CGPoint(x: o.x + r * 12 * pen.u, y: o.y - hh * pen.u),
                            control2: CGPoint(x: o.x + r * 20 * pen.u, y: o.y - hh * 0.5 * pen.u))
                pp.addQuadCurve(to: CGPoint(x: o.x - r * 31 * pen.u, y: o.y), control: CGPoint(x: o.x, y: o.y + r * 18 * pen.u))
            }
            pen.c.fill(hill, with: .color(Color(hex: "#E2C08E")))
            let shade = Path { pp in
                pp.move(to: CGPoint(x: o.x, y: o.y - hh * pen.u))
                pp.addCurve(to: CGPoint(x: o.x + r * 31 * pen.u, y: o.y),
                            control1: CGPoint(x: o.x + r * 12 * pen.u, y: o.y - hh * pen.u),
                            control2: CGPoint(x: o.x + r * 20 * pen.u, y: o.y - hh * 0.5 * pen.u))
                pp.addQuadCurve(to: CGPoint(x: o.x + r * 4 * pen.u, y: o.y + r * 12 * pen.u), control: CGPoint(x: o.x + r * 20 * pen.u, y: o.y + r * 10 * pen.u))
                pp.addQuadCurve(to: CGPoint(x: o.x, y: o.y - hh * pen.u), control: CGPoint(x: o.x + r * 8 * pen.u, y: o.y - hh * 0.4 * pen.u))
            }
            pen.c.fill(shade, with: .color(Color(hex: "#CFA875")))
            pen.ellipse(CGPoint(x: o.x - r * 10 * pen.u, y: o.y - hh * 0.35 * pen.u), r * 5, r * 2.5, Earthy.leaf.opacity(0.8))
            pen.ellipse(CGPoint(x: o.x + r * 13 * pen.u, y: o.y - hh * 0.2 * pen.u), r * 4, r * 2, Earthy.leaf.opacity(0.8))
            // A small shrine on the summit.
            let sx: CGFloat = 0.13
            let base = hh - 3
            pen.box(0, 0, hx: sx, hy: sx, z0: base, h: 6, walls, soft: 0.6)
            top = (0, 0, roof(pen, spec, hx: sx, hy: sx, z: base + 6, walls: walls))
        }
        crest(pen, spec.crest, at: pen.p(top.x, top.y, top.z))
    }

    /// Roof by kind; returns the top height.
    private static func roof(_ pen: IsoPen, _ spec: BuildingSpec, hx: CGFloat, hy: CGFloat, x: CGFloat = 0, y: CGFloat = 0,
                             z: CGFloat, walls: Earthy.Walls) -> CGFloat {
        switch spec.roof {
        case .pyramid: return pen.pyramid(x, y, hx: hx, hy: hy, z: z, h: 10 + (hx + hy) * 10)
        case .spire: return pen.pyramid(x, y, hx: hx, hy: hy, z: z, h: 28)
        case .gable: return pen.gable(x, y, hx: hx, hy: hy, z: z, h: 6 + hy * 10, gableEnd: walls.right)
        case .dome: return pen.dome(x, y, r: min(hx, hy) * 0.8, z: z, drum: hx > 0.3 ? walls : nil)
        case .goldDome: return pen.dome(x, y, r: min(hx, hy) * 0.8, z: z, gold: true, drum: hx > 0.3 ? walls : nil)
        case .tent: return pen.cone(x, y, r: min(hx, hy) * 1.1, z: z, h: 14, light: Earthy.cloth, dark: Earthy.clothShade)
        case .crenellated:
            pen.battlements(x, y, hx: hx, hy: hy, z: z, walls)
            return z + 3
        case .flat:
            pen.box(x, y, hx: hx * 0.94, hy: hy * 0.94, z0: z, h: 1.2, Earthy.Walls(left: walls.left, right: walls.right, top: Earthy.wallTop))
            return z + 1
        }
    }

    private static func wings(_ pen: IsoPen, spec: BuildingSpec, walls: Earthy.Walls) {
        guard spec.wings > 0, ![.fort, .gate, .pavilion, .garden, .mountain].contains(spec.family) else { return }
        let b = body(spec)
        let wing: CGFloat = 0.22
        if spec.wings >= 2 { // behind on the right
            pen.box(0.05, -b.hy - wing * 0.7, hx: b.hx * 0.6, hy: wing, h: storey * 1.1, walls)
            pen.arch(.right, box: 0.05, -b.hy - wing * 0.7, hx: b.hx * 0.6, hy: wing, t: 0.5, z: 2, width: 0.08, h: 6)
            pen.pyramid(0.05, -b.hy - wing * 0.7, hx: b.hx * 0.6, hy: wing, z: storey * 1.1, h: 6)
        }
        // Behind on the left.
        pen.box(-b.hx - wing * 0.7, 0.05, hx: wing, hy: b.hy * 0.6, h: storey * 1.1, walls)
        pen.arch(.left, box: -b.hx - wing * 0.7, 0.05, hx: wing, hy: b.hy * 0.6, t: 0.5, z: 2, width: 0.08, h: 6)
        pen.box(-b.hx - wing * 0.7, 0.05, hx: wing * 0.95, hy: b.hy * 0.57, z0: storey * 1.1, h: 1.2, walls)
    }

    private static func columns(_ pen: IsoPen, hx: CGFloat, hy: CGFloat, z0: CGFloat, h: CGFloat, walls: Earthy.Walls) {
        let n = max(4, Int(2 * hx / 0.2))
        for i in 0..<n {
            let x = -hx + (CGFloat(i) + 0.5) * 2 * hx / CGFloat(n)
            let o = pen.p(x, hy + 0.08, z0)
            pen.rect(-1.6, -h, 3.2, h, Earthy.cloth, radius: 1.6, at: o)
            pen.rect(0, -h, 1.6, h, Earthy.clothShade, radius: 0.8, at: o)
        }
    }

    private static func corner(_ pen: IsoPen, _ x: CGFloat, _ y: CGFloat, h: CGFloat, walls: Earthy.Walls) {
        pen.box(x, y, hx: 0.12, hy: 0.12, h: h, walls)
        pen.battlements(x, y, hx: 0.12, hy: 0.12, z: h, walls)
    }

    private static func fence(_ pen: IsoPen, r: CGFloat) {
        let posts = 9
        for i in 0..<posts { // front two edges only, so it never hides the building
            let t = CGFloat(i) / CGFloat(posts - 1)
            for (x, y) in [(-r + 2 * r * t, r), (r, r - 2 * r * t)] {
                let o = pen.p(x, y)
                pen.rect(-0.8, -6, 1.6, 6, Earthy.woodDark, radius: 0.8, at: o)
            }
        }
        pen.c.stroke(Path { pp in pp.move(to: pen.p(-r, r, 4)); pp.addLine(to: pen.p(r, r, 4)); pp.addLine(to: pen.p(r, -r, 4)) },
                     with: .color(Earthy.wood), style: StrokeStyle(lineWidth: 1.1 * pen.u, lineCap: .round, lineJoin: .round))
    }

    private static func vines(_ pen: IsoPen, r: CGFloat) {
        for row in 0..<2 {
            let y = r * (0.2 + CGFloat(row) * 0.45)
            for i in 0..<4 {
                let o = pen.p(-r * 0.6 + CGFloat(i) * r * 0.35, y)
                pen.rect(-0.6, -9, 1.2, 9, Earthy.woodDark, at: o)
                pen.ellipse(CGPoint(x: o.x, y: o.y - 9 * pen.u), 4, 3, Earthy.leaf)
                pen.ellipse(CGPoint(x: o.x + 1.5 * pen.u, y: o.y - 6.5 * pen.u), 1.4, 1.8, Earthy.dome)
            }
        }
    }

    static func boat(_ pen: IsoPen, x: CGFloat, y: CGFloat, size s: CGFloat) {
        let a = pen.p(x - 0.22 * s, y + 0.06 * s), b = pen.p(x + 0.22 * s, y - 0.06 * s)
        let u = pen.u
        let hull = Path { pp in
            pp.move(to: CGPoint(x: a.x - 3 * s * u, y: a.y - 5 * s * u))
            pp.addLine(to: CGPoint(x: b.x + 3 * s * u, y: b.y - 5 * s * u))
            pp.addQuadCurve(to: CGPoint(x: a.x - 3 * s * u, y: a.y - 5 * s * u), control: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + 6 * s * u))
        }
        pen.c.fill(hull, with: .color(Earthy.woodDark))
        pen.c.fill(Path { pp in
            pp.move(to: CGPoint(x: a.x - 2 * s * u, y: a.y - 5 * s * u))
            pp.addLine(to: CGPoint(x: b.x + 2 * s * u, y: b.y - 5 * s * u))
            pp.addLine(to: CGPoint(x: b.x, y: b.y - 3.5 * s * u))
            pp.addLine(to: CGPoint(x: a.x, y: a.y - 3.5 * s * u))
            pp.closeSubpath()
        }, with: .color(Earthy.woodLight))
        let m = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        pen.rect(-0.6, -20 * s, 1.2, 16 * s, Earthy.woodDeep, at: m)
        pen.fill([CGPoint(x: m.x + 0.8 * u, y: m.y - 19 * s * u), CGPoint(x: m.x + 9 * s * u, y: m.y - 7 * s * u),
                  CGPoint(x: m.x + 0.8 * u, y: m.y - 6 * s * u)], Earthy.cloth, soft: 0.6)
    }

    static func wellShape(_ pen: IsoPen, x: CGFloat, y: CGFloat, size s: CGFloat) {
        let o = pen.p(x, y), u = pen.u
        pen.shadow(x, y, rx: 9 * s)
        pen.ellipse(o, 7 * s, 3.5 * s, Earthy.stoneShade)
        pen.rect(-7 * s, -5 * s, 14 * s, 5 * s, Earthy.stone, at: o)
        pen.rect(0, -5 * s, 7 * s, 5 * s, Earthy.stoneShade, at: o)
        pen.ellipse(CGPoint(x: o.x, y: o.y - 5 * s * u), 7 * s, 3.5 * s, Earthy.stone)
        pen.ellipse(CGPoint(x: o.x, y: o.y - 5 * s * u), 5 * s, 2.4 * s, Earthy.water)
        pen.rect(-5.5 * s, -15 * s, 1.2 * s, 10 * s, Earthy.woodDark, at: o)
        pen.rect(4.3 * s, -15 * s, 1.2 * s, 10 * s, Earthy.woodDark, at: o)
        pen.fill([CGPoint(x: o.x - 7 * s * u, y: o.y - 14 * s * u), CGPoint(x: o.x, y: o.y - 19 * s * u),
                  CGPoint(x: o.x + 7 * s * u, y: o.y - 14 * s * u)], Earthy.roofLight)
    }

    /// Foundations, and walls rising as chapters are read (a building goes up when the book is finished).
    private static func foundations(_ pen: IsoPen, spec: BuildingSpec, fraction: CGFloat, walls: Earthy.Walls) {
        let b = body(spec)
        let hx = max(b.hx, 0.32), hy = max(b.hy, 0.32)
        let stone = Earthy.Walls(left: Earthy.stone, right: Earthy.stoneShade, top: Color(hex: "#F1E0BC"))
        pen.box(0, 0, hx: hx + 0.08, hy: hy + 0.08, h: 2.2, stone)
        // Corner stones.
        for (x, y) in [(-hx, -hy), (hx, -hy), (-hx, hy), (hx, hy)] {
            pen.box(x, y, hx: 0.05, hy: 0.05, z0: 2.2, h: 2.2, stone, soft: 0.4)
        }
        let full = CGFloat(spec.storeys) * storey
        let h = full * min(1, fraction) * 0.85
        if h >= 1.5 {
            pen.box(0, 0, hx: hx, hy: hy, z0: 2.2, h: h, walls)
            pen.arch(.left, box: 0, 0, hx: hx, hy: hy, t: 0.5, z: 2.2, width: 0.12, h: min(h, storey * 0.75))
            // Scaffolding.
            for (x, y) in [(-hx - 0.06, hy + 0.06), (hx + 0.06, hy + 0.06), (hx + 0.06, -hy - 0.06)] {
                let o = pen.p(x, y)
                pen.rect(-0.6, -(h + 9), 1.2, h + 9, Earthy.woodDark, at: o)
            }
            pen.c.stroke(Path { pp in
                pp.move(to: pen.p(-hx - 0.06, hy + 0.06, h + 4)); pp.addLine(to: pen.p(hx + 0.06, hy + 0.06, h + 4))
                pp.addLine(to: pen.p(hx + 0.06, -hy - 0.06, h + 4))
            }, with: .color(Earthy.wood), style: StrokeStyle(lineWidth: 1.2 * pen.u, lineCap: .round))
        }
        // A small pile of stones ready to go.
        let o = pen.p(hx + 0.25, hy * 0.2)
        for (dx, dy, r) in [(-2.5, 0.0, 2.6), (2.0, 0.6, 2.4), (0.0, -2.2, 2.2)] {
            pen.ellipse(CGPoint(x: o.x + dx * pen.u, y: o.y + dy * pen.u), r, r * 0.75, Earthy.stoneShade)
            pen.ellipse(CGPoint(x: o.x + dx * pen.u - 0.4 * pen.u, y: o.y + dy * pen.u - 0.5 * pen.u), r * 0.8, r * 0.55, Earthy.stone)
        }
    }

    // MARK: Crests

    static func crest(_ pen: IsoPen, _ crest: Crest, at o: CGPoint) {
        let u = pen.u
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * u, y: o.y + y * u) }
        switch crest {
        case .none: return
        case .cross:
            pen.rect(-0.9, -10, 1.8, 10, Earthy.gold, radius: 0.9, at: o)
            pen.rect(-3.5, -7.6, 7, 1.8, Earthy.gold, radius: 0.9, at: o)
        case .star:
            pen.rect(-0.6, -5, 1.2, 5, Earthy.gold, at: o)
            var pts: [CGPoint] = []
            for i in 0..<10 {
                let a = CGFloat(i) * .pi / 5 - .pi / 2, r: CGFloat = i % 2 == 0 ? 3.6 : 1.5
                pts.append(pt(cos(a) * r, -8.5 + sin(a) * r))
            }
            pen.fill(pts, Earthy.gold, soft: 0.5)
        case .flame:
            pen.rect(-2.2, -2.5, 4.4, 2.5, Earthy.woodDark, radius: 1, at: o)
            pen.fill([pt(-2, -2.5), pt(0, -10), pt(2, -2.5)], Earthy.roofLight, soft: 1)
            pen.fill([pt(-1, -2.5), pt(0, -7), pt(1, -2.5)], Earthy.gold, soft: 0.6)
        case .flag:
            pen.rect(-0.5, -13, 1, 13, Earthy.woodDeep, at: o)
            pen.fill([pt(0.5, -13), pt(8, -11), pt(0.5, -8.6)], Earthy.roofLight, soft: 0.6)
        case .bell:
            pen.rect(-0.5, -4, 1, 4, Earthy.woodDeep, at: o)
            pen.fill([pt(-3, -4), pt(-2, -9), pt(2, -9), pt(3, -4)], Earthy.gold, soft: 1)
        case .orb:
            pen.rect(-0.5, -3, 1, 3, Earthy.gold, at: o)
            pen.ellipse(pt(0, -6), 3.2, 3.2, Earthy.gold)
            pen.ellipse(pt(-1, -7), 1, 1, Earthy.goldShine)
        case .lamp:
            pen.ellipse(pt(0, -6), 6, 5, Earthy.gold.opacity(0.35))
            pen.rect(-2, -8, 4, 6, Earthy.goldShine, radius: 1, at: o)
            pen.fill([pt(-2.6, -8), pt(0, -10.5), pt(2.6, -8)], Earthy.woodDark, soft: 0.5)
        case .crown:
            pen.fill([pt(-4, -1), pt(-4, -6), pt(-2, -3.5), pt(0, -7), pt(2, -3.5), pt(4, -6), pt(4, -1)], Earthy.gold, soft: 0.6)
        case .scroll:
            pen.rect(-4, -6, 8, 4.5, Earthy.cloth, radius: 1, at: o)
            pen.ellipse(pt(-4, -3.8), 1.3, 2.4, Earthy.wood)
            pen.ellipse(pt(4, -3.8), 1.3, 2.4, Earthy.wood)
        case .dove:
            pen.ellipse(pt(0, -5), 3.4, 1.8, Earthy.cloth)
            pen.fill([pt(-1, -5.5), pt(1.5, -10), pt(2, -5.5)], Earthy.cloth, soft: 0.6)
            pen.ellipse(pt(3, -6), 1.2, 1.1, Earthy.cloth)
        case .palm:
            pen.rect(-0.6, -10, 1.2, 10, Earthy.trunk, at: o)
            for (dx, dy) in [(-4.0, -10.0), (4.0, -10.0), (-2.4, -12.0), (2.4, -12.0)] { pen.ellipse(pt(dx, dy), 4, 1.6, Earthy.leaf) }
        case .wheat:
            for dx in [-2.0, 0.0, 2.0] {
                pen.rect(dx - 0.3, -8, 0.6, 8, Earthy.gold, at: o)
                pen.ellipse(pt(dx, -9), 1, 2.2, Earthy.gold)
            }
        case .harp:
            pen.c.stroke(Path { pp in pp.move(to: pt(-3, 0)); pp.addQuadCurve(to: pt(3, -10), control: pt(-4, -9)); pp.addLine(to: pt(3, 0)) },
                         with: .color(Earthy.gold), style: StrokeStyle(lineWidth: 1.4 * u, lineCap: .round))
            for i in 0..<3 { pen.rect(-1.5 + CGFloat(i) * 1.5, -6, 0.4, 6, Earthy.goldShine, at: o) }
        case .jar:
            pen.ellipse(pt(0, -4), 3.2, 3.6, Earthy.roofDark)
            pen.rect(-1.4, -9, 2.8, 2.6, Earthy.roofDark, radius: 0.6, at: o)
            pen.ellipse(pt(-1, -5), 0.9, 1.5, Earthy.roofLight)
        case .grapes:
            for (dx, dy) in [(-1.6, -7.0), (1.6, -7.0), (0.0, -5.0), (-0.8, -3.2), (0.8, -3.2), (0.0, -8.6)] {
                pen.ellipse(pt(dx, dy), 1.5, 1.5, Earthy.dome)
            }
            pen.ellipse(pt(2, -9.5), 2, 1, Earthy.leaf)
        }
    }
}

// MARK: - Artifacts and rewards

enum ArtifactArt {
    /// Rough drawn size in u (width, height), for tap targets.
    static func size(_ kind: ArtifactKind) -> CGSize {
        switch kind {
        case .olive, .palm: CGSize(width: 18, height: 36)
        case .cypress: CGSize(width: 10, height: 30)
        case .bush, .flowers: CGSize(width: 14, height: 9)
        case .sheep: CGSize(width: 12, height: 9)
        case .tent: CGSize(width: 18, height: 16)
        case .well: CGSize(width: 16, height: 20)
        case .scroll, .jar: CGSize(width: 10, height: 11)
        case .stele: CGSize(width: 9, height: 15)
        case .altar: CGSize(width: 12, height: 14)
        case .boat: CGSize(width: 20, height: 20)
        case .fishBasket: CGSize(width: 12, height: 8)
        case .wheat: CGSize(width: 12, height: 13)
        case .vine: CGSize(width: 16, height: 14)
        case .oilLamp: CGSize(width: 9, height: 18)
        case .harp: CGSize(width: 10, height: 14)
        case .domedHouse: CGSize(width: 20, height: 24)
        }
    }

    static func draw(_ pen: IsoPen, _ kind: ArtifactKind, level: Int, seed: Int) {
        let o = pen.p(0, 0), u = pen.u
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * u, y: o.y + y * u) }
        decorations(pen, level: level, seed: seed, behind: true)
        switch kind {
        case .olive: pen.tree(0, 0, size: 0.82, seed: seed)
        case .palm:
            pen.shadow(0, 0, rx: 8)
            pen.c.stroke(Path { pp in pp.move(to: pt(0, 0)); pp.addQuadCurve(to: pt(2, -24), control: pt(-2, -12)) },
                         with: .color(Earthy.trunk), style: StrokeStyle(lineWidth: 2.4 * u, lineCap: .round))
            for (dx, dy, rot) in [(-6.0, -24.0, -0.4), (8.0, -24.0, 0.4), (-3.5, -27.0, -0.9), (6.0, -27.5, 0.9), (1.0, -28.0, 0.0)] {
                var g = pen.c
                g.translateBy(x: o.x + dx * u, y: o.y + dy * u)
                g.rotate(by: .radians(rot))
                g.fill(Path(ellipseIn: CGRect(x: -6 * u, y: -1.8 * u, width: 12 * u, height: 3.6 * u)), with: .color(Earthy.leaf))
            }
        case .cypress:
            pen.shadow(0, 0, rx: 5)
            pen.rect(-0.8, -4, 1.6, 4, Earthy.trunk, at: o)
            pen.ellipse(pt(0.8, -15), 4.6, 12, Earthy.leafShade)
            pen.ellipse(pt(0, -15.5), 4.4, 12, Earthy.leaf)
        case .bush:
            pen.shadow(0, 0, rx: 7)
            pen.ellipse(pt(-2.5, -2.4), 4.6, 3.2, Earthy.bush)
            pen.ellipse(pt(2.5, -3), 4.6, 3.4, Earthy.bush)
            pen.ellipse(pt(0, -4.4), 4, 3, Earthy.leaf)
        case .flowers:
            pen.ellipse(pt(0, -0.5), 7, 2.6, Earthy.bush)
            let colours = [Earthy.roofLight, Earthy.dome, Earthy.gold, Earthy.cloth]
            for i in 0..<5 {
                let x = CGFloat(i) * 3 - 6, y = CGFloat((i * 7 + seed) % 3) - 1
                pen.rect(x - 0.3, y - 5, 0.6, 5, Earthy.leafShade, at: o)
                pen.ellipse(pt(x, y - 5.5), 1.8, 1.6, colours[(i + seed) % colours.count])
            }
        case .sheep:
            pen.shadow(0, 0, rx: 6)
            for (dx, dy) in [(-2.0, -4.0), (0.6, -5.0), (2.4, -3.8), (0.0, -3.0)] { pen.ellipse(pt(dx, dy), 2.6, 2.4, Earthy.cloth) }
            pen.ellipse(pt(4.8, -4.6), 1.6, 1.5, Color(hex: "#6A5640"))
            pen.rect(-2.4, -1.8, 0.9, 1.8, Color(hex: "#6A5640"), at: o)
            pen.rect(1.6, -1.8, 0.9, 1.8, Color(hex: "#6A5640"), at: o)
        case .tent:
            pen.shadow(0, 0, rx: 9)
            pen.cone(0, 0, r: 0.24, h: 14, light: seed % 2 == 0 ? Earthy.roofLight : Earthy.cloth,
                     dark: seed % 2 == 0 ? Earthy.roofDark : Earthy.clothShade)
            pen.fill([pt(-1.4, 1.5), pt(1.4, 2.6), pt(0, -5)], Earthy.woodDeep.opacity(0.5), soft: 0.3)
        case .well: BuildingArt.wellShape(pen, x: 0, y: 0, size: 0.85)
        case .scroll:
            pen.shadow(0, 0, rx: 6)
            pen.box(0, 0, hx: 0.1, hy: 0.06, h: 4, Earthy.Walls(left: Earthy.wood, right: Earthy.woodDark, top: Earthy.woodLight), soft: 0.4)
            pen.rect(-5, -9, 10, 4, Earthy.cloth, radius: 1, at: o)
            pen.ellipse(pt(-5, -7), 1.2, 2.2, Earthy.woodLight)
            pen.ellipse(pt(5, -7), 1.2, 2.2, Earthy.woodLight)
            pen.rect(-3, -7.6, 6, 0.6, Earthy.window.opacity(0.5), at: o)
        case .jar:
            pen.shadow(0, 0, rx: 5)
            pen.ellipse(pt(0, -4.5), 4, 4.6, Earthy.roofDark)
            pen.ellipse(pt(-1.2, -5.2), 2.8, 3.6, Earthy.roofLight)
            pen.rect(-1.8, -10.5, 3.6, 2.6, Earthy.roofDark, radius: 0.8, at: o)
            if seed % 2 == 0 {
                pen.ellipse(pt(5, -2.5), 2.4, 2.8, Earthy.wood)
                pen.ellipse(pt(4.4, -3), 1.6, 2.1, Earthy.woodLight)
            }
        case .stele:
            pen.shadow(0, 0, rx: 5)
            pen.fill([pt(-4, 0), pt(-4, -11), pt(-2.5, -14), pt(0, -14.5), pt(0, 1.2)], Earthy.stone, soft: 1)
            pen.fill([pt(0, 1.2), pt(0, -14.5), pt(2.5, -14), pt(4, -11), pt(4, -0.6)], Earthy.stoneShade, soft: 1)
            for i in 0..<3 { pen.rect(-3, -11 + CGFloat(i) * 2.6, 2.2, 0.6, Earthy.window.opacity(0.4), at: o) }
        case .altar:
            pen.shadow(0, 0, rx: 7)
            pen.box(0, 0, hx: 0.12, hy: 0.12, h: 7, Earthy.Walls(left: Earthy.stone, right: Earthy.stoneShade, top: Color(hex: "#F1E0BC")), soft: 0.6)
            BuildingArt.crest(pen, .flame, at: pt(0, -7))
        case .boat:
            pen.ellipse(o, 11, 5, Earthy.water)
            BuildingArt.boat(pen, x: 0, y: 0, size: 0.8)
        case .fishBasket:
            pen.shadow(0, 0, rx: 6)
            pen.ellipse(pt(0, -2), 5.5, 2.6, Earthy.woodDark)
            pen.rect(-5.5, -5, 11, 3, Earthy.wood, radius: 1, at: o)
            pen.ellipse(pt(0, -5), 5.5, 2.4, Earthy.woodLight)
            for (dx, c) in [(-2.0, Color(hex: "#B5C6CC")), (1.8, Color(hex: "#C9D6DA"))] {
                pen.ellipse(pt(dx, -6), 2.6, 1.1, c)
            }
        case .wheat:
            pen.shadow(0, 0, rx: 6)
            for i in 0..<5 {
                let x = CGFloat(i) * 2.2 - 4.4
                pen.rect(x - 0.3, -10, 0.6, 10, Color(hex: "#D9B66B"), at: o)
                pen.ellipse(pt(x, -11), 1.1, 2.4, Earthy.gold)
            }
        case .vine:
            pen.shadow(0, 0, rx: 8)
            for dx in [-5.0, 5.0] { pen.rect(dx - 0.6, -11, 1.2, 11, Earthy.woodDark, at: o) }
            pen.rect(-6, -11, 12, 1.2, Earthy.wood, at: o)
            pen.ellipse(pt(-2, -10), 5, 3, Earthy.leaf)
            pen.ellipse(pt(3, -9.5), 4.5, 2.8, Earthy.leafShade)
            for (dx, dy) in [(-2.0, -7.0), (2.5, -6.5), (0.0, -6.0)] { pen.ellipse(pt(dx, dy), 1.3, 1.7, Earthy.dome) }
        case .oilLamp:
            pen.ellipse(pt(0, -14), 7, 6, Earthy.gold.opacity(0.3))
            pen.shadow(0, 0, rx: 4)
            pen.rect(-0.6, -11, 1.2, 11, Earthy.woodDeep, at: o)
            pen.ellipse(pt(0, -12), 3.4, 1.6, Earthy.roofDark)
            pen.ellipse(pt(-0.6, -12.6), 2.4, 1.1, Earthy.roofLight)
            pen.fill([pt(1.6, -13), pt(2.6, -17), pt(3.4, -13)], Earthy.gold, soft: 0.6)
        case .harp:
            pen.shadow(0, 0, rx: 5)
            BuildingArt.crest(pen, .harp, at: pt(0, -1))
            pen.rect(-3.5, -1.4, 7, 1.4, Earthy.woodDark, radius: 0.6, at: o)
        case .domedHouse:
            pen.shadow(0, 0, rx: 11)
            pen.box(0, 0, hx: 0.2, hy: 0.2, h: 11, Earthy.walls(.sand), soft: 0.8)
            pen.arch(.left, box: 0, 0, hx: 0.2, hy: 0.2, t: 0.5, z: 0, width: 0.09, h: 7)
            pen.arch(.right, box: 0, 0, hx: 0.2, hy: 0.2, t: 0.5, z: 3, width: 0.08, h: 5)
            pen.dome(0, 0, r: 0.17, z: 11, gold: true)
        }
        decorations(pen, level: level, seed: seed, behind: false)
    }

    /// Levels 2–5 add small touches: a flower, a second flower, a soft glow, a golden sparkle.
    static func decorations(_ pen: IsoPen, level: Int, seed: Int, behind: Bool) {
        let o = pen.p(0, 0), u = pen.u
        if behind {
            if level >= 4 { pen.ellipse(CGPoint(x: o.x, y: o.y - 6 * u), 13, 11, Earthy.gold.opacity(0.18)) }
            return
        }
        let colours = [Earthy.roofLight, Earthy.dome, Earthy.gold]
        if level >= 2 {
            pen.rect(5.5, -3.5, 0.5, 3.5, Earthy.leafShade, at: o)
            pen.ellipse(CGPoint(x: o.x + 5.75 * u, y: o.y - 4 * u), 1.5, 1.4, colours[seed % 3])
        }
        if level >= 3 {
            pen.rect(-6.2, -3, 0.5, 3, Earthy.leafShade, at: o)
            pen.ellipse(CGPoint(x: o.x - 6 * u, y: o.y - 3.4 * u), 1.4, 1.3, colours[(seed + 1) % 3])
        }
        if level >= 5 {
            let c = CGPoint(x: o.x + 6 * u, y: o.y - 16 * u)
            var pts: [CGPoint] = []
            for i in 0..<8 {
                let a = CGFloat(i) * .pi / 4, r: CGFloat = i % 2 == 0 ? 2.6 : 0.9
                pts.append(CGPoint(x: c.x + cos(a) * r * u, y: c.y + sin(a) * r * u))
            }
            pen.fill(pts, Earthy.gold, soft: 0.3)
        }
    }
}

enum RewardArt {
    static func size(_ kind: RewardKind) -> CGSize {
        switch kind {
        case .banner: CGSize(width: 14, height: 26)
        case .lantern: CGSize(width: 12, height: 22)
        case .fruitTree: CGSize(width: 20, height: 38)
        }
    }

    static func draw(_ pen: IsoPen, _ kind: RewardKind, seed: Int) {
        let o = pen.p(0, 0), u = pen.u
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * u, y: o.y + y * u) }
        switch kind {
        case .banner:
            pen.shadow(0, 0, rx: 5)
            pen.rect(-0.8, -24, 1.6, 24, Earthy.woodDeep, radius: 0.8, at: o)
            pen.ellipse(pt(0, -24.5), 1.4, 1.4, Earthy.gold)
            let colour = seed % 2 == 0 ? Earthy.roofLight : Earthy.dome
            pen.fill([pt(0.8, -22), pt(9, -21), pt(9, -12), pt(5, -14), pt(0.8, -12)], colour, soft: 0.8)
            pen.rect(3, -19, 3, 3, Earthy.gold, radius: 1.5, at: o)
        case .lantern:
            pen.ellipse(pt(0, -15), 9, 8, Earthy.gold.opacity(0.3))
            pen.shadow(0, 0, rx: 4)
            pen.rect(-0.6, -12, 1.2, 12, Earthy.woodDeep, at: o)
            pen.rect(-2.4, -18, 4.8, 6, Earthy.goldShine, radius: 1.2, at: o)
            pen.rect(-1.2, -16.5, 2.4, 3, Earthy.gold, radius: 1, at: o)
            pen.fill([pt(-3, -18), pt(0, -21), pt(3, -18)], Earthy.woodDark, soft: 0.6)
        case .fruitTree:
            pen.tree(0, 0, size: 0.95, fruit: true, seed: seed)
        }
    }
}

// MARK: - Story objects

/// Story objects (e.g. Noah's Ark for Genesis 6–9), drawn in the island's style. They take
/// their chapter's spot like an artifact, a little larger, and grow with rereads (1–5).
enum StoryArt {
    static func size(_ kind: ChapterObjectKind) -> CGSize {
        switch kind {
        case .ladder, .tower, .sinai: CGSize(width: 34, height: 46)
        default: CGSize(width: 38, height: 32)
        }
    }

    static func draw(_ pen: IsoPen, _ kind: ChapterObjectKind, level: Int, variant: Int, seed: Int) {
        let o = pen.p(0, 0), u = pen.u
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * u, y: o.y + y * u) }
        let stone = Earthy.Walls(left: Earthy.stone, right: Earthy.stoneShade, top: Color(hex: "#F1E0BC"))
        let wood = Earthy.Walls(left: Earthy.wood, right: Earthy.woodDark, top: Earthy.woodLight)
        func pool(_ rx: CGFloat, _ ry: CGFloat, at c: CGPoint? = nil) {
            let c = c ?? o
            pen.ellipse(c, rx, ry, Earthy.water)
            pen.ellipse(CGPoint(x: c.x - rx * 0.25 * u, y: c.y - ry * 0.2 * u), rx * 0.5, ry * 0.35, Earthy.waterShine)
        }
        func figure(_ x: CGFloat, _ y: CGFloat, _ robe: Color) {
            let f = pen.p(x, y)
            pen.ellipse(CGPoint(x: f.x, y: f.y), 2.2, 1, Earthy.shadow)
            pen.rect(-1.6, -5.5, 3.2, 5.5, robe, radius: 1.4, at: f)
            pen.ellipse(CGPoint(x: f.x, y: f.y - 7 * u), 1.8, 1.8, Color(hex: "#EBC3A0"))
        }
        func flame(_ c: CGPoint, _ s: CGFloat) {
            pen.fill([CGPoint(x: c.x - 2 * s * u, y: c.y), CGPoint(x: c.x, y: c.y - 7 * s * u), CGPoint(x: c.x + 2 * s * u, y: c.y)], Earthy.roofLight, soft: 0.8)
            pen.fill([CGPoint(x: c.x - 1 * s * u, y: c.y), CGPoint(x: c.x, y: c.y - 4.5 * s * u), CGPoint(x: c.x + 1 * s * u, y: c.y)], Earthy.gold, soft: 0.5)
        }

        ArtifactArt.decorations(pen, level: level, seed: seed, behind: true)
        switch kind {
        case .edenTrees:
            pool(10, 3.5, at: pt(4, 2))
            pen.tree(-0.25, -0.1, size: 0.8, fruit: true, seed: seed)
            pen.tree(0.2, -0.3, size: 0.7, fruit: true, seed: seed + 1)
            pen.tree(-0.05, 0.25, size: 0.6, seed: seed)
        case .ark:
            pen.shadow(0, 0, rx: 20)
            let hull = Path { p in
                p.move(to: pt(-18, -8)); p.addLine(to: pt(18, -8))
                p.addQuadCurve(to: pt(10, 3), control: pt(17, 1)); p.addLine(to: pt(-10, 3))
                p.addQuadCurve(to: pt(-18, -8), control: pt(-17, 1)); p.closeSubpath()
            }
            pen.c.fill(hull, with: .color(Earthy.woodDark))
            pen.rect(-18, -9.5, 36, 2.5, Earthy.woodLight, radius: 1, at: o)
            pen.box(0, -0.02, hx: 0.22, hy: 0.1, z0: 9, h: 7, wood, soft: 0.6)
            pen.gable(0, -0.02, hx: 0.22, hy: 0.1, z: 16, h: 5, gableEnd: Earthy.woodDark)
            for i in 0..<3 { pen.rect(-7 + CGFloat(i) * 5, -13.5, 2, 2.5, Earthy.woodDeep, radius: 0.6, at: o) }
        case .ladder:
            pen.ellipse(pt(0, -40), 12, 9, Earthy.gold.opacity(0.25))
            pen.box(0, 0, hx: 0.1, hy: 0.06, h: 4, stone, soft: 0.5)
            for x in [-3.0, 3.0] { pen.rect(x - 0.6, -42, 1.2, 38, Earthy.gold, at: o) }
            for i in 0..<8 { pen.rect(-3, -8 - CGFloat(i) * 4.4, 6, 0.9, Earthy.goldShine, at: o) }
        case .tower:
            var z: CGFloat = 0
            for i in 0..<4 {
                let k = 1 - CGFloat(i) * 0.2
                pen.box(0, 0, hx: 0.24 * k, hy: 0.24 * k, z0: z, h: 9, Earthy.walls(.clay), soft: 0.6)
                pen.arch(.left, box: 0, 0, hx: 0.24 * k, hy: 0.24 * k, t: 0.5, z: z + 1, width: 0.06, h: 6)
                z += 9
            }
            // Unfinished: scaffold on top.
            pen.rect(-5, -z - 8, 1, 8, Earthy.woodDark, at: o)
            pen.rect(4, -z - 6, 1, 6, Earthy.woodDark, at: o)
        case .sinai:
            let hill = Path { p in
                p.move(to: pt(-18, 0)); p.addQuadCurve(to: pt(0, -34), control: pt(-12, -30))
                p.addQuadCurve(to: pt(18, 0), control: pt(12, -30)); p.closeSubpath()
            }
            pen.c.fill(hill, with: .color(Color(hex: "#D9B98A")))
            pen.fill([pt(0, -34), pt(18, 0), pt(6, 4)], Color(hex: "#C8A473"), soft: 1)
            pen.ellipse(pt(0, -38), 11, 5, Color.white.opacity(0.7))
            pen.ellipse(pt(5, -40), 7, 4, Color.white.opacity(0.6))
            for dx in [-3.5, 1.0] { pen.rect(dx, -10, 3.6, 5, Earthy.stone, radius: 1.6, at: o) }
        case .bush:
            pen.shadow(0, 0, rx: 9)
            pen.ellipse(pt(0, -12), 12, 10, Earthy.gold.opacity(0.25))
            pen.ellipse(pt(-3, -4), 6, 4, Earthy.bush)
            pen.ellipse(pt(3, -4.5), 6, 4.2, Earthy.leaf)
            for (dx, s) in [(-4.0, 1.0), (0.0, 1.4), (4.0, 1.1)] { flame(pt(dx, -7), s) }
        case .plague:
            pen.box(0, 0, hx: 0.12, hy: 0.08, h: 3, stone, soft: 0.5)
            pen.fill([pt(-4, -3), pt(-4, -15), pt(0, -18), pt(4, -15), pt(4, -3)], Earthy.stone, soft: 1)
            let marks: [Color] = [Color(hex: "#B5524A"), Earthy.leaf, Earthy.woodDark, Earthy.gold, Color(hex: "#6A5640"), Earthy.roofLight]
            pen.ellipse(pt(0, -10), 2.4, 2.4, marks[variant % marks.count])
        case .redSea:
            pen.fill([pt(-20, 4), pt(-6, -3), pt(6, 3), pt(-8, 10)], Earthy.path, soft: 2)
            for side in [-1.0, 1.0] {
                let c = pt(CGFloat(side) * 12, -2)
                pen.rect(-7, -14, 14, 14, Earthy.water, radius: 4, at: c)
                pen.rect(-5, -13, 4, 10, Earthy.waterShine, radius: 2, at: c)
            }
        case .fallenWalls:
            pen.shadow(0, 0, rx: 16)
            for (i, h) in [8.0, 3.0, 6.0, 2.0].enumerated() {
                pen.box(-0.3 + CGFloat(i) * 0.18, 0.05, hx: 0.08, hy: 0.06, h: h, stone, soft: 0.5)
            }
            for (dx, dy) in [(-8.0, 5.0), (6.0, 6.0), (12.0, 2.0)] {
                pen.ellipse(pt(dx, dy), 2.6, 1.8, Earthy.stoneShade)
            }
        case .valley:
            for side in [-1.0, 1.0] {
                let c = pt(CGFloat(side) * 12, -2)
                pen.c.fill(Path(ellipseIn: CGRect(x: c.x - 9 * u, y: c.y - 7 * u, width: 18 * u, height: 12 * u)), with: .color(Color(hex: "#DCC08F")))
            }
            pen.fill([pt(-4, 6), pt(4, -2), pt(7, -1), pt(-1, 7)], Earthy.water, soft: 1)
            for i in 0..<5 { pen.ellipse(pt(-3 + CGFloat(i) * 1.6, 2 - CGFloat(i % 2)), 0.9, 0.7, Color(hex: "#9A8E80")) }
        case .stronghold:
            pen.box(0, 0, hx: 0.2, hy: 0.2, h: 18, Earthy.walls(.sand))
            pen.arch(.left, box: 0, 0, hx: 0.2, hy: 0.2, t: 0.5, z: 0, width: 0.1, h: 9)
            pen.battlements(0, 0, hx: 0.2, hy: 0.2, z: 18, Earthy.walls(.sand))
            BuildingArt.crest(pen, .flag, at: pt(0, -22))
        case .pasture:
            pen.ellipse(o, 18, 8, Earthy.bush.opacity(0.7))
            pool(6, 2.5, at: pt(7, 1))
            for (x, y) in [(-0.2, -0.05), (0.0, 0.15), (-0.32, 0.2)] {
                var g = pen.c
                let p = pen.p(x, y)
                g.translateBy(x: p.x, y: p.y)
                ArtifactArt.draw(IsoPen(c: g, u: u * 0.8), .sheep, level: 1, seed: seed)
            }
        case .shipAndFish:
            pool(18, 7)
            BuildingArt.boat(pen, x: -0.15, y: 0.1, size: 0.8)
            let fish = pt(9, -1)
            pen.ellipse(fish, 7, 3.2, Color(hex: "#8FA7B0"))
            pen.fill([CGPoint(x: fish.x + 6 * u, y: fish.y), CGPoint(x: fish.x + 11 * u, y: fish.y - 3.5 * u), CGPoint(x: fish.x + 11 * u, y: fish.y + 3.5 * u)], Color(hex: "#7C949D"), soft: 0.6)
            pen.ellipse(CGPoint(x: fish.x - 4 * u, y: fish.y - 0.8 * u), 0.7, 0.7, Color.bodyText)
        case .lionsDen:
            pen.ellipse(o, 16, 7.5, Earthy.stoneShade)
            pen.ellipse(pt(0, -1), 13, 5.8, Color(hex: "#7E6450"))
            let head = pt(-2, -5)
            pen.ellipse(head, 5, 4.6, Color(hex: "#C98F4E"))
            pen.ellipse(head, 3, 2.8, Earthy.gold)
            for dx in [-1.0, 1.0] { pen.rect(dx - 0.3, -6, 0.6, 0.8, Color.bodyText, at: head) }
            figure(0.18, -0.02, Earthy.dome)
        case .boats:
            pool(19, 7)
            BuildingArt.boat(pen, x: -0.2, y: 0.05, size: 0.7)
            BuildingArt.boat(pen, x: 0.25, y: -0.05, size: 0.6)
        case .weddingHouse:
            ArtifactArt.draw(pen, .domedHouse, level: 1, seed: seed)
            for i in 0..<6 {
                let j = pt(-12 + CGFloat(i % 3) * 3.4 + (i < 3 ? 0 : 1.7), 4 + (i < 3 ? 0 : 2.4))
                pen.ellipse(j, 1.6, 2, Earthy.stoneShade)
                pen.ellipse(CGPoint(x: j.x - 0.3 * u, y: j.y - 0.4 * u), 1.1, 1.5, Earthy.stone)
            }
        case .vineyard:
            for (x, y) in [(-0.22, -0.1), (0.15, 0.1)] {
                var g = pen.c
                let p = pen.p(x, y)
                g.translateBy(x: p.x, y: p.y)
                ArtifactArt.draw(IsoPen(c: g, u: u), .vine, level: 1, seed: seed)
            }
        case .hillsideCrowd:
            let hill = Path { p in
                p.move(to: pt(-20, 3)); p.addQuadCurve(to: pt(20, 3), control: pt(0, -22)); p.closeSubpath()
            }
            pen.c.fill(hill, with: .color(Earthy.bush.opacity(0.85)))
            let robes = [Earthy.roofLight, Earthy.dome, Earthy.cloth, Earthy.leaf, Earthy.gold]
            for i in 0..<7 {
                let x = -0.3 + CGFloat(i % 4) * 0.16, y = 0.12 - CGFloat(i / 4) * 0.18
                figure(x, y, robes[i % robes.count])
            }
            figure(-0.05, -0.32, Earthy.cloth)
        case .pentecost:
            pen.box(0, 0, hx: 0.22, hy: 0.18, h: 14, Earthy.walls(.cream))
            pen.windows(box: 0, 0, hx: 0.22, hy: 0.18, storeys: 1, storey: 14)
            pen.box(0, 0, hx: 0.21, hy: 0.17, z0: 14, h: 1.2, Earthy.walls(.cream))
            for (i, dx) in [-6.0, -2.0, 2.0, 6.0].enumerated() {
                flame(pt(dx, -18 - CGFloat(i % 2) * 3), 0.8)
            }
        case .altarCourt:
            pen.fill([pen.p(-0.45, -0.45), pen.p(0.45, -0.45), pen.p(0.45, 0.45), pen.p(-0.45, 0.45)], Earthy.path, soft: 2)
            for i in 0..<5 { // curtain posts along the back of the court
                let post = pen.p(-0.42 + CGFloat(i) * 0.21, -0.42)
                pen.rect(-0.6, -10, 1.2, 10, Earthy.woodDark, at: post)
            }
            pen.box(0, 0, hx: 0.16, hy: 0.16, h: 8, stone, soft: 0.6)
            BuildingArt.crest(pen, .flame, at: pt(0, -8))
            pool(4, 1.8, at: pt(12, 4))
        case .shipwreck:
            pool(18, 7)
            var g = pen.c
            g.translateBy(x: o.x, y: o.y)
            g.rotate(by: .degrees(-14))
            BuildingArt.boat(IsoPen(c: g, u: u), x: 0, y: 0, size: 0.9)
            for (dx, dy) in [(-11.0, 3.0), (9.0, 4.0)] { pen.rect(dx, dy, 6, 1.2, Earthy.wood, radius: 0.5, at: o) }
        }
        ArtifactArt.decorations(pen, level: level, seed: seed, behind: false)
    }
}
