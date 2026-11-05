import CoreGraphics
import Foundation

// Villagers: once a Place is complete, a few simple chibi villagers move in, each walking a
// short looping routine tied to the Place's story (a fisherman rows out and brings the catch
// home; someone harvests wheat and carries it to the mill). Routines are waypoint loops with
// idle pauses, written in Place-local coordinates (fractions of the footprint, with its bay
// on the +x side; turned to match the real Place). Positions are a pure function of time, so
// nothing needs updating: what's off screen simply isn't drawn.

nonisolated enum VillagerPose: Sendable { case walk, boat, work, idle }

nonisolated struct Waypoint: Sendable, Equatable {
    /// Place-local position (0…1 across the footprint; beyond 1 on +x is out on the bay).
    let x: Double
    let y: Double
    /// Seconds spent here before moving on.
    let pause: Double
    /// How they look while getting here and pausing.
    let pose: VillagerPose
    /// Carrying something home?
    let carry: Bool

    init(_ x: Double, _ y: Double, pause: Double = 0, _ pose: VillagerPose = .walk, carry: Bool = false) {
        self.x = x; self.y = y; self.pause = pause; self.pose = pose; self.carry = carry
    }
}

nonisolated struct Routine: Sendable, Equatable {
    let name: String
    let waypoints: [Waypoint]
    /// Walking speed in tiles a second.
    var speed: Double = 0.45
}

/// One villager on the island.
struct Villager: Identifiable, Equatable {
    let id: String
    let routine: Routine
    /// The Place's footprint and how its local frame is turned.
    let origin: CGPoint
    let size: CGFloat
    let quarter: Int
    /// Seconds into the loop at time zero, so neighbours don't move in step.
    let phase: Double
    let robe: Int
    let produce: ProduceKind

    struct Pose { let point: CGPoint; let pose: VillagerPose; let carrying: Bool; let facingLeft: Bool }

    /// Place-local to grid.
    func grid(_ w: Waypoint) -> CGPoint {
        var dx = CGFloat(w.x) - 0.5, dy = CGFloat(w.y) - 0.5
        for _ in 0..<quarter { (dx, dy) = (-dy, dx) }
        return CGPoint(x: origin.x + (0.5 + dx) * size, y: origin.y + (0.5 + dy) * size)
    }

    /// The loop's segments: walk from one waypoint to the next, then pause.
    private var legs: [(from: CGPoint, to: CGPoint, walk: Double, pause: Double, arrive: Waypoint)] {
        let pts = routine.waypoints
        return pts.indices.map { i in
            let a = grid(pts[i]), b = grid(pts[(i + 1) % pts.count])
            let next = pts[(i + 1) % pts.count]
            let speed = next.pose == .boat ? routine.speed * 0.7 : routine.speed
            return (a, b, max(0.4, Double(hypot(b.x - a.x, b.y - a.y)) / speed), next.pause, next)
        }
    }

    var period: Double { legs.reduce(0) { $0 + $1.walk + $1.pause } }

    /// Everywhere the routine goes, as a grid rect (for culling before any pose maths).
    var bounds: CGRect {
        let pts = routine.waypoints.map(grid)
        let xs = pts.map(\.x), ys = pts.map(\.y)
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { return .zero }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0).insetBy(dx: -0.3, dy: -0.3)
    }

    func pose(at time: TimeInterval) -> Pose {
        let legs = legs
        guard legs.count > 1 else {
            return Pose(point: grid(routine.waypoints.first ?? Waypoint(0.5, 0.5)), pose: .idle, carrying: false, facingLeft: false)
        }
        var t = (time + phase).truncatingRemainder(dividingBy: period)
        if t < 0 { t += period }
        for leg in legs {
            if t < leg.walk {
                let k = CGFloat(t / leg.walk)
                let e = k * k * (3 - 2 * k)
                let p = CGPoint(x: leg.from.x + (leg.to.x - leg.from.x) * e, y: leg.from.y + (leg.to.y - leg.from.y) * e)
                return Pose(point: p, pose: leg.arrive.pose == .boat ? .boat : .walk, carrying: leg.arrive.carry,
                            facingLeft: (leg.to.x - leg.to.y) < (leg.from.x - leg.from.y))
            }
            t -= leg.walk
            if t < leg.pause {
                return Pose(point: leg.to, pose: leg.arrive.pose == .walk ? .idle : leg.arrive.pose, carrying: leg.arrive.carry, facingLeft: false)
            }
            t -= leg.pause
        }
        return Pose(point: legs[0].from, pose: .idle, carrying: false, facingLeft: false)
    }
}

