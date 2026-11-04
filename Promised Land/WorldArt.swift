import SwiftUI

// MARK: - Shapes

/// The top face of an isometric tile.
struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
        }
    }
}

/// Geometry shared by the tile drawing and its tap area.
struct TileMetrics {
    let width: CGFloat
    var unit: CGFloat { width / 130 }
    var height: CGFloat { width / 2 }
    var depth: CGFloat { 14 * unit }
    /// Centre of the top diamond inside a `width × width` frame.
    var center: CGPoint { CGPoint(x: width / 2, y: width - height / 2 - depth) }
}

/// Tap area that matches the visible block (top + sides) of a tile.
struct TileHitShape: Shape {
    func path(in rect: CGRect) -> Path {
        let m = TileMetrics(width: rect.width)
        let c = m.center
        return Path { p in
            p.move(to: CGPoint(x: c.x, y: c.y - m.height / 2))
            p.addLine(to: CGPoint(x: c.x + m.width / 2, y: c.y))
            p.addLine(to: CGPoint(x: c.x + m.width / 2, y: c.y + m.depth))
            p.addLine(to: CGPoint(x: c.x, y: c.y + m.height / 2 + m.depth))
            p.addLine(to: CGPoint(x: c.x - m.width / 2, y: c.y + m.depth))
            p.addLine(to: CGPoint(x: c.x - m.width / 2, y: c.y))
            p.closeSubpath()
        }
    }
}

// MARK: - Tile view

struct PlaceTileView: View {
    let place: Place
    let level: GrowthLevel
    let width: CGFloat

    @State private var appeared = false

    var body: some View {
        let m = TileMetrics(width: width)
        ZStack {
            Canvas { context, _ in
                IsoPainter(context: context, m: m).draw(kind: place.kind, level: level)
            }
            .opacity(level == .locked ? 0.55 : 1)

            if level == .locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15 * m.unit, weight: .semibold))
                    .foregroundStyle(Color.secondaryText.opacity(0.7))
                    .position(x: m.center.x, y: m.center.y)
            } else if level == .flourishing {
                Image(systemName: "sparkles")
                    .font(.system(size: 18 * m.unit))
                    .foregroundStyle(Color.wheat)
                    .position(x: m.center.x + 34 * m.unit, y: m.center.y - 60 * m.unit)
                    .opacity(appeared ? 1 : 0.4)
                    .animation(.easeInOut(duration: 1.6).repeatForever(), value: appeared)
                    .onAppear { appeared = true }
            }
        }
        .frame(width: width, height: width)
        .contentShape(TileHitShape())
    }
}

// MARK: - Painter

/// Draws a tile's base block and its place illustration with soft, outline-free shapes.
struct IsoPainter {
    var context: GraphicsContext
    let m: TileMetrics

    private var u: CGFloat { m.unit }
    private var c: CGPoint { m.center }

    private static let oliveDeep = Color(hex: "#929E66")
    private static let trunk = Color(hex: "#A9805C")
    private static let waterDeep = Color(hex: "#93BEC6")

    func draw(kind: PlaceKind, level: GrowthLevel) {
        drawBase(kind: kind, level: level)
        guard level != .locked else { return }
        let n = level.rawValue
        switch kind {
        case .eden: drawEden(level: n)
        case .sinai: drawSinai(level: n)
        case .bethlehem: drawFields(level: n)
        case .temple: drawTemple(level: n)
        case .babylon: drawGate(level: n)
        case .galilee: drawGalilee(level: n)
        }
    }

    // MARK: Helpers

