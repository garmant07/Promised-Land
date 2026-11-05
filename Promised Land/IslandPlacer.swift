import Foundation

/// Lays out Places loosely around the central plaza (the starting square and the Library).
/// Each new Place goes in the nearest pleasant free spot: never overlapping, with at least one
/// tile of breathing room, and always within two tiles of land already there, so the island stays
/// one piece. A light bias puts Old Testament Places on the left (as you look at the island) and
/// New Testament Places on the right. Waterside Places also need room for a bay of open water on
/// their outer side, so they sit on the coast. Places you've moved yourself are reserved first and
/// never moved. Everything follows from the order books were first read, so nothing moves on its own.
struct IslandPlacer {
    /// The starting square (2 × 2 tiles from the origin), where your character begins.
    static let start = (x: 0, y: 0, size: 2)
    /// The Library's default spot, beside the starting square: together they are the plaza.
    static let library = (x: -3, y: -3, size: 2)
    static let forestSize = 5

    /// Tiles taken by Places, the plaza and bays (nothing else may be built on them).
    private(set) var core: Set<Island.Tile> = []
    /// Tiles inside Places and the plaza (roads go around these).
    private(set) var blocked: Set<Island.Tile> = []
    private var regions: [(x: Int, y: Int, size: Int)] = []
    private(set) var water: Set<Island.Tile> = []
    private let placements: [String: IslandPlacement]
    /// Saved places that overlap another (only possible mid-drag in edit mode).
    private(set) var conflicts: Set<String> = []
    private var libraryPlace: (x: Int, y: Int)
    private var reservedBays: [String: Int] = [:]

    /// - Parameters:
    ///   - placements: saved places, reserved before anything is laid out automatically.
    ///   - keys: the books (and feature keys) being laid out, to reserve their saved places.
    init(placements: [String: IslandPlacement] = [:], keys: [String] = []) {
        self.placements = placements
        let lib = placements[IslandPlacement.libraryKey]
        libraryPlace = lib.map { ($0.x, $0.y) } ?? (Self.library.x, Self.library.y)
        mark(Self.start.x, Self.start.y, Self.start.size)
        var reserved: [(key: String, x: Int, y: Int, size: Int, bay: [Island.Tile], side: Int?)] = [
            (IslandPlacement.libraryKey, libraryPlace.x, libraryPlace.y, Self.library.size, [], nil)
        ]
        for key in keys {
            guard let p = placements[key], let size = Self.size(of: key) else { continue }
            let waterside = BibleCatalog.book(id: key) != nil && PlaceData.spec(for: key).isWaterside
            let side = waterside ? Self.outwardSide(x: p.x, y: p.y, size: size) : nil
            reserved.append((key, p.x, p.y, size, side.map { Self.bay(x: p.x, y: p.y, size: size, side: $0) } ?? [], side))
        }
        for r in reserved {
            if !fits(r.x, r.y, r.size, gap: 1) || r.bay.contains(where: { core.contains($0) }) { conflicts.insert(r.key) }
            mark(r.x, r.y, r.size)
            for t in r.bay { core.insert(t); water.insert(t) }
            if let side = r.side { reservedBays[r.key] = side }
        }
    }

    static func size(of key: String) -> Int? {
        if key == IslandPlacement.forestKey { return forestSize }
        return BibleCatalog.book(id: key).map { _ in PlaceData.spec(for: key).size }
    }

    var libraryPlot: Island.Plot {
        Island.Plot(bookID: IslandPlacement.libraryKey, x: libraryPlace.x, y: libraryPlace.y, size: Self.library.size,
                    rotation: placements[IslandPlacement.libraryKey]?.rotation ?? 0)
    }

    /// The throne room's spot: past the furthest land on the New Testament (right) side.
    mutating func placeThrone() -> Island.Plot {
        let all = regions + [(x: Self.start.x, y: Self.start.y, size: Self.start.size)]
        let far = all.max { ($0.x - $0.y) < ($1.x - $1.y) }!
        let x = far.x + far.size + 2, y = far.y
        mark(x, y, 2)
        regions.append((x, y, 2))
        return Island.Plot(bookID: "feature:throne", x: x, y: y, size: 2)
    }

