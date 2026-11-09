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
    /// Where each villager and traveller can be (grid rects), for culling before any pose maths.
    var villagerHomes: [CGRect] = []
    var travellerHomes: [CGRect] = []
    /// The island's extent in grid units (centre and half-size), for the birds' flight across it.
    var sky = CGRect(x: 0, y: 0, width: 8, height: 8)

    struct Basket: Equatable {
        let bookID: String
        let point: CGPoint
        let count: Int
        let kind: ProduceKind
    }

    static func == (a: IslandLife, b: IslandLife) -> Bool {
        a.villagers == b.villagers && a.travellers == b.travellers && a.baskets == b.baskets
            && a.chimneys.map(\.point) == b.chimneys.map(\.point) && a.sky == b.sky
    }

    var isEmpty: Bool { villagers.isEmpty && travellers.isEmpty && chimneys.isEmpty && baskets.isEmpty }

    /// Everything for an island; `baskets` maps complete books to what's waiting in them.
    static func make(island: Island, baskets: [String: Int] = [:]) -> IslandLife {
        var life = IslandLife(villagers: VillagerData.villagers(island: island), travellers: Traveller.make(island: island))
        life.villagerHomes = life.villagers.map(\.bounds)
        life.travellerHomes = life.travellers.map(\.bounds)
        if let x0 = island.tiles.map(\.x).min(), let x1 = island.tiles.map(\.x).max(),
           let y0 = island.tiles.map(\.y).min(), let y1 = island.tiles.map(\.y).max() {
            life.sky = CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1)
        }
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

    /// The figures near the screen this frame, for the `LifeDirector` (ids "v<i>" villagers,
    /// "t<i>" travellers). Anything whose home is off screen isn't even listed.
    func figures(layout: IslandLayout, viewport: CGRect) -> [LifeDirector.Figure] {
        var out: [LifeDirector.Figure] = []
        for (i, v) in villagers.enumerated() {
            let home = Self.screenRect(villagerHomes[i], layout: layout)
            guard home.intersects(viewport) else { continue }
            out.append(.init(id: "v\(i)", home: home, position: { t in let p = v.pose(at: t).point; return layout.point(p.x, p.y) }))
        }
        for (i, tr) in travellers.enumerated() {
            let home = Self.screenRect(travellerHomes[i], layout: layout)
            guard home.intersects(viewport) else { continue }
            out.append(.init(id: "t\(i)", home: home, position: { t in let p = tr.position(at: t).point; return layout.point(p.x, p.y) }))
        }
        return out
    }

    /// A grid rect's bounds on screen (with a margin for the figure's height).
    static func screenRect(_ r: CGRect, layout: IslandLayout) -> CGRect {
        // Called for every figure every frame: no arrays.
        let a = layout.point(r.minX, r.minY), b = layout.point(r.maxX, r.minY)
        let c = layout.point(r.minX, r.maxY), d = layout.point(r.maxX, r.maxY)
        let x0 = min(a.x, b.x, c.x, d.x), x1 = max(a.x, b.x, c.x, d.x)
        let y0 = min(a.y, b.y, c.y, d.y), y1 = max(a.y, b.y, c.y, d.y)
        let m = 16 * layout.u
        return CGRect(x: x0 - m, y: y0 - 2 * m, width: x1 - x0 + 2 * m, height: y1 - y0 + 3 * m)
    }

    /// Smoke from chimneys on screen (a single soft puff when far out). Drawn above the world layer:
    /// it rises above the roofs.
    static func drawSmoke(_ c: inout GraphicsContext, life: IslandLife, tier: LODTier, layout: IslandLayout,
                          time: TimeInterval, visible: CGRect) -> Int {
        let u = layout.u
        var count = 0
        for chimney in life.chimneys {
            let base = layout.point(chimney.point.x, chimney.point.y)
            guard visible.contains(base) else { continue }
            smoke(&c, at: CGPoint(x: base.x, y: base.y - chimney.height * u), time: time, u: u,
                  seed: Int(chimney.point.x * 31 + chimney.point.y * 7), puffs: tier == .far ? 1 : 3)
            count += 1
        }
        return count
    }

    /// Far out: just a couple of boats out on the water (drawn on the water, under everything else).
    static func drawFarBoats(_ c: inout GraphicsContext, life: IslandLife, director: LifeDirector, layout: IslandLayout,
                             time: TimeInterval, visible: CGRect) -> Int {
        var boats = 0
        for (i, v) in life.villagers.enumerated() where boats < IslandLOD.farBoats && v.routine.waypoints.contains(where: { $0.pose == .boat }) {
            guard screenRect(life.villagerHomes[i], layout: layout).intersects(visible) else { continue }
            let p = v.pose(at: director.time("v\(i)", now: time))
            guard p.pose == .boat else { continue }
            villager(&c, at: layout.point(p.point.x, p.point.y), pose: p, robe: v.robe, produce: v.produce, u: layout.u, time: time)
            boats += 1
        }
        return boats
    }

    /// One villager or traveller the director chose, at its own time and fade.
    static func drawFigure(_ c: inout GraphicsContext, _ f: LifeDirector.Shown, life: IslandLife, layout: IslandLayout) {
        var g = c
        g.opacity = f.opacity
        let u = layout.u
        if f.id.hasPrefix("v"), let i = Int(f.id.dropFirst()), life.villagers.indices.contains(i) {
            let v = life.villagers[i]
            villager(&g, at: f.point, pose: v.pose(at: f.time), robe: v.robe, produce: v.produce, u: u, time: f.time)
        } else if f.id.hasPrefix("t"), let i = Int(f.id.dropFirst()), life.travellers.indices.contains(i) {
            let t = life.travellers[i]
            let p = t.position(at: f.time)
            if t.cart { cart(&g, at: f.point, u: u, flip: p.facingLeft != layout.mirrored) }
            else {
                villager(&g, at: f.point, pose: Villager.Pose(point: p.point, pose: .walk, carrying: true, facingLeft: p.facingLeft),
                         robe: t.robe, produce: t.carrying, u: u, time: f.time)
            }
        }
    }

    /// The screen rect a villager or traveller covers (for depth against buildings).
    static func figureRect(_ f: LifeDirector.Shown, u: CGFloat) -> CGRect {
        CGRect(x: f.point.x - 4 * u, y: f.point.y - 15 * u, width: 8 * u, height: 15 * u)
    }

    /// Baskets go on top of everything, so they're always easy to see and tap.
    static func drawBaskets(_ c: inout GraphicsContext, life: IslandLife, layout: IslandLayout, time: TimeInterval, visible: CGRect) {
        // Zoomed far out they'd cover the island: they appear as you come closer.
        guard layout.u >= minimumBasketU else { return }
        // Each basket is a cached picture (its shapes and count drawn once per count, produce and
        // size), not redrawn every frame: laying out the count's text alone was a large share
        // of a frame with many baskets on screen.
        let ub = CGFloat(pow(1.25, ceil(log(Double(max(0.05, layout.u))) / log(1.25))))
        let half = 19 * ub * 1.1
        let k = layout.u / ub
        for basket in life.baskets {
            let s = layout.point(basket.point.x, basket.point.y)
            guard visible.contains(s) else { continue }
            let p = basketPoint(s, u: layout.u, time: time)
            let key = "basket|\(basket.kind)|\(basket.count)|\(Int(ub * 1000))"
            if let image = IslandRenderCache.shared.picture(key, size: CGSize(width: 2 * half, height: 2 * half), draw: { g in
                Self.basket(&g, at: CGPoint(x: half, y: half), count: basket.count, kind: basket.kind, u: ub)
            }) {
                c.draw(Image(decorative: image, scale: 1),
                       in: CGRect(x: p.x - half * k, y: p.y - half * k, width: 2 * half * k, height: 2 * half * k))
            } else {
                Self.basket(&c, at: p, count: basket.count, kind: basket.kind, u: layout.u)
            }
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

    static func smoke(_ c: inout GraphicsContext, at p: CGPoint, time: TimeInterval, u: CGFloat, seed: Int, puffs: Int = 3) {
        for i in 0..<puffs {
            let t = (time * 0.25 + Double(i) / 3 + Double(abs(seed) % 10) / 10).truncatingRemainder(dividingBy: 1)
            let y = p.y - CGFloat(t) * 26 * u
            let x = p.x + CGFloat(sin(t * 5 + Double(seed))) * 3 * u + CGFloat(t) * 6 * u
            let r = (2 + CGFloat(t) * 4) * u
            c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(Color.white.opacity(0.5 * (1 - t))))
        }
    }

    /// A few birds crossing the island now and then. They fly in the island's own space (a line
    /// across its grid, high above the ground), so they pan, zoom and turn with it.
    static func birds(_ c: inout GraphicsContext, layout: IslandLayout, sky: CGRect, visible: CGRect, time: TimeInterval) {
        let t = birdProgress(time)
        guard t < 1 else { return }
        let leader = birdPoint(t, sky: sky)
        let u = layout.u
        let altitude = 70 * u
        let s = max(0.8, min(2.4, u)) // wing size: grows a little with zoom, never vanishes or swamps
        for i in 0..<3 {
            // The flock trails behind the leader along the grid's diagonal.
            let g = CGPoint(x: leader.x - CGFloat(i) * 0.45, y: leader.y + CGFloat(i % 2) * 0.35 - CGFloat(i) * 0.1)
            let p = layout.point(g.x, g.y)
            let bx = p.x, by = p.y - altitude + CGFloat(sin(t * 3)) * 6 * u
            guard visible.insetBy(dx: -20, dy: -20).contains(CGPoint(x: bx, y: by)) else { continue }
            let flap = CGFloat(sin(time * 7 + Double(i))) * 2.5 * s
            var path = Path()
            path.move(to: CGPoint(x: bx - 5 * s, y: by - flap))
            path.addQuadCurve(to: CGPoint(x: bx, y: by), control: CGPoint(x: bx - 2.5 * s, y: by - 3 * s - flap))
            path.addQuadCurve(to: CGPoint(x: bx + 5 * s, y: by - flap), control: CGPoint(x: bx + 2.5 * s, y: by - 3 * s - flap))
            c.stroke(path, with: .color(Color.primaryBrown.opacity(0.45)), style: StrokeStyle(lineWidth: 1.4 * min(1.5, s), lineCap: .round))
        }
    }

    /// How far through a crossing the flock is (0…1), or ≥ 1 during the pause between crossings.
    static func birdProgress(_ time: TimeInterval) -> Double {
        time.truncatingRemainder(dividingBy: 38) / 14 // crossing takes 14 s, then a long pause
    }

    /// Where the flock's leader is on the island's grid, `t` of the way across (from beyond one
    /// corner of the island to beyond the opposite one).
    static func birdPoint(_ t: Double, sky: CGRect) -> CGPoint {
        let from = CGPoint(x: sky.minX - 3, y: sky.midY + sky.height * 0.15)
        let to = CGPoint(x: sky.maxX + 3, y: sky.midY - sky.height * 0.15)
        return CGPoint(x: from.x + (to.x - from.x) * CGFloat(t), y: from.y + (to.y - from.y) * CGFloat(t))
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