enum VillagerData {
    /// Caps, so the island stays calm and smooth.
    static let perPlace = 4
    static let maxVisible = 40
    static let maxTravellers = 6

    // MARK: Routines

    static let fisherman = Routine(name: "Rows out, casts a net and carries the catch home", waypoints: [
        Waypoint(0.5, 0.5, pause: 1.5, .idle),
        Waypoint(1.04, 0.5), // the end of the jetty
        Waypoint(1.45, 0.45, pause: 0.5, .boat),
        Waypoint(1.75, 0.75, pause: 3, .boat),
        Waypoint(1.45, 0.5, .boat),
        Waypoint(1.04, 0.5, carry: true),
        Waypoint(0.3, 0.72, pause: 2.5, .idle, carry: true),
    ])
    static let family = Routine(name: "Waits by the house", waypoints: [
        Waypoint(0.28, 0.78, pause: 4, .idle), Waypoint(0.36, 0.7, pause: 2, .idle), Waypoint(0.22, 0.68, pause: 3, .idle),
    ], speed: 0.3)
    static let child = Routine(name: "Plays by the water", waypoints: [
        Waypoint(0.88, 0.25, pause: 0.6), Waypoint(0.9, 0.62, pause: 0.4), Waypoint(0.78, 0.4, pause: 0.8),
    ], speed: 0.8)
    static let trader = Routine(name: "Keeps a market stall", waypoints: [
        Waypoint(0.72, 0.22, pause: 5, .work), Waypoint(0.8, 0.3, pause: 3, .idle),
    ], speed: 0.3)
    static let harvester = Routine(name: "Harvests wheat and carries it to the mill", waypoints: [
        Waypoint(0.22, 0.8, pause: 3, .work), Waypoint(0.3, 0.7, pause: 2, .work),
        Waypoint(0.8, 0.5, pause: 2, .work, carry: true), Waypoint(0.76, 0.76, pause: 1.5, .idle),
    ])
    static let baker = Routine(name: "Brings bread from the oven", waypoints: [
        Waypoint(0.8, 0.55, pause: 3, .work), Waypoint(0.5, 0.58, pause: 2, .idle, carry: true), Waypoint(0.55, 0.42, pause: 2, .idle),
    ], speed: 0.35)
    static let gardener = Routine(name: "Tends the plants", waypoints: [
        Waypoint(0.4, 0.45, pause: 3, .work), Waypoint(0.25, 0.3, pause: 3, .work), Waypoint(0.7, 0.3, pause: 3, .work),
        Waypoint(0.62, 0.65, pause: 2, .idle),
    ], speed: 0.3)
    static let shepherd = Routine(name: "Walks with the flock", waypoints: [
        Waypoint(0.3, 0.75, pause: 2, .idle), Waypoint(0.75, 0.8, pause: 2, .idle), Waypoint(0.8, 0.35, pause: 2, .idle),
    ], speed: 0.3)
    static let townsfolk = Routine(name: "Strolls through town", waypoints: [
        Waypoint(0.5, 0.62, pause: 2, .idle), Waypoint(0.2, 0.5, pause: 1), Waypoint(0.4, 0.25, pause: 2, .idle),
        Waypoint(0.78, 0.3, pause: 1), Waypoint(0.78, 0.7, pause: 2, .idle),
    ], speed: 0.4)
    static let sailor = Routine(name: "Brings a ship into the harbour", waypoints: [
        Waypoint(2.6, 0.2, pause: 1, .boat), Waypoint(1.35, 0.5, pause: 4, .boat), Waypoint(2.6, 0.8, pause: 6, .boat),
    ], speed: 0.4)
    /// The crowd that gathers in the plaza (local to the 2 × 2 starting square).
    static let crowd = Routine(name: "Gathers in the plaza", waypoints: [
        Waypoint(0.3, 0.4, pause: 3, .idle), Waypoint(0.6, 0.3, pause: 4, .idle), Waypoint(0.7, 0.7, pause: 3, .idle),
    ], speed: 0.25)

    /// Who lives in a complete Place of each style, in the order they move in.
    static func routines(for style: PlaceStyle) -> [Routine] {
        switch style {
        case .fishingVillage, .coastTown: [fisherman, family, child, trader]
        case .harbour: [sailor, fisherman, family, trader]
        case .farmstead: [harvester, baker, family, child]
        case .garden, .musicGarden, .vineyard, .oasis, .newJerusalem: [gardener, townsfolk, gardener, child]
        case .camp, .shepherds, .mountain: [shepherd, family, shepherd, child]
        default: [townsfolk, trader, family, child]
        }
    }