    // MARK: Placing

    /// Candidate centres around the plaza, nearest first, leaning to one Testament's side.
    private static let candidatesOld = ordered(lean: 1)
    private static let candidatesNew = ordered(lean: -1)

    private static func ordered(lean: Double) -> [(dx: Int, dy: Int)] {
        let r = 44
        var all: [(dx: Int, dy: Int, cost: Double)] = []
        for dy in -r...r {
            for dx in -r...r {
                let d = hypot(Double(dx), Double(dy))
                // On screen, +y − x is to the left: the Old Testament side.
                let across = Double(dy - dx) / 1.414 * lean
                let cost = d - 0.55 * max(-4, min(4, across)) + (across < -1 ? 1.5 : 0)
                all.append((dx, dy, cost))
            }
        }
        return all.sorted { ($0.cost, $0.dy, $0.dx) < ($1.cost, $1.dy, $1.dx) }.map { ($0.dx, $0.dy) }
    }

    /// Places a Place (or the forest), or returns its saved spot.
    mutating func place(_ key: String, size: Int, waterside: Bool, testament: Testament) -> Island.Plot {
        if let p = placements[key] {
            regions.append((p.x, p.y, size))
            blockInside(p.x, p.y, size)
            return Island.Plot(bookID: key, x: p.x, y: p.y, size: size, rotation: p.rotation, bay: reservedBays[key])
        }
        let candidates = testament == .old ? Self.candidatesOld : Self.candidatesNew
        // Waterside Places look a little further out first, so their bay faces open sea.
        var fallback: Island.Plot?
        for c in candidates {
            let x = 1 + c.dx - size / 2, y = 1 + c.dy - size / 2
            guard fits(x, y, size, gap: 1), touchesLand(x, y, size) else { continue }
            if waterside {
                let side = Self.outwardSide(x: x, y: y, size: size)
                let bay = Self.bay(x: x, y: y, size: size, side: side)
                guard bay.allSatisfy({ !core.contains($0) && !near($0, distance: 1) }) else { continue }
                mark(x, y, size)
                for t in bay { core.insert(t); water.insert(t) }
                regions.append((x, y, size))
                blockInside(x, y, size)
                return Island.Plot(bookID: key, x: x, y: y, size: size, bay: side)
            }
            fallback = Island.Plot(bookID: key, x: x, y: y, size: size)
            break
        }
        let plot = fallback ?? Island.Plot(bookID: key, x: 60, y: 60, size: size)
        mark(plot.x, plot.y, size)
        regions.append((plot.x, plot.y, size))
        blockInside(plot.x, plot.y, size)
        return plot
    }

    /// The side of a plot that faces away from the plaza (0 +y, 1 +x, 2 −y, 3 −x).
    static func outwardSide(x: Int, y: Int, size: Int) -> Int {
        let cx = Double(x) + Double(size) / 2 - 1, cy = Double(y) + Double(size) / 2 - 1
        if abs(cx) > abs(cy) { return cx >= 0 ? 1 : 3 }
        return cy >= 0 ? 0 : 2
    }

    /// A bay: two tiles of water beyond a plot's side (one tile of shore in between).
    static func bay(x: Int, y: Int, size: Int, side: Int) -> [Island.Tile] {
        switch side {
        case 0: (x..<(x + size)).flatMap { tx in [Island.Tile(x: tx, y: y + size + 1), Island.Tile(x: tx, y: y + size + 2)] }
        case 1: (y..<(y + size)).flatMap { ty in [Island.Tile(x: x + size + 1, y: ty), Island.Tile(x: x + size + 2, y: ty)] }
        case 2: (x..<(x + size)).flatMap { tx in [Island.Tile(x: tx, y: y - 2), Island.Tile(x: tx, y: y - 3)] }
        default: (y..<(y + size)).flatMap { ty in [Island.Tile(x: x - 2, y: ty), Island.Tile(x: x - 3, y: ty)] }
        }
    }

