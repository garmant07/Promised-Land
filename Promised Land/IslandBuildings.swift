import SwiftUI

/// A book's building on the island. Opening the book lays foundation stones; every chapter
/// read then adds to it, so progress is easy to see at a glance:
/// - **Stories** (towers, temples, palaces, walls…): floors stack up. Each chapter raises the
///   current floor; a finished book gets its roof (a dome, a pointed roof, battlements…).
/// - **Rows** (vineyards, fields, gardens, hills): one more vine, wheat stalk or tree per chapter.
/// - **Settlements** (camps, villages): one more tent or house per chapter.
/// Drawn in island units (`u`): a tile is 44u wide and 22u deep, centred on the origin.
enum IslandBuildings {
    enum Growth { case stories, rows, settlement }

    static func growth(of style: BuildingStyle) -> Growth {
        switch style {
        case .garden, .field, .vineyard, .mountain, .hill: .rows
        case .tents, .village: .settlement
        default: .stories
        }
    }

    // MARK: Stories

    static let floorHeight: CGFloat = 5.5
    static let maxFloors = 5

    /// Books of up to five chapters get one floor per chapter; longer books spread across five
    /// floors, each chapter raising the current floor a little.
    static func floors(total: Int) -> Int { min(maxFloors, max(1, total)) }

    /// Built height in floors (fractional while a floor is going up).
    static func builtFloors(progress: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(min(progress, total)) / Double(total) * Double(floors(total: total))
    }

    /// Height of the drawn building (for hit testing), in units.
    static func height(style: BuildingStyle, progress: Int, total: Int) -> CGFloat {
        switch growth(of: style) {
        case .stories:
            let roof: CGFloat = progress >= total && total > 0 ? 14 : 4
            return CGFloat(builtFloors(progress: progress, total: total)) * floorHeight + roof
        case .rows, .settlement: return 14
        }
    }

    // MARK: Drawing

    static func draw(_ c: inout GraphicsContext, style: BuildingStyle, progress: Int, total: Int, u: CGFloat, seed: Int) {
        let complete = total > 0 && progress >= total
        foundations(&c, u: u, faint: progress > 0)
        guard progress > 0 else { return }
        switch growth(of: style) {
        case .stories: stories(&c, style: style, progress: progress, total: total, complete: complete, u: u)
        case .rows: rows(&c, style: style, progress: progress, total: total, complete: complete, u: u)
        case .settlement: settlement(&c, style: style, progress: progress, total: total, complete: complete, u: u)
        }
    }