    /// Villagers for every complete Place (1 + richness, up to 4 each), and the plaza crowd.
    static func villagers(island: Island) -> [Villager] {
        var out: [Villager] = []
        for plot in island.plots {
            guard let index = island.placeIndex(plot.bookID) else { continue }
            let item = island.items[index]
            guard item.total > 0, item.progress >= item.total else { continue }
            let spec = PlaceData.spec(for: plot.bookID)
            let quarter = plot.bay.map { [1, 0, 3, 2][$0] } ?? ((plot.rotation % 4) + 4) % 4
            let count = min(perPlace, 1 + max(1, item.level))
            for (i, routine) in routines(for: spec.style).prefix(count).enumerated() {
                out.append(Villager(id: "\(plot.bookID)-\(i)", routine: routine, origin: CGPoint(x: plot.x, y: plot.y),
                                    size: CGFloat(plot.size), quarter: quarter, phase: Double(Island.hash("\(plot.bookID)\(i)") % 97),
                                    robe: Island.hash(plot.bookID) + i, produce: spec.produce))
            }
        }
        // A small crowd gathers in the plaza once any Place is complete.
        if !out.isEmpty {
            let crowdSize = min(6, 2 + out.count / 6)
            for i in 0..<crowdSize {
                out.append(Villager(id: "crowd-\(i)", routine: crowd, origin: CGPoint(x: IslandPlacer.start.x, y: IslandPlacer.start.y),
                                    size: CGFloat(IslandPlacer.start.size), quarter: i % 4, phase: Double(i) * 3.7, robe: i * 3,
                                    produce: .bread))
            }
        }
        return out
    }
}

/// Someone walking a road between villages, or a cart rolling along it.
struct Traveller: Equatable {
    let road: [Island.Tile]
    let cart: Bool
    let phase: Double
    let robe: Int
    /// What they carry (readers walking to the Library carry a book, drawn in the bread colour).
    var carrying: ProduceKind = .wool

    /// Everywhere the road goes, as a grid rect.
    var bounds: CGRect {
        let xs = road.map(\.x), ys = road.map(\.y)
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { return .zero }
        return CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1)
    }

    /// Out and back along the road at a stroll, with a rest at each end.
    func position(at time: TimeInterval) -> (point: CGPoint, facingLeft: Bool) {
        guard road.count > 1 else { return (CGPoint(x: CGFloat(road.first?.x ?? 0) + 0.5, y: CGFloat(road.first?.y ?? 0) + 0.5), false) }
        let speed = cart ? 0.3 : 0.4
        let legs = Double(road.count - 1) / speed
        let rest = 4.0
        let period = 2 * (legs + rest)
        var t = (time + phase).truncatingRemainder(dividingBy: period)
        var back = false
        if t > legs + rest { t -= legs + rest; back = true }
        let s = min(Double(road.count - 1), max(0, t * speed))
        let d = back ? Double(road.count - 1) - s : s
        let i = min(road.count - 2, Int(d)), f = CGFloat(d - Double(i))
        let a = road[i], b = road[i + 1]
        let p = CGPoint(x: CGFloat(a.x) + 0.5 + CGFloat(b.x - a.x) * f, y: CGFloat(a.y) + 0.5 + CGFloat(b.y - a.y) * f)
        let dir = back ? -1 : 1
        return (p, CGFloat((b.x - a.x) - (b.y - a.y)) * CGFloat(dir) < 0)
    }

    /// The longest roads get travellers (at most `VillagerData.maxTravellers`). Once the Library
    /// has two storeys, readers also walk the roads to it from the furthest Places.
    static func make(island: Island) -> [Traveller] {
        var out = island.roads.filter { $0.count >= 4 }.sorted { ($0.count, $0.first?.x ?? 0) > ($1.count, $1.first?.x ?? 0) }
            .prefix(VillagerData.maxTravellers).enumerated()
            .map { Traveller(road: $1, cart: $0 % 3 == 1, phase: Double($0) * 11.3, robe: $0 * 5 + 2) }
        if island.library != nil, island.libraryGrowth.stage >= .upperFloor {
            let readers = island.libraryGrowth.stage == .upperFloor ? 2 : 4
            let routes = island.plots.map { island.routeToLibrary(from: $0.bookID) }.filter { $0.count >= 6 }
                .sorted { ($0.count, $0.first?.x ?? 0, $0.first?.y ?? 0) > ($1.count, $1.first?.x ?? 0, $1.first?.y ?? 0) }
            for (i, route) in routes.prefix(readers).enumerated() {
                out.append(Traveller(road: route, cart: false, phase: Double(i) * 17.9, robe: i * 3 + 1, carrying: .bread))
            }
        }
        return out
    }
}
