import SwiftUI

/// Everything that quietly moves on the island: villagers in complete Places, travellers and
/// carts on the roads, smoke from chimneys, birds crossing, and baskets of produce waiting to be
/// collected. Calm, not busy. Positions are pure functions of time.
struct IslandLife: Equatable {
    var villagers: [Villager] = []
    var travellers: [Traveller] = []
    /// Grid points of chimneys (smoke rises from these), with how high above the ground (in u).
    var chimneys: [(point: CGPoint, height: CGFloat)] = []
    /// Baskets waiting above complete Places.
    var baskets: [Basket] = []

    struct Basket: Equatable {
        let bookID: String
        let point: CGPoint
        let count: Int
        let kind: ProduceKind
    }

    static func == (a: IslandLife, b: IslandLife) -> Bool {
        a.villagers == b.villagers && a.travellers == b.travellers && a.baskets == b.baskets
            && a.chimneys.map(\.point) == b.chimneys.map(\.point)
    }

    var isEmpty: Bool { villagers.isEmpty && travellers.isEmpty && chimneys.isEmpty && baskets.isEmpty }

    /// Everything for an island; `baskets` maps complete books to what's waiting in them.
    static func make(island: Island, baskets: [String: Int] = [:]) -> IslandLife {
        var life = IslandLife(villagers: VillagerData.villagers(island: island), travellers: Traveller.make(island: island))
        let homes: Set<PieceKind> = [.hut, .farmhouse, .house, .oven, .mill, .upperRoom, .houses]
        for item in island.items {
            guard case .piece(let kind) = item.kind, homes.contains(kind), item.total > 0, item.progress >= item.total else { continue }
            life.chimneys.append((CGPoint(x: item.gx, y: item.gy), 30 * PlaceArt.scale(item.span)))
        }
        for (bookID, count) in baskets.sorted(by: { $0.key < $1.key }) where count > 0 {
            guard let index = island.placeIndex(bookID) else { continue }
            let item = island.items[index]
            life.baskets.append(Basket(bookID: bookID, point: CGPoint(x: item.gx, y: item.gy), count: count,
                                       kind: PlaceData.spec(for: bookID).produce))
        }
        return life
    }

    // MARK: Drawing

    /// Draws the life that's on screen (`visible`, in view points), capped so it stays smooth.
    static func draw(_ c: inout GraphicsContext, life: IslandLife, layout: IslandLayout, time: TimeInterval, visible: CGRect) {
        let u = layout.u
        // Smoke first (it's behind the figures).
        for chimney in life.chimneys {
            let base = layout.point(chimney.point.x, chimney.point.y)
            guard visible.contains(base) else { continue }
            smoke(&c, at: CGPoint(x: base.x, y: base.y - chimney.height * u), time: time, u: u, seed: Int(chimney.point.x * 31 + chimney.point.y * 7))
        }
        var figures: [(depth: CGFloat, draw: (inout GraphicsContext) -> Void)] = []
        var shown = 0
        for v in life.villagers {
            let p = v.pose(at: time)
            let s = layout.point(p.point.x, p.point.y)
            guard visible.contains(s), shown < VillagerData.maxVisible else { continue }
            shown += 1
            figures.append((s.y, { g in villager(&g, at: s, pose: p, robe: v.robe, produce: v.produce, u: u, time: time) }))
        }
        for t in life.travellers {
            let p = t.position(at: time)
            let s = layout.point(p.point.x, p.point.y)
            guard visible.contains(s) else { continue }
            figures.append((s.y, { g in
                if t.cart { cart(&g, at: s, u: u, flip: p.facingLeft != layout.mirrored) }
                else {
                    villager(&g, at: s, pose: Villager.Pose(point: p.point, pose: .walk, carrying: true, facingLeft: p.facingLeft),
                             robe: t.robe, produce: .wool, u: u, time: time)
                }
            }))
        }
        for f in figures.sorted(by: { $0.depth < $1.depth }) { f.draw(&c) }
        birds(&c, size: visible.size, origin: visible.origin, time: time)
    }

    /// Baskets go on top of everything, so they're always easy to see and tap.
    static func drawBaskets(_ c: inout GraphicsContext, life: IslandLife, layout: IslandLayout, time: TimeInterval, visible: CGRect) {
        // Zoomed far out they'd cover the island: they appear as you come closer.
        guard layout.u >= minimumBasketU else { return }
        for basket in life.baskets {
            let s = layout.point(basket.point.x, basket.point.y)
            guard visible.contains(s) else { continue }
            Self.basket(&c, at: basketPoint(s, u: layout.u, time: time), count: basket.count, kind: basket.kind, u: layout.u)
        }
    }