    private func fits(_ x: Int, _ y: Int, _ size: Int, gap: Int) -> Bool {
        for ty in (y - gap)..<(y + size + gap) {
            for tx in (x - gap)..<(x + size + gap) where core.contains(Island.Tile(x: tx, y: ty)) { return false }
        }
        return true
    }

    /// Within two tiles of something already built (so the land joins up).
    private func touchesLand(_ x: Int, _ y: Int, _ size: Int) -> Bool {
        !fits(x, y, size, gap: 3)
    }

    private func near(_ t: Island.Tile, distance d: Int) -> Bool {
        for ty in (t.y - d)...(t.y + d) {
            for tx in (t.x - d)...(t.x + d) where blocked.contains(Island.Tile(x: tx, y: ty)) { return true }
        }
        return false
    }

    private mutating func mark(_ x: Int, _ y: Int, _ size: Int) {
        for ty in y..<(y + size) { for tx in x..<(x + size) { core.insert(Island.Tile(x: tx, y: ty)) } }
    }

    private mutating func blockInside(_ x: Int, _ y: Int, _ size: Int) {
        for ty in y..<(y + size) { for tx in x..<(x + size) { blocked.insert(Island.Tile(x: tx, y: ty)) } }
    }

    // MARK: Land

    /// Land: the plaza and every Place, each with a one-tile border (where roads run), and any
    /// gaps enclosed by land filled in. The starting square comes first.
    func tiles(features: Set<Island.Feature>) -> [Island.Tile] {
        var shown = [Self.start] + regions
        if features.contains(.library) { shown.append((libraryPlace.x, libraryPlace.y, Self.library.size)) }
        var seen: Set<Island.Tile> = []
        var out: [Island.Tile] = []
        for ty in Self.start.y..<(Self.start.y + Self.start.size) {
            for tx in Self.start.x..<(Self.start.x + Self.start.size) {
                let t = Island.Tile(x: tx, y: ty)
                if seen.insert(t).inserted { out.append(t) }
            }
        }
        for r in shown {
            for ty in (r.y - 1)...(r.y + r.size) {
                for tx in (r.x - 1)...(r.x + r.size) {
                    let t = Island.Tile(x: tx, y: ty)
                    if !water.contains(t), seen.insert(t).inserted { out.append(t) }
                }
            }
        }
        // Bridge any gap between neighbouring Places (they're at most three tiles apart).
        for t in Array(out) {
            for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
                let a = Island.Tile(x: t.x + dx, y: t.y + dy), b = Island.Tile(x: t.x + 2 * dx, y: t.y + 2 * dy)
                if !seen.contains(a), seen.contains(b), !water.contains(a) { seen.insert(a); out.append(a) }
            }
        }
        // Fill any gaps enclosed by land (but not the bays), so there are no holes.
        let xs = out.map(\.x), ys = out.map(\.y)
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { return out }
        var outside: Set<Island.Tile> = []
        var queue = [Island.Tile(x: x0 - 1, y: y0 - 1)]
        while let t = queue.popLast() {
            guard t.x >= x0 - 1, t.x <= x1 + 1, t.y >= y0 - 1, t.y <= y1 + 1,
                  !seen.contains(t), outside.insert(t).inserted else { continue }
            queue += [Island.Tile(x: t.x + 1, y: t.y), Island.Tile(x: t.x - 1, y: t.y),
                      Island.Tile(x: t.x, y: t.y + 1), Island.Tile(x: t.x, y: t.y - 1)]
        }
        for ty in y0...y1 {
            for tx in x0...x1 {
                let t = Island.Tile(x: tx, y: ty)
                if !seen.contains(t), !outside.contains(t), !water.contains(t) { out.append(t) }
            }
        }
        return out
    }
}

