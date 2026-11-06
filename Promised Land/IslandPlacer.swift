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
    /// The hut's spot (the Library's anchor) and its footprint now (it grows from the hut).
    private(set) var libraryHut: (x: Int, y: Int)
    private(set) var libraryRect: (x: Int, y: Int, size: Int)
    private var reservedBays: [String: Int] = [:]
    /// Saved spots that aren't kept (auto-placed ones the Library grew over): laid out again,
    /// as near their old spot as they fit.
    private var nudged: [String: (x: Int, y: Int)] = [:]

    /// - Parameters:
    ///   - placements: saved places, reserved before anything is laid out automatically.
    ///   - keys: the books (and feature keys) being laid out, to reserve their saved places.
    ///   - library: how big the Library has grown.
    ///   - libraryAvoid: the places the Library grows around (only ones you moved yourself count).
    ///     Defaults to `placements`; edit mode passes the saved places, so dropping something on
    ///     the Library is a conflict rather than a reason for it to shrink.
    init(placements: [String: IslandPlacement] = [:], keys: [String] = [], library: LibraryStage = .hut,
         libraryAvoid: [String: IslandPlacement]? = nil) {
        self.placements = placements
        let lib = placements[IslandPlacement.libraryKey]
        let hut = lib.map { ($0.x, $0.y) } ?? (Self.library.x, Self.library.y)
        libraryHut = hut
        // What the Library must grow around: the plaza, and everything you moved yourself
        // (with its bay), except anything sitting on the hut itself (that's a conflict instead).
        var avoid: [(x: Int, y: Int, size: Int)] = [(Self.start.x, Self.start.y, Self.start.size)]
        let hutRect = (x: hut.0, y: hut.1, size: Self.library.size)
        for (key, p) in libraryAvoid ?? placements where key != IslandPlacement.libraryKey && p.moved {
            guard let size = Self.size(of: key) else { continue }
            let square = (x: p.x, y: p.y, size: size)
            guard !Self.overlaps(square, hutRect, gap: 1) else { continue }
            avoid.append(square)
            if BibleCatalog.book(id: key) != nil, PlaceData.spec(for: key).isWaterside {
                for t in Self.bay(x: p.x, y: p.y, size: size, side: Self.outwardSide(x: p.x, y: p.y, size: size)) {
                    avoid.append((t.x, t.y, 1))
                }
            }
        }
        libraryRect = library == .hut ? (hut.0, hut.1, Self.library.size)
            : LibraryFootprint.place(hutX: hut.0, hutY: hut.1, stage: library, avoid: avoid)
        mark(Self.start.x, Self.start.y, Self.start.size)
        var reserved: [(key: String, x: Int, y: Int, size: Int, bay: [Island.Tile], side: Int?)] = [
            (IslandPlacement.libraryKey, libraryRect.x, libraryRect.y, libraryRect.size, [], nil)
        ]
        for key in keys {
            guard let p = placements[key], let size = Self.size(of: key) else { continue }
            let waterside = BibleCatalog.book(id: key) != nil && PlaceData.spec(for: key).isWaterside
            let side = waterside ? Self.outwardSide(x: p.x, y: p.y, size: size) : nil
            let bay = side.map { Self.bay(x: p.x, y: p.y, size: size, side: $0) } ?? []
            // An auto-placed spot the Library has grown over is nudged out of the way.
            if !p.moved, Self.overlaps((p.x, p.y, size), libraryRect, gap: 1)
                || bay.contains(where: { Self.overlaps(($0.x, $0.y, 1), libraryRect, gap: 1) }) {
                nudged[key] = (p.x, p.y)
                continue
            }
            reserved.append((key, p.x, p.y, size, bay, side))
        }
        // Saved spots may sit right beside each other (you can build snugly); only overlapping
        // another, or a bay landing on one, is a conflict, and both of the pair are flagged, so
        // whichever you dropped springs back.
        func tiles(_ r: (key: String, x: Int, y: Int, size: Int, bay: [Island.Tile], side: Int?)) -> Set<Island.Tile> {
            Set((r.y..<(r.y + r.size)).flatMap { ty in (r.x..<(r.x + r.size)).map { Island.Tile(x: $0, y: ty) } })
        }
        let start = Set((Self.start.y..<(Self.start.y + Self.start.size)).flatMap { ty in
            (Self.start.x..<(Self.start.x + Self.start.size)).map { Island.Tile(x: $0, y: ty) }
        })
        let footprints = reserved.map(tiles)
        for (i, a) in reserved.enumerated() {
            if !footprints[i].isDisjoint(with: start) || a.bay.contains(where: start.contains) { conflicts.insert(a.key) }
            for j in reserved.indices where j > i {
                let b = reserved[j]
                if !footprints[i].isDisjoint(with: footprints[j]) || a.bay.contains(where: footprints[j].contains)
                    || b.bay.contains(where: footprints[i].contains) {
                    conflicts.insert(a.key)
                    conflicts.insert(b.key)
                }
            }
        }
        for r in reserved {
            mark(r.x, r.y, r.size)
            for t in r.bay { core.insert(t); water.insert(t) }
            if let side = r.side { reservedBays[r.key] = side }
        }
    }

    /// True if two squares are closer than `gap` tiles.
    static func overlaps(_ a: (x: Int, y: Int, size: Int), _ b: (x: Int, y: Int, size: Int), gap: Int) -> Bool {
        a.x - gap < b.x + b.size && b.x < a.x + a.size + gap && a.y - gap < b.y + b.size && b.y < a.y + a.size + gap
    }

    static func size(of key: String) -> Int? {
        if key == IslandPlacement.forestKey { return forestSize }
        return BibleCatalog.book(id: key).map { _ in PlaceData.spec(for: key).size }
    }

    /// The Library's footprint now.
    var libraryPlot: Island.Plot {
        Island.Plot(bookID: IslandPlacement.libraryKey, x: libraryRect.x, y: libraryRect.y, size: libraryRect.size,
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

    /// Offsets around a spot, nearest first (for nudging a Place out of the Library's way).
    private static let nearby: [(dx: Int, dy: Int)] = {
        var all: [(dx: Int, dy: Int)] = []
        for dy in -16...16 { for dx in -16...16 { all.append((dx, dy)) } }
        return all.sorted { (hypot(Double($0.dx), Double($0.dy)), $0.dy, $0.dx) < (hypot(Double($1.dx), Double($1.dy)), $1.dy, $1.dx) }
    }()

    /// Places a Place (or the forest), or returns its saved spot.
    /// - Parameter preferred: where it stood before the Library grew (kept if it still fits,
    ///   otherwise the nearest free spot, a little further out).
    mutating func place(_ key: String, size: Int, waterside: Bool, testament: Testament,
                        preferred: (x: Int, y: Int)? = nil) -> Island.Plot {
        if let p = placements[key], nudged[key] == nil {
            regions.append((p.x, p.y, size))
            blockInside(p.x, p.y, size)
            let rotation = p.rotation
            return Island.Plot(bookID: key, x: p.x, y: p.y, size: size, rotation: rotation, bay: reservedBays[key])
        }
        let rotation = placements[key]?.rotation ?? 0
        if let start = nudged[key] ?? preferred {
            // Away from the Library's middle counts as a little nearer, so things move outward.
            let lc = (x: Double(libraryRect.x) + Double(libraryRect.size) / 2, y: Double(libraryRect.y) + Double(libraryRect.size) / 2)
            let from = hypot(Double(start.x) + Double(size) / 2 - lc.x, Double(start.y) + Double(size) / 2 - lc.y)
            var best: (cost: Double, plot: Island.Plot, bay: [Island.Tile])?
            for o in Self.nearby {
                let d = hypot(Double(o.dx), Double(o.dy))
                if let best, d - 1 > best.cost { break }
                let x = start.x + o.dx, y = start.y + o.dy
                guard fits(x, y, size, gap: 1), touchesLand(x, y, size, landOnly: true) else { continue }
                var bay: [Island.Tile] = []
                var side: Int?
                if waterside {
                    let s = Self.outwardSide(x: x, y: y, size: size)
                    bay = Self.bay(x: x, y: y, size: size, side: s)
                    guard bay.allSatisfy({ !core.contains($0) && !near($0, distance: 1) }) else { continue }
                    side = s
                }
                let to = hypot(Double(x) + Double(size) / 2 - lc.x, Double(y) + Double(size) / 2 - lc.y)
                let cost = d - (to > from ? 0.5 : 0)
                if best == nil || cost < best!.cost {
                    best = (cost, Island.Plot(bookID: key, x: x, y: y, size: size, rotation: rotation, bay: side), bay)
                }
            }
            if let best {
                let p = best.plot
                mark(p.x, p.y, size)
                for t in best.bay { core.insert(t); water.insert(t) }
                regions.append((p.x, p.y, size))
                blockInside(p.x, p.y, size)
                return p
            }
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

    /// Joins every separate piece of land to the piece with the starting square, by the shortest
    /// strip (three tiles wide) over tiles that aren't water.
    private static func joinPieces(_ out: inout [Island.Tile], _ seen: inout Set<Island.Tile>, water: Set<Island.Tile>) {
        let steps = [(1, 0), (0, 1), (-1, 0), (0, -1)]
        for _ in 0..<20 {
            // The main piece: everything connected to the starting square.
            guard let first = out.first else { return }
            var main: Set<Island.Tile> = [first]
            var stack = [first]
            while let t = stack.popLast() {
                for (dx, dy) in steps {
                    let n = Island.Tile(x: t.x + dx, y: t.y + dy)
                    if seen.contains(n), main.insert(n).inserted { stack.append(n) }
                }
            }
            guard let stray = out.first(where: { !main.contains($0) }) else { return }
            // Shortest walk from the stray piece to the main piece, over anything but water.
            var piece: Set<Island.Tile> = [stray]
            stack = [stray]
            while let t = stack.popLast() {
                for (dx, dy) in steps {
                    let n = Island.Tile(x: t.x + dx, y: t.y + dy)
                    if seen.contains(n), piece.insert(n).inserted { stack.append(n) }
                }
            }
            var came: [Island.Tile: Island.Tile] = [:]
            var visited = piece
            var queue = Array(piece).sorted { ($0.y, $0.x) < ($1.y, $1.x) }
            var head = 0
            var reached: Island.Tile?
            while head < queue.count, reached == nil {
                let t = queue[head]
                head += 1
                for (dx, dy) in steps {
                    let n = Island.Tile(x: t.x + dx, y: t.y + dy)
                    guard !water.contains(n), visited.insert(n).inserted, visited.count < 20_000 else { continue }
                    came[n] = t
                    if main.contains(n) { reached = n; break }
                    queue.append(n)
                }
            }
            guard var t = reached else { return }
            while let prev = came[t], !piece.contains(prev) {
                for (dx, dy) in [(0, 0)] + steps {
                    let w = Island.Tile(x: prev.x + dx, y: prev.y + dy)
                    if !water.contains(w), seen.insert(w).inserted { out.append(w) }
                }
                t = prev
            }
        }
    }

    private func fits(_ x: Int, _ y: Int, _ size: Int, gap: Int) -> Bool {
        for ty in (y - gap)..<(y + size + gap) {
            for tx in (x - gap)..<(x + size + gap) where core.contains(Island.Tile(x: tx, y: ty)) { return false }
        }
        return true
    }

    /// Within two tiles of something already built (so the land joins up).
    /// - Parameter landOnly: count only land (not bays) as something to join.
    private func touchesLand(_ x: Int, _ y: Int, _ size: Int, landOnly: Bool = false) -> Bool {
        guard landOnly else { return !fits(x, y, size, gap: 3) }
        for ty in (y - 3)..<(y + size + 3) {
            for tx in (x - 3)..<(x + size + 3) {
                let t = Island.Tile(x: tx, y: ty)
                if core.contains(t), !water.contains(t) { return true }
            }
        }
        return false
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
        if features.contains(.library) { shown.append((libraryRect.x, libraryRect.y, libraryRect.size)) }
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
        // Close the gaps between neighbouring Places: any straight gap of up to three tiles between
        // two pieces of land, and any notch (a sea tile with land on three sides), is land too, so
        // moving a Place never leaves a channel or an inlet cutting into the island. Bays stay water.
        func add(_ t: Island.Tile) {
            if !water.contains(t), seen.insert(t).inserted { out.append(t) }
        }
        /// Beside a bay: left as sea, so the bay keeps its mouth onto open water.
        func byBay(_ t: Island.Tile) -> Bool {
            [(1, 0), (0, 1), (-1, 0), (0, -1)].contains { water.contains(Island.Tile(x: t.x + $0.0, y: t.y + $0.1)) }
        }
        func closeGaps() {
            for _ in 0..<2 {
                for t in Array(out) {
                    for (dx, dy) in [(1, 0), (0, 1)] {
                        for gap in 1...3 {
                            let far = Island.Tile(x: t.x + (gap + 1) * dx, y: t.y + (gap + 1) * dy)
                            guard seen.contains(far) else { continue }
                            let between = (1...gap).map { Island.Tile(x: t.x + $0 * dx, y: t.y + $0 * dy) }
                            if between.allSatisfy({ !seen.contains($0) && !water.contains($0) && !byBay($0) }) { between.forEach(add) }
                            break
                        }
                    }
                }
            }
            for _ in 0..<3 {
                var notches: [Island.Tile] = []
                for t in out {
                    for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
                        let n = Island.Tile(x: t.x + dx, y: t.y + dy)
                        guard !seen.contains(n), !water.contains(n), !byBay(n) else { continue }
                        let sides = [(1, 0), (0, 1), (-1, 0), (0, -1)].filter { seen.contains(Island.Tile(x: n.x + $0.0, y: n.y + $0.1)) }.count
                        if sides >= 3 { notches.append(n) }
                    }
                }
                if notches.isEmpty { break }
                notches.forEach(add)
            }
        }
        closeGaps()
        // A Place dragged out on its own is joined to the island by a strip of land (then any gaps
        // beside the strip are closed too).
        Self.joinPieces(&out, &seen, water: water)
        closeGaps()
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

/// Soft dirt roads: the Library is the heart of the network. The plaza joins the Library, and each
/// Place's road runs from its nearest side to the nearest point of the roads already there, so
/// all the roads are one connected network and every road leads to the Library. Worked out afresh
/// every time, so roads follow Places you move.
enum IslandRoads {
    /// Where a road joins the road it meets: that road's index, and the tile's index along it.
    struct Join: Equatable {
        let road: Int
        let at: Int
    }

    /// Which road leaves a plot, the plot whose road it meets (or the Library, for the plaza's), and
    /// where it joins (nil for the plaza's road, which ends at the Library).
    struct Link: Equatable {
        let road: Int
        let to: String
        let join: Join?
    }

    /// The link for each plot (by key; "plaza" for the plaza).
    typealias Links = [String: Link]

    static func route(plots: [Island.Plot], library: Island.Plot?, land: Set<Island.Tile>,
                      blocked: Set<Island.Tile>) -> [[Island.Tile]] {
        network(plots: plots, library: library, land: land, blocked: blocked).roads
    }

    static func network(plots: [Island.Plot], library: Island.Plot?, land: Set<Island.Tile>,
                        blocked: Set<Island.Tile>) -> (roads: [[Island.Tile]], links: Links) {
        let plaza = Island.Plot(bookID: "plaza", x: IslandPlacer.start.x, y: IslandPlacer.start.y, size: IslandPlacer.start.size)
        var joined: [Island.Plot] = (library.map { [$0] } ?? []) + [plaza]
        var roads: [[Island.Tile]] = []
        var links: Links = [:]
        var open = blocked
        // The plaza (and the Library's ground) can be walked across.
        for p in [plaza] + (library.map { [$0] } ?? []) {
            for ty in p.y..<(p.y + p.size) { for tx in p.x..<(p.x + p.size) { open.remove(Island.Tile(x: tx, y: ty)) } }
        }
        /// Every road tile, and where it sits (a new road can join the network at any of them).
        var network: [Island.Tile: (key: String, join: Join)] = [:]
        func add(_ road: [Island.Tile], key: String, link: Link) {
            let index = roads.count
            links[key] = Link(road: index, to: link.to, join: link.join)
            for (i, t) in road.enumerated() where network[t] == nil { network[t] = (key, Join(road: index, at: i)) }
            roads.append(road)
        }
        // The heart: the plaza to the Library.
        if let library, let path = path(from: plaza, to: library, land: land, blocked: open) {
            add(path, key: "plaza", link: Link(road: 0, to: library.bookID, join: nil))
        }
        // Without a Library (or a road to it), new roads make for the plaza instead.
        let plazaTiles: Set<Island.Tile> = network.isEmpty
            ? Set((plaza.y..<(plaza.y + plaza.size)).flatMap { ty in (plaza.x..<(plaza.x + plaza.size)).map { Island.Tile(x: $0, y: ty) } })
            : []
        let heart = library?.centre ?? plaza.centre
        for plot in plots {
            if let spur = spur(from: plot, toward: heart, land: land, blocked: open,
                               reaches: { network[$0].map { ($0.key, $0.join) } ?? (plazaTiles.contains($0) ? ("plaza", nil) : nil) }) {
                add(spur.path, key: plot.bookID, link: Link(road: 0, to: spur.to, join: spur.join))
            } else {
                // Cut off from the network (shouldn't happen on one island): a road to the nearest Place.
                let target = joined.min { dist($0, plot) < dist($1, plot) }!
                if let path = path(from: plot, to: target, land: land, blocked: open) {
                    add(path, key: plot.bookID, link: Link(road: 0, to: target.bookID, join: nil))
                }
            }
            joined.append(plot)
        }
        return (roads, links)
    }

    /// The shortest road (over land, around Places) from any side of `plot` to a tile `reaches`
    /// accepts, starting a tile inside the plot. Sides nearer `toward` are tried first on a tie.
    private static func spur(from plot: Island.Plot, toward: CGPoint, land: Set<Island.Tile>, blocked: Set<Island.Tile>,
                             reaches: (Island.Tile) -> (String, Join?)?) -> (path: [Island.Tile], to: String, join: Join?)? {
        let ring = ring(of: plot, land: land).filter { !blocked.contains($0) }.sorted { a, b in
            (hypot(CGFloat(a.x) + 0.5 - toward.x, CGFloat(a.y) + 0.5 - toward.y), a.y, a.x) <
                (hypot(CGFloat(b.x) + 0.5 - toward.x, CGFloat(b.y) + 0.5 - toward.y), b.y, b.x)
        }
        var came: [Island.Tile: Island.Tile] = [:]
        var seen = Set(ring)
        var queue = ring
        var head = 0
        while head < queue.count {
            let t = queue[head]
            head += 1
            if let (to, join) = reaches(t) {
                var out = [t]
                var c = t
                while let prev = came[c] { out.append(prev); c = prev }
                out.reverse()
                return ([inward(out[0], plot)] + out, to, join)
            }
            for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
                let n = Island.Tile(x: t.x + dx, y: t.y + dy)
                guard land.contains(n), !blocked.contains(n), seen.insert(n).inserted else { continue }
                came[n] = t
                queue.append(n)
            }
        }
        return nil
    }

    /// The whole walk from a plot to the Library: along its road to where it joins the next one,
    /// along that one, and so on to the Library. Every step is to a neighbouring tile.
    static func toLibrary(from key: String, roads: [[Island.Tile]], links: Links) -> [Island.Tile] {
        guard var link = links[key], roads.indices.contains(link.road) else { return [] }
        let owner = Dictionary(links.map { ($0.value.road, $0.value) }, uniquingKeysWith: { a, _ in a })
        var out = roads[link.road]
        var steps = 0
        while let join = link.join {
            steps += 1
            guard steps <= roads.count, roads.indices.contains(join.road), let next = owner[join.road] else { return [] }
            let road = roads[join.road]
            if join.at + 1 < road.count { out += road[(join.at + 1)...] }
            link = next
        }
        // Only the plaza's road ends at the Library.
        return link.to == IslandPlacement.libraryKey && links["plaza"] == link ? out : []
    }

    private static func dist(_ a: Island.Plot, _ b: Island.Plot) -> CGFloat {
        hypot(a.centre.x - b.centre.x, a.centre.y - b.centre.y)
    }

    /// The tiles bordering a plot's sides, on land (not its corners, so roads leave from the
    /// middle of a side).
    static func ring(of plot: Island.Plot, land: Set<Island.Tile>) -> [Island.Tile] {
        var ring: [Island.Tile] = []
        for ty in (plot.y - 1)...(plot.y + plot.size) {
            for tx in (plot.x - 1)...(plot.x + plot.size) {
                let inside = tx >= plot.x && tx < plot.x + plot.size && ty >= plot.y && ty < plot.y + plot.size
                let corner = (tx == plot.x - 1 || tx == plot.x + plot.size) && (ty == plot.y - 1 || ty == plot.y + plot.size)
                let t = Island.Tile(x: tx, y: ty)
                if !inside, !corner, land.contains(t) { ring.append(t) }
            }
        }
        return ring
    }

    /// The border tile of `plot` nearest to `toward` (its "gate").
    static func gate(of plot: Island.Plot, toward p: CGPoint, land: Set<Island.Tile>) -> Island.Tile? {
        ring(of: plot, land: land).min { a, b in
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