    static let minimumBasketU: CGFloat = 0.55

    /// Where a basket floats, above its Place (bobbing gently).
    static func basketPoint(_ base: CGPoint, u: CGFloat, time: TimeInterval) -> CGPoint {
        CGPoint(x: base.x, y: base.y - 58 * u - CGFloat(sin(time * 2)) * 2 * u)
    }

    /// A chibi villager: a round head, a robe, and what they carry.
    static func villager(_ c: inout GraphicsContext, at p: CGPoint, pose: Villager.Pose, robe: Int, produce: ProduceKind,
                         u: CGFloat, time: TimeInterval) {
        let s = u * 0.9
        let robes = [Earthy.roofLight, Earthy.dome, Color(hex: "#E8D4B0"), Earthy.leaf, Earthy.goldDome, Color(hex: "#B9CBD8")]
        if pose.pose == .boat {
            var g = c
            g.translateBy(x: p.x, y: p.y)
            BuildingArt.boat(IsoPen(c: g, u: u), x: 0, y: 0, size: 0.55)
        }
        let bob: CGFloat = pose.pose == .walk ? -abs(CGFloat(sin(time * 8 + Double(robe)))) * 1.2 * s : 0
        let work: CGFloat = pose.pose == .work ? CGFloat(sin(time * 4 + Double(robe))) * 1.5 * s : 0
        let base = CGPoint(x: p.x, y: p.y - (pose.pose == .boat ? 4 * u : 0) + bob)
        c.fill(Path(ellipseIn: CGRect(x: base.x - 3 * s, y: base.y - 1.2 * s, width: 6 * s, height: 2.4 * s)),
               with: .color(Earthy.shadow.opacity(pose.pose == .boat ? 0 : 0.7)))
        c.fill(Path(roundedRect: CGRect(x: base.x - 2.6 * s, y: base.y - 8 * s, width: 5.2 * s, height: 8 * s), cornerRadius: 2.4 * s),
               with: .color(robes[abs(robe) % robes.count]))
        c.fill(Path(ellipseIn: CGRect(x: base.x - 2.5 * s + work, y: base.y - 13 * s, width: 5 * s, height: 5 * s)),
               with: .color(Color(hex: robe % 3 == 0 ? "#C99474" : "#DDAE8C")))
        c.fill(Path(ellipseIn: CGRect(x: base.x - 2.7 * s + work, y: base.y - 13.6 * s, width: 5.4 * s, height: 2.6 * s)),
               with: .color(Color(hex: robe % 2 == 0 ? "#6E4E3A" : "#F1E6D7")))
        if pose.carrying {
            let x = base.x + (pose.facingLeft ? -3.6 : 3.6) * s
            c.fill(Path(roundedRect: CGRect(x: x - 2 * s, y: base.y - 7 * s, width: 4 * s, height: 3 * s), cornerRadius: 1 * s),
                   with: .color(Earthy.woodLight))
            c.fill(Path(ellipseIn: CGRect(x: x - 1.6 * s, y: base.y - 8.4 * s, width: 3.2 * s, height: 2 * s)), with: .color(colour(produce)))
        }
    }

    static func cart(_ c: inout GraphicsContext, at p: CGPoint, u: CGFloat, flip: Bool) {
        let s = u
        let dir: CGFloat = flip ? -1 : 1
        c.fill(Path(ellipseIn: CGRect(x: p.x - 7 * s, y: p.y - 1.5 * s, width: 14 * s, height: 3 * s)), with: .color(Earthy.shadow.opacity(0.7)))
        c.fill(Path(roundedRect: CGRect(x: p.x - 6 * s, y: p.y - 8 * s, width: 12 * s, height: 5 * s), cornerRadius: 1 * s), with: .color(Earthy.wood))
        c.fill(Path(ellipseIn: CGRect(x: p.x - 5 * s, y: p.y - 5 * s, width: 4 * s, height: 4 * s)), with: .color(Earthy.woodDeep))
        c.fill(Path(ellipseIn: CGRect(x: p.x + 1 * s, y: p.y - 5 * s, width: 4 * s, height: 4 * s)), with: .color(Earthy.woodDeep))
        c.fill(Path(ellipseIn: CGRect(x: p.x - 4 * s, y: p.y - 11 * s, width: 8 * s, height: 4 * s)), with: .color(Earthy.goldShine))
        // A donkey in front.
        let d = CGPoint(x: p.x + dir * 10 * s, y: p.y)
        c.fill(Path(roundedRect: CGRect(x: d.x - 3.5 * s, y: d.y - 7 * s, width: 7 * s, height: 4 * s), cornerRadius: 2 * s), with: .color(Color(hex: "#B7A595")))
        c.fill(Path(ellipseIn: CGRect(x: d.x + dir * 3 * s - 1.5 * s, y: d.y - 9.5 * s, width: 3 * s, height: 3.5 * s)), with: .color(Color(hex: "#A29081")))
    }