    /// Cut stones laid round the plot: the foundations, there as soon as you open the book.
    private static func foundations(_ c: inout GraphicsContext, u: CGFloat, faint: Bool) {
        var g = Geo(c: c, u: u)
        g.diamond(CGPoint.zero, width: 38, .stoneShade, alpha: faint ? 0.25 : 0.4)
        guard !faint else { return }
        let corners: [CGPoint] = [CGPoint(x: 0, y: -9.5), CGPoint(x: 19, y: 0), CGPoint(x: 0, y: 9.5), CGPoint(x: -19, y: 0)]
        var stones: [CGPoint] = []
        for i in 0..<4 {
            let a = corners[i], b = corners[(i + 1) % 4]
            for t in stride(from: 0.0, to: 1.0, by: 0.25) { stones.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)) }
        }
        for p in stones.sorted(by: { $0.y < $1.y }) { g.box(p, w: 4.5, h: 2.6, left: .stoneLight, right: .stoneShade) }
        c = g.c
    }

    private static func stories(_ c: inout GraphicsContext, style: BuildingStyle, progress: Int, total: Int, complete: Bool, u: CGFloat) {
        var g = Geo(c: c, u: u)
        let walls = wallColours(style)
        let built = builtFloors(progress: progress, total: total)
        let full = Int(built), partial = built - Double(full)
        let narrows = style == .pyramid
        func width(_ f: Int) -> CGFloat { narrows ? max(10, 32 - CGFloat(f) * 3.4) : 30 }
        g.ellipse(CGPoint(x: 0, y: 4), 40, 14, .primaryBrown, alpha: 0.08)

        for f in 0..<full {
            let base = CGPoint(x: 0, y: -CGFloat(f) * floorHeight)
            g.box(base, w: width(f), h: floorHeight, left: walls.light, right: walls.shade)
            // A dark band between floors, and a window on each face, so floors read as floors.
            g.box(base, w: width(f) + 0.6, h: 0.8, left: walls.shade.opacity(0.9), right: walls.shade.opacity(0.9))
            if !narrows {
                g.rect(CGPoint(x: -width(f) * 0.27, y: base.y - floorHeight * 0.45), 2.6, 3.4, Color.primaryBrown.opacity(0.22))
                g.rect(CGPoint(x: width(f) * 0.27, y: base.y - floorHeight * 0.4), 2.6, 3.4, Color.primaryBrown.opacity(0.3))
            }
        }
        let top = -CGFloat(full) * floorHeight
        if partial > 0.001 {
            // The floor going up: lighter, with scaffolding poles at its corners.
            let h = floorHeight * CGFloat(partial)
            let w = width(full)
            g.box(CGPoint(x: 0, y: top), w: w, h: h, left: walls.light.opacity(0.8), right: walls.shade.opacity(0.8))
            for x in [-w / 2 - 0.6, w / 2 + 0.6] {
                g.rect(CGPoint(x: x, y: top - floorHeight / 2), 0.5, floorHeight + 1.5, Color(hex: "#A9805C").opacity(0.8))
            }
            g.rect(CGPoint(x: 0, y: top - floorHeight + w / 4 - 0.5), 0.5, floorHeight + 1.5, Color(hex: "#A9805C").opacity(0.8))
        }
        if complete { roof(&g, style: style, top: top, width: width(max(0, full - 1))) }
        c = g.c
    }

    private static func roof(_ g: inout Geo, style: BuildingStyle, top: CGFloat, width w: CGFloat) {
        switch style {
        case .temple:
            g.dome(CGPoint(x: 0, y: top), r: w * 0.36, .lavender)
        case .palace, .glowCity:
            g.dome(CGPoint(x: 0, y: top), r: w * 0.32, Color(hex: "#EBCB7E"))
        case .walls, .gate:
            for i in 0..<4 { g.rect(CGPoint(x: -w / 2 + 3 + CGFloat(i) * (w - 6) / 3, y: top - 2), 3, 3.2, .terracotta) }
        case .pyramid:
            g.poly([CGPoint(x: -w / 2, y: top), CGPoint(x: 0, y: top + w / 4), CGPoint(x: 0, y: top - 8)], Color(hex: "#EBCB7E"))
            g.poly([CGPoint(x: 0, y: top + w / 4), CGPoint(x: w / 2, y: top), CGPoint(x: 0, y: top - 8)], Color(hex: "#DDB466"))
        case .tabernacle:
            g.poly([CGPoint(x: -w / 2 - 1, y: top), CGPoint(x: 0, y: top + w / 4), CGPoint(x: 0, y: top - 8)], .cream)
            g.poly([CGPoint(x: 0, y: top + w / 4), CGPoint(x: w / 2 + 1, y: top), CGPoint(x: 0, y: top - 8)], .lavender)
        case .portCity, .harbour:
            g.ellipse(CGPoint(x: 0, y: top - 3), 6, 6, .wheat)
            g.pointedRoof(top: top - 5, w: 8)
        default:
            g.pointedRoof(top: top, w: w)
        }
        // A small pennant: finished.
        g.rect(CGPoint(x: 0, y: top - 15), 0.7, 8, Color(hex: "#A9805C"))
        g.poly([CGPoint(x: 0.3, y: top - 19), CGPoint(x: 5, y: top - 17.5), CGPoint(x: 0.3, y: top - 16)], .lavender)
    }

    private static func wallColours(_ style: BuildingStyle) -> (light: Color, shade: Color) {
        switch style {
        case .temple, .palace, .tabernacle, .glowCity, .house: (.cream, Color(hex: "#EADFCB"))
        default: (.stoneLight, .stoneShade)
        }
    }

    // MARK: Rows

    /// Up to 20 plants; long books grow each plant over several chapters (it gets bigger).
    private static func rows(_ c: inout GraphicsContext, style: BuildingStyle, progress: Int, total: Int, complete: Bool, u: CGFloat) {
        var g = Geo(c: c, u: u)
        if style == .mountain || style == .hill {
            g.poly([CGPoint(x: -20, y: 0), CGPoint(x: 0, y: 10), CGPoint(x: 20, y: 0), CGPoint(x: 0, y: -6)], .olive, alpha: 0.6)
        } else if style == .field {
            g.diamond(.zero, width: 34, .wheat, alpha: 0.35)
        }
        let slots = min(20, max(1, total))
        let grown = Double(min(progress, total)) / Double(max(1, total)) * Double(slots)
        var spots: [(CGPoint, CGFloat)] = []
        for i in 0..<slots {
            let size = min(1, max(0, CGFloat(grown) - CGFloat(i)))
            guard size > 0 else { break }
            let col = CGFloat(i % 5), row = CGFloat(i / 5)
            let a = -0.32 + col * 0.16, b = -0.3 + row * 0.2
            spots.append((CGPoint(x: (a - b) * 22, y: (a + b) * 11), max(0.35, size)))
        }
        for (p, s) in spots.sorted(by: { $0.0.y < $1.0.y }) {
            switch style {
            case .vineyard:
                g.rect(CGPoint(x: p.x, y: p.y - 4 * s), 0.7, 8 * s, Color(hex: "#A9805C"))
                g.ellipse(CGPoint(x: p.x, y: p.y - 8 * s), 6 * s, 4.4 * s, .olive)
                g.ellipse(CGPoint(x: p.x + 1.2 * s, y: p.y - 6.6 * s), 2 * s, 2.2 * s, .lavender)
            case .field:
                g.rect(CGPoint(x: p.x, y: p.y - 3.5 * s), 0.6, 7 * s, .olive)
                g.ellipse(CGPoint(x: p.x, y: p.y - 7.6 * s), 2 * s, 4 * s, .wheat)
            default:
                g.rect(CGPoint(x: p.x, y: p.y - 3 * s), 1, 6 * s, Color(hex: "#A9805C"))
                g.ellipse(CGPoint(x: p.x + 0.6 * s, y: p.y - 7.5 * s), 7 * s, 6 * s, Color(hex: "#929E66"))
                g.ellipse(CGPoint(x: -0.4 * s + p.x, y: p.y - 8.2 * s), 6.6 * s, 5.6 * s, .olive)
            }
        }
        if complete { fence(&g) }
        c = g.c
    }

    // MARK: Settlements

    private static func settlement(_ c: inout GraphicsContext, style: BuildingStyle, progress: Int, total: Int, complete: Bool, u: CGFloat) {
        var g = Geo(c: c, u: u)
        let slots = min(9, max(1, total))
        let grown = Double(min(progress, total)) / Double(max(1, total)) * Double(slots)
        let colours: [Color] = [.terracotta, .cream, .lavender, .wheat]
        var spots: [(CGPoint, CGFloat, Int)] = []
        for i in 0..<slots {
            let size = min(1, max(0, CGFloat(grown) - CGFloat(i)))
            guard size > 0 else { break }
            let a = -0.28 + CGFloat(i % 3) * 0.28, b = -0.28 + CGFloat(i / 3) * 0.28
            spots.append((CGPoint(x: (a - b) * 22, y: (a + b) * 11), max(0.4, size), i))
        }
        for (p, s, i) in spots.sorted(by: { $0.0.y < $1.0.y }) {
            if style == .village {
                g.box(p, w: 9 * s, h: 6 * s, left: .stoneLight, right: .stoneShade)
                g.pointedRoof(top: p.y - 6 * s, w: 9 * s, x: p.x)
            } else {
                let colour = colours[i % colours.count]
                g.poly([CGPoint(x: p.x - 5 * s, y: p.y), CGPoint(x: p.x, y: p.y + 2.4 * s), CGPoint(x: p.x, y: p.y - 7 * s)], colour)
                g.poly([CGPoint(x: p.x, y: p.y + 2.4 * s), CGPoint(x: p.x + 5 * s, y: p.y), CGPoint(x: p.x, y: p.y - 7 * s)], colour.opacity(0.8))
            }
        }
        if complete { fence(&g) }
        c = g.c
    }

    /// A low fence round a finished row or settlement.
    private static func fence(_ g: inout Geo) {
        let corners: [CGPoint] = [CGPoint(x: 0, y: -10.5), CGPoint(x: 21, y: 0), CGPoint(x: 0, y: 10.5), CGPoint(x: -21, y: 0)]
        for i in 0..<4 {
            let a = corners[i], b = corners[(i + 1) % 4]
            for t in stride(from: 0.0, to: 1.0, by: 0.2) {
                g.rect(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t - 1.5), 0.7, 3, Color(hex: "#A9805C"))
            }
        }
    }
}