    private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: c.x + x * u, y: c.y + y * u)
    }

    /// Converts grid coordinates on the tile surface into a screen offset.
    private func iso(_ a: CGFloat, _ b: CGFloat) -> CGPoint {
        pt((a - b), (a + b) / 2)
    }

    private func fill(_ points: [CGPoint], _ color: Color) {
        var p = Path()
        p.addLines(points)
        p.closeSubpath()
        context.fill(p, with: .color(color))
    }

    private func ellipse(_ center: CGPoint, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
        let r = CGRect(x: center.x - w * u / 2, y: center.y - h * u / 2, width: w * u, height: h * u)
        context.fill(Path(ellipseIn: r), with: .color(color))
    }

    private func diamond(at center: CGPoint, width w: CGFloat, _ color: Color) {
        let r = CGRect(x: center.x - w / 2, y: center.y - w / 4, width: w, height: w / 2)
        context.fill(Diamond().path(in: r), with: .color(color))
    }

    /// An isometric box standing on `base` (the centre of its footprint).
    private func box(base: CGPoint, width w: CGFloat, height h: CGFloat,
                     top: Color, left: Color, right: Color) {
        let W = w * u, H = h * u
        fill([CGPoint(x: base.x - W / 2, y: base.y), CGPoint(x: base.x, y: base.y + W / 4),
              CGPoint(x: base.x, y: base.y + W / 4 - H), CGPoint(x: base.x - W / 2, y: base.y - H)], left)
        fill([CGPoint(x: base.x, y: base.y + W / 4), CGPoint(x: base.x + W / 2, y: base.y),
              CGPoint(x: base.x + W / 2, y: base.y - H), CGPoint(x: base.x, y: base.y + W / 4 - H)], right)
        diamond(at: CGPoint(x: base.x, y: base.y - H), width: W, top)
    }

    private func shadow(_ at: CGPoint, _ w: CGFloat) {
        ellipse(at, w, w * 0.45, Color.primaryBrown.opacity(0.10))
    }

    // MARK: Base

    private func drawBase(kind: PlaceKind, level: GrowthLevel) {
        let w = m.width, h = m.height, d = m.depth
        let left = CGPoint(x: c.x - w / 2, y: c.y)
        let right = CGPoint(x: c.x + w / 2, y: c.y)
        let bottom = CGPoint(x: c.x, y: c.y + h / 2)

        fill([left, bottom, CGPoint(x: bottom.x, y: bottom.y + d), CGPoint(x: left.x, y: left.y + d)], .stoneLight)
        fill([bottom, right, CGPoint(x: right.x, y: right.y + d), CGPoint(x: bottom.x, y: bottom.y + d)], .stoneShade)

        let ground: Color
        if level == .locked {
            ground = .sand
        } else {
            switch kind {
            case .eden: ground = Color.olive.opacity(0.75)
            case .sinai, .temple: ground = .stoneLight
            case .bethlehem, .babylon, .galilee: ground = .sand
            }
        }
        diamond(at: c, width: w, .sand)
        diamond(at: c, width: w, ground)
    }

    // MARK: Places

    private func tree(_ p: CGPoint, scale s: CGFloat = 1) {
        shadow(CGPoint(x: p.x, y: p.y + 1 * u), 20 * s)
        let trunk = CGRect(x: p.x - 2.5 * u * s, y: p.y - 16 * u * s, width: 5 * u * s, height: 16 * u * s)
        context.fill(Path(roundedRect: trunk, cornerRadius: 2.5 * u * s), with: .color(Self.trunk))
        ellipse(CGPoint(x: p.x + 3 * u * s, y: p.y - 22 * u * s), 22 * s, 18 * s, Self.oliveDeep)
        ellipse(CGPoint(x: p.x - 2 * u * s, y: p.y - 25 * u * s), 22 * s, 19 * s, .olive)
    }

    private func drawEden(level: Int) {
        let spots: [(CGFloat, CGFloat, CGFloat)] = [
            (-10, -14, 1.0), (16, -4, 1.1), (-20, 6, 0.9), (8, 16, 1.0),
        ]
        // Back-to-front so nearer trees overlap farther ones.
        for s in spots.prefix(level + 1).sorted(by: { $0.0 + $0.1 < $1.0 + $1.1 }) {
            tree(iso(s.0, s.1), scale: s.2)
        }
        if level >= 3 {
            for (a, b) in [(-28.0, -6.0), (24.0, 14.0), (-4.0, 26.0)] {
                ellipse(iso(a, b), 5, 4, .terracotta)
                ellipse(iso(a + 4, b + 2), 4, 3, .lavender)
            }
        }
    }

    private func drawSinai(level: Int) {
        let base = pt(0, 6)
        let towerH: CGFloat = [34, 46, 58][level - 1]
        let w: CGFloat = 36
        shadow(CGPoint(x: base.x, y: base.y + 6 * u), 50)
        box(base: base, width: w, height: towerH, top: .stoneLight, left: .stoneLight, right: .stoneShade)

        // Little window on each face.
        ellipse(CGPoint(x: base.x - 9 * u, y: base.y - towerH * u * 0.55), 5, 8, .stoneShade)
        ellipse(CGPoint(x: base.x + 9 * u, y: base.y - towerH * u * 0.55), 5, 8, Color.primaryBrown.opacity(0.18))

        // Terracotta pyramid roof.
        let t = CGPoint(x: base.x, y: base.y - towerH * u)
        let W = (w + 6) * u
        let apex = CGPoint(x: t.x, y: t.y - 24 * u)
        fill([CGPoint(x: t.x - W / 2, y: t.y), CGPoint(x: t.x, y: t.y + W / 4), apex], .terracotta)
        fill([CGPoint(x: t.x, y: t.y + W / 4), CGPoint(x: t.x + W / 2, y: t.y), apex], Color(hex: "#CF8569"))

        if level >= 2 {
            // Rocks at the foot of the mountain.
            ellipse(iso(-26, 10), 14, 8, .stoneShade)
            ellipse(iso(22, -18), 10, 6, .stoneShade)
        }
        if level >= 3 {
            let pole = CGRect(x: apex.x - 0.75 * u, y: apex.y - 14 * u, width: 1.5 * u, height: 14 * u)
            context.fill(Path(roundedRect: pole, cornerRadius: u), with: .color(Self.trunk))
            fill([CGPoint(x: apex.x, y: apex.y - 14 * u), CGPoint(x: apex.x + 10 * u, y: apex.y - 11 * u),
                  CGPoint(x: apex.x, y: apex.y - 8 * u)], .lavender)
        }
    }

    private func drawFields(level: Int) {
        let span = level + 1 // 2, 3, 4
        let step: CGFloat = 24 / CGFloat(span) // keeps stalks inside the tile
        var spots: [CGPoint] = []
        for a in -span...span {
            for b in -span...span {
                spots.append(iso(CGFloat(a) * step, CGFloat(b) * step))
            }
        }
        // Soft furrows.
        diamond(at: c, width: m.width * 0.78, Color.wheat.opacity(0.35))
        for p in spots.sorted(by: { $0.y < $1.y }) {
            let stalk = CGRect(x: p.x - 0.8 * u, y: p.y - 12 * u, width: 1.6 * u, height: 12 * u)
            context.fill(Path(roundedRect: stalk, cornerRadius: u), with: .color(Color.olive))
            ellipse(CGPoint(x: p.x, y: p.y - 14 * u), 4, 8, .wheat)
        }
        if level >= 3 {
            // A small sheaf bundle.
            let s = iso(30, -26)
            ellipse(CGPoint(x: s.x, y: s.y - 6 * u), 10, 16, Color(hex: "#DDB466"))
            ellipse(CGPoint(x: s.x, y: s.y - 6 * u), 11, 3, .terracotta)
        }
    }

    private func drawTemple(level: Int) {
        let base = pt(0, 6)
        let w: CGFloat = 62
        let h: CGFloat = level >= 2 ? 26 : 20
        shadow(CGPoint(x: base.x, y: base.y + 8 * u), 80)
        box(base: base, width: w, height: h, top: .stoneLight, left: .stoneLight, right: .stoneShade)

        // Doorways.
        let door = CGRect(x: base.x - 18 * u, y: base.y - 3 * u - 12 * u, width: 7 * u, height: 12 * u)
        context.fill(Path(roundedRect: door, cornerRadius: 3.5 * u), with: .color(Color.primaryBrown.opacity(0.18)))
        let door2 = door.offsetBy(dx: 29 * u, dy: 0)
        context.fill(Path(roundedRect: door2, cornerRadius: 3.5 * u), with: .color(Color.primaryBrown.opacity(0.22)))

        // Lavender dome.
        let top = CGPoint(x: base.x, y: base.y - h * u)
        let r: CGFloat = (level >= 3 ? 20 : 17) * u
        var dome = Path()
        dome.addArc(center: top, radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        dome.addEllipse(in: CGRect(x: top.x - r, y: top.y - r * 0.3, width: 2 * r, height: r * 0.6))
        context.fill(dome, with: .color(.lavender))
        ellipse(CGPoint(x: top.x - r * 0.35, y: top.y - r * 0.55), 7, 5, Color.white.opacity(0.35))

        if level >= 2 {
            // Columns along the front edges.
            for i in 0..<3 {
                let x = base.x - 27 * u + CGFloat(i) * 8 * u
                let y = base.y + (CGFloat(i) * 4 + 3) * u
                let col = CGRect(x: x - 1.5 * u, y: y - 14 * u, width: 3 * u, height: 14 * u)
                context.fill(Path(roundedRect: col, cornerRadius: 1.5 * u), with: .color(Color.cream))
            }
        }
        if level >= 3 {
            ellipse(CGPoint(x: top.x, y: top.y - r - 3 * u), 6, 6, .wheat)
        }
    }

    private func drawGate(level: Int) {
        let base = pt(0, 8)
        let halfW: CGFloat = 30 * u
        let wallH: CGFloat = 50 * u
        let depthX: CGFloat = 12 * u, depthY: CGFloat = 6 * u
        shadow(CGPoint(x: base.x + 4 * u, y: base.y + 2 * u), 84)

        // Side face for depth.
        fill([CGPoint(x: base.x + halfW, y: base.y), CGPoint(x: base.x + halfW + depthX, y: base.y - depthY),
              CGPoint(x: base.x + halfW + depthX, y: base.y - depthY - wallH), CGPoint(x: base.x + halfW, y: base.y - wallH)],
             .stoneShade)
        // Top face.
        fill([CGPoint(x: base.x - halfW, y: base.y - wallH), CGPoint(x: base.x + halfW, y: base.y - wallH),
              CGPoint(x: base.x + halfW + depthX, y: base.y - wallH - depthY),
              CGPoint(x: base.x - halfW + depthX, y: base.y - wallH - depthY)], Color(hex: "#F7E2C0"))

        // Front wall with an arched opening (even-odd fill leaves the arch open).
        var wall = Path(roundedRect: CGRect(x: base.x - halfW, y: base.y - wallH, width: 2 * halfW, height: wallH),
                        cornerRadius: 3 * u)
        let archW: CGFloat = 22 * u, archH: CGFloat = 32 * u
        var arch = Path()
        arch.move(to: CGPoint(x: base.x - archW / 2, y: base.y))
        arch.addLine(to: CGPoint(x: base.x - archW / 2, y: base.y - archH + archW / 2))
        arch.addArc(center: CGPoint(x: base.x, y: base.y - archH + archW / 2), radius: archW / 2,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        arch.addLine(to: CGPoint(x: base.x + archW / 2, y: base.y))
        arch.closeSubpath()
        wall.addPath(arch)
        context.fill(arch, with: .color(Color.primaryBrown.opacity(0.16)))
        context.fill(wall, with: .color(.stoneLight), style: FillStyle(eoFill: true))

        // Crenellations.
        for i in 0..<4 {
            let x = base.x - halfW + 4 * u + CGFloat(i) * 15 * u
            let r = CGRect(x: x, y: base.y - wallH - 7 * u, width: 8 * u, height: 8 * u)
            context.fill(Path(roundedRect: r, cornerRadius: 2 * u), with: .color(.terracotta))
        }

        if level >= 2 {
            // Glazed lavender band.
            let band = CGRect(x: base.x - halfW, y: base.y - wallH + 10 * u, width: 2 * halfW, height: 5 * u)
            context.fill(Path(band), with: .color(Color.lavender.opacity(0.9)))
        }
        if level >= 3 {
            for x in [base.x - halfW - 6 * u, base.x + halfW + depthX + 4 * u] {
                let pole = CGRect(x: x, y: base.y - 30 * u, width: 1.6 * u, height: 30 * u)
                context.fill(Path(roundedRect: pole, cornerRadius: u), with: .color(Self.trunk))
                fill([CGPoint(x: x + 1.6 * u, y: base.y - 30 * u), CGPoint(x: x + 10 * u, y: base.y - 26 * u),
                      CGPoint(x: x + 1.6 * u, y: base.y - 22 * u)], .terracotta)
            }
        }
    }

    private func boat(_ p: CGPoint, scale s: CGFloat) {
        ellipse(CGPoint(x: p.x, y: p.y + 3 * u * s), 34 * s, 7 * s, Self.waterDeep)
        fill([CGPoint(x: p.x - 16 * u * s, y: p.y - 4 * u * s), CGPoint(x: p.x + 16 * u * s, y: p.y - 4 * u * s),
              CGPoint(x: p.x + 11 * u * s, y: p.y + 3 * u * s), CGPoint(x: p.x - 11 * u * s, y: p.y + 3 * u * s)],
             .terracotta)
        let mast = CGRect(x: p.x - 0.8 * u * s, y: p.y - 30 * u * s, width: 1.6 * u * s, height: 26 * u * s)
        context.fill(Path(roundedRect: mast, cornerRadius: u), with: .color(Self.trunk))
        fill([CGPoint(x: p.x + 1.5 * u * s, y: p.y - 29 * u * s), CGPoint(x: p.x + 14 * u * s, y: p.y - 7 * u * s),
              CGPoint(x: p.x + 1.5 * u * s, y: p.y - 7 * u * s)], .cream)
    }

    private func drawGalilee(level: Int) {
        diamond(at: c, width: m.width * 0.82, .water)
        diamond(at: pt(4, 2), width: m.width * 0.5, Self.waterDeep.opacity(0.5))
        // Gentle ripples.
        for (a, b) in [(-24.0, -6.0), (18.0, 20.0), (-6.0, 22.0)] {
            ellipse(iso(a, b), 10, 2.5, Color.white.opacity(0.5))
        }
        boat(pt(-4, 2), scale: 1)
        if level >= 2 {
            boat(pt(26, -8), scale: 0.6)
        }
        if level >= 3 {
            // Reeds on the shore.
            for (i, x) in [-46.0, -42.0, -38.0].enumerated() {
                let p = pt(x, 2 + Double(i) * 2)
                let reed = CGRect(x: p.x, y: p.y - 12 * u, width: 1.6 * u, height: 12 * u)
                context.fill(Path(roundedRect: reed, cornerRadius: u), with: .color(.olive))
            }
        }
    }
}