    static func smoke(_ c: inout GraphicsContext, at p: CGPoint, time: TimeInterval, u: CGFloat, seed: Int) {
        for i in 0..<3 {
            let t = (time * 0.25 + Double(i) / 3 + Double(abs(seed) % 10) / 10).truncatingRemainder(dividingBy: 1)
            let y = p.y - CGFloat(t) * 26 * u
            let x = p.x + CGFloat(sin(t * 5 + Double(seed))) * 3 * u + CGFloat(t) * 6 * u
            let r = (2 + CGFloat(t) * 4) * u
            c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(Color.white.opacity(0.5 * (1 - t))))
        }
    }

    /// A few birds crossing the sky now and then, in screen space.
    static func birds(_ c: inout GraphicsContext, size: CGSize, origin: CGPoint, time: TimeInterval) {
        let period = 38.0
        let t = time.truncatingRemainder(dividingBy: period) / 14 // crossing takes 14 s, then a long pause
        guard t < 1 else { return }
        let x = origin.x - 40 + CGFloat(t) * (size.width + 80)
        let y = origin.y + size.height * 0.22 + CGFloat(sin(t * 3)) * 12
        for i in 0..<3 {
            let bx = x - CGFloat(i) * 16, by = y + CGFloat(i % 2) * 9 + CGFloat(i) * 4
            let flap = CGFloat(sin(time * 7 + Double(i))) * 2.5
            var path = Path()
            path.move(to: CGPoint(x: bx - 5, y: by - flap))
            path.addQuadCurve(to: CGPoint(x: bx, y: by), control: CGPoint(x: bx - 2.5, y: by - 3 - flap))
            path.addQuadCurve(to: CGPoint(x: bx + 5, y: by - flap), control: CGPoint(x: bx + 2.5, y: by - 3 - flap))
            c.stroke(path, with: .color(Color.primaryBrown.opacity(0.45)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }

    /// A little basket with its produce and a count, to tap and collect.
    static func basket(_ c: inout GraphicsContext, at p: CGPoint, count: Int, kind: ProduceKind, u: CGFloat) {
        let s = u * 1.1
        c.fill(Path(ellipseIn: CGRect(x: p.x - 14 * s, y: p.y - 14 * s, width: 28 * s, height: 28 * s)), with: .color(Color.cream.opacity(0.95)))
        c.fill(Path(roundedRect: CGRect(x: p.x - 8 * s, y: p.y - 2 * s, width: 16 * s, height: 8 * s), cornerRadius: 3 * s), with: .color(Earthy.wood))
        c.stroke(Path { $0.addArc(center: CGPoint(x: p.x, y: p.y - 1 * s), radius: 7 * s, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false) },
                 with: .color(Earthy.woodDark), lineWidth: 1.5 * s)
        for i in 0..<3 {
            c.fill(Path(ellipseIn: CGRect(x: p.x + CGFloat(i - 1) * 4.5 * s - 2.6 * s, y: p.y - 5 * s, width: 5.2 * s, height: 4.4 * s)),
                   with: .color(colour(kind)))
        }
        let badge = CGPoint(x: p.x + 11 * s, y: p.y - 11 * s)
        c.fill(Path(ellipseIn: CGRect(x: badge.x - 6 * s, y: badge.y - 6 * s, width: 12 * s, height: 12 * s)), with: .color(Color.terracotta))
        c.draw(Text("\(count)").font(.system(size: 8 * s, weight: .bold)).foregroundStyle(Color.white), at: badge)
    }

    static func colour(_ kind: ProduceKind) -> Color {
        switch kind {
        case .fish: Color(hex: "#9DB8C6")
        case .bread: Color(hex: "#D9A86C")
        case .wheat: Earthy.gold
        case .grapes: Color(hex: "#9C7AB0")
        case .oil: Color(hex: "#C7B66A")
        case .fruit: Earthy.roofLight
        case .wool: Color(hex: "#F6F0E4")
        case .figs: Color(hex: "#8C6A86")
        }
    }
}