/// Little drawing helpers in island units.
private struct Geo {
    var c: GraphicsContext
    let u: CGFloat

    func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * u, y: p.y * u) }

    mutating func poly(_ points: [CGPoint], _ colour: Color, alpha: Double = 1) {
        c.fill(Path { p in p.addLines(points.map(pt)); p.closeSubpath() }, with: .color(colour.opacity(alpha)))
    }

    mutating func ellipse(_ centre: CGPoint, _ w: CGFloat, _ h: CGFloat, _ colour: Color, alpha: Double = 1) {
        c.fill(Path(ellipseIn: CGRect(x: (centre.x - w / 2) * u, y: (centre.y - h / 2) * u, width: w * u, height: h * u)),
               with: .color(colour.opacity(alpha)))
    }

    /// A small upright rectangle centred on `centre`.
    mutating func rect(_ centre: CGPoint, _ w: CGFloat, _ h: CGFloat, _ colour: Color) {
        c.fill(Path(roundedRect: CGRect(x: (centre.x - w / 2) * u, y: (centre.y - h / 2) * u, width: w * u, height: h * u),
                    cornerRadius: min(w, h) * 0.3 * u), with: .color(colour))
    }

    mutating func diamond(_ centre: CGPoint, width w: CGFloat, _ colour: Color, alpha: Double = 1) {
        poly([CGPoint(x: centre.x, y: centre.y - w / 4), CGPoint(x: centre.x + w / 2, y: centre.y),
              CGPoint(x: centre.x, y: centre.y + w / 4), CGPoint(x: centre.x - w / 2, y: centre.y)], colour, alpha: alpha)
    }

    /// An isometric box standing on `base` (left face lighter, right face darker).
    mutating func box(_ base: CGPoint, w: CGFloat, h: CGFloat, left: Color, right: Color) {
        poly([CGPoint(x: base.x - w / 2, y: base.y), CGPoint(x: base.x, y: base.y + w / 4),
              CGPoint(x: base.x, y: base.y + w / 4 - h), CGPoint(x: base.x - w / 2, y: base.y - h)], left)
        poly([CGPoint(x: base.x, y: base.y + w / 4), CGPoint(x: base.x + w / 2, y: base.y),
              CGPoint(x: base.x + w / 2, y: base.y - h), CGPoint(x: base.x, y: base.y + w / 4 - h)], right)
        diamond(CGPoint(x: base.x, y: base.y - h), width: w, left)
    }

    mutating func pointedRoof(top: CGFloat, w: CGFloat, x: CGFloat = 0) {
        let rw = w + 2
        poly([CGPoint(x: x - rw / 2, y: top), CGPoint(x: x, y: top + rw / 4), CGPoint(x: x, y: top - w * 0.45)], .terracotta)
        poly([CGPoint(x: x, y: top + rw / 4), CGPoint(x: x + rw / 2, y: top), CGPoint(x: x, y: top - w * 0.45)], Color(hex: "#CF8569"))
    }

    mutating func dome(_ base: CGPoint, r: CGFloat, _ colour: Color) {
        let centre = pt(base)
        let path = Path { p in
            p.addArc(center: centre, radius: r * u, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addEllipse(in: CGRect(x: centre.x - r * u, y: centre.y - r * 0.3 * u, width: 2 * r * u, height: r * 0.6 * u))
        }
        c.fill(path, with: .color(colour))
        ellipse(CGPoint(x: base.x - r * 0.35, y: base.y - r * 0.55), r * 0.4, r * 0.28, .cream, alpha: 0.4)
    }
}