/// Soft dirt roads: each Place joins the nearest Place laid out before it (or the plaza), along
/// the land between Places. Worked out afresh every time, so roads follow Places you move.
enum IslandRoads {
    static func route(plots: [Island.Plot], library: Island.Plot?, land: Set<Island.Tile>,
                      blocked: Set<Island.Tile>) -> [[Island.Tile]] {
        let plaza = Island.Plot(bookID: "plaza", x: IslandPlacer.start.x, y: IslandPlacer.start.y, size: IslandPlacer.start.size)
        var joined: [Island.Plot] = [plaza]
        var roads: [[Island.Tile]] = []
        var open = blocked
        // The plaza itself is walkable.
        for p in [plaza] + (library.map { [$0] } ?? []) {
            for ty in p.y..<(p.y + p.size) { for tx in p.x..<(p.x + p.size) { open.remove(Island.Tile(x: tx, y: ty)) } }
        }
        if let library, let path = path(from: library, to: plaza, land: land, blocked: open) { roads.append(path) }
        for plot in plots {
            let target = joined.min { dist($0, plot) < dist($1, plot) }!
            if let path = path(from: plot, to: target, land: land, blocked: open) { roads.append(path) }
            joined.append(plot)
        }
        return roads
    }

    private static func dist(_ a: Island.Plot, _ b: Island.Plot) -> CGFloat {
        hypot(a.centre.x - b.centre.x, a.centre.y - b.centre.y)
    }

    /// The border tile of `plot` nearest to `toward` (its "gate").
    static func gate(of plot: Island.Plot, toward p: CGPoint, land: Set<Island.Tile>) -> Island.Tile? {
        var ring: [Island.Tile] = []
        for ty in (plot.y - 1)...(plot.y + plot.size) {
            for tx in (plot.x - 1)...(plot.x + plot.size) {
                let inside = tx >= plot.x && tx < plot.x + plot.size && ty >= plot.y && ty < plot.y + plot.size
                let t = Island.Tile(x: tx, y: ty)
                // Not the corners, so roads leave from the middle of a side.
                let corner = (tx == plot.x - 1 || tx == plot.x + plot.size) && (ty == plot.y - 1 || ty == plot.y + plot.size)
                if !inside, !corner, land.contains(t) { ring.append(t) }
            }
        }
        return ring.min { a, b in
            (hypot(CGFloat(a.x) + 0.5 - p.x, CGFloat(a.y) + 0.5 - p.y), a.y, a.x) <
                (hypot(CGFloat(b.x) + 0.5 - p.x, CGFloat(b.y) + 0.5 - p.y), b.y, b.x)
        }
    }

    /// The tile just inside a plot, next to one of its border tiles.
    private static func inward(_ t: Island.Tile, _ plot: Island.Plot) -> Island.Tile {
        Island.Tile(x: min(max(t.x, plot.x), plot.x + plot.size - 1), y: min(max(t.y, plot.y), plot.y + plot.size - 1))
    }

    /// Shortest walk over land (4-way, A*), avoiding the inside of Places.
    static func path(from a: Island.Plot, to b: Island.Plot, land: Set<Island.Tile>, blocked: Set<Island.Tile>) -> [Island.Tile]? {
        guard let start = gate(of: a, toward: b.centre, land: land), let goal = gate(of: b, toward: a.centre, land: land) else { return nil }
        func h(_ t: Island.Tile) -> Int { abs(t.x - goal.x) + abs(t.y - goal.y) }
        var open: [(f: Int, g: Int, t: Island.Tile)] = [(h(start), 0, start)]
        var came: [Island.Tile: Island.Tile] = [:]
        var best: [Island.Tile: Int] = [start: 0]
        var steps = 0
        while !open.isEmpty, steps < 6000 {
            steps += 1
            let i = open.indices.min { (open[$0].f, open[$0].t.y, open[$0].t.x) < (open[$1].f, open[$1].t.y, open[$1].t.x) }!
            let cur = open.remove(at: i)
            if cur.t == goal {
                var out = [goal]
                var t = goal
                while let prev = came[t] { out.append(prev); t = prev }
                // Run the road a tile into each Place, so it reads as arriving there.
                return [inward(start, a)] + Array(out.reversed()) + [inward(goal, b)]
            }
            for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
                let n = Island.Tile(x: cur.t.x + dx, y: cur.t.y + dy)
                guard land.contains(n), !blocked.contains(n) || n == goal else { continue }
                let g = cur.g + 1
                if g < best[n] ?? .max {
                    best[n] = g
                    came[n] = cur.t
                    open.append((g + h(n), g, n))
                }
            }
        }
        return nil
    }
}
