import SwiftUI

// Level of detail: how much life the island shows depends on how close you are.
// - Far (the whole island): no villagers or walkers; only a couple of boats, birds, waves and smoke.
// - Middle: a few villagers and travellers, only near the middle of the screen (about 15).
// - Close: everyone whose Place is on screen (about 30).
// Tiers switch at slightly different zooms going in and out (hysteresis), so they never flicker at
// a boundary, and figures fade in and out over 0.3 s rather than popping. Each figure keeps its own
// clock that only runs while it's on screen: off screen it is paused (nothing is worked out for
// it), and it carries on from where it left off when it comes back.

nonisolated enum LODTier: Int, Comparable, Sendable {
    case far, middle, close
    static func < (a: LODTier, b: LODTier) -> Bool { a.rawValue < b.rawValue }
}

nonisolated enum IslandLOD {
    /// Size unit `u` (points per art unit) where the tiers change: shown when zooming in past
    /// the first number, hidden again only when zooming out past the second.
    static let middleShow: CGFloat = 0.62, middleHide: CGFloat = 0.55
    static let closeShow: CGFloat = 1.3, closeHide: CGFloat = 1.15
    /// At most this many figures (villagers, travellers and Bible characters together).
    static let middleCap = 15
    static let closeCap = 30
    /// Boats still shown far out.
    static let farBoats = 2
    /// Seconds for a figure to fade in or out.
    static let fade: Double = 0.3
    /// In the middle tier, figures show only this close to the centre (a fraction of the screen's
    /// smaller side).
    static let middleRadius: CGFloat = 0.42

    /// The tier for a zoom, given the tier before (nil: the first look).
    static func tier(u: CGFloat, previous: LODTier?) -> LODTier {
        switch previous {
        case nil, .far?: u >= closeShow ? .close : u >= middleShow ? .middle : .far
        case .middle?: u >= closeShow ? .close : u < middleHide ? .far : .middle
        case .close?: u < middleHide ? .far : u < closeHide ? .middle : .close
        }
    }

    struct Candidate: Equatable {
        let id: String
        /// Where it stands, in view points.
        let point: CGPoint
    }

    /// Which figures to show: none far out; near the centre in the middle tier; everyone on screen
    /// close in, nearest the centre first, up to the tier's cap. Figures already showing are kept a
    /// little longer (a 24pt head start), so two at the edge of the cap don't swap back and forth.
    static func select(_ candidates: [Candidate], tier: LODTier, viewport: CGRect, showing: Set<String> = []) -> [String] {
        guard tier != .far else { return [] }
        let centre = CGPoint(x: viewport.midX, y: viewport.midY)
        let radius = min(viewport.width, viewport.height) * middleRadius
        let cap = tier == .middle ? middleCap : closeCap
        return candidates
            .filter { viewport.contains($0.point) }
            .map { c in (c.id, hypot(c.point.x - centre.x, c.point.y - centre.y)) }
            .filter { tier == .close || $0.1 <= radius }
            .sorted { a, b in
                let da = a.1 - (showing.contains(a.0) ? 24 : 0), db = b.1 - (showing.contains(b.0) ? 24 : 0)
                return (da, a.0) < (db, b.0)
            }
            .prefix(cap)
            .map(\.0)
    }
}

/// Runs the island's life frame by frame: the tier, each figure's own clock (paused off screen) and
/// each figure's fade. One per island view; it changes only while drawing, so it isn't observed.
@MainActor
final class LifeDirector {
    private(set) var tier: LODTier?
    /// Each figure's own time, and the frame it was last awake (on screen).
    private var clocks: [String: (time: Double, frame: Int, wall: Double)] = [:]
    private var opacities: [String: Double] = [:]
    private var showing: Set<String> = []
    private var frame = 0
    private var lastWall: Double?

    /// A figure to consider this frame: its id, where it lives (view points), and how to find
    /// where it is at its own time (only asked while it's awake).
    struct Figure {
        let id: String
        let home: CGRect
        let position: (Double) -> CGPoint
        var frozen = false
    }

    struct Shown {
        let id: String
        let time: Double
        let point: CGPoint
        let opacity: Double
    }

    /// Starts a frame: updates the tier for this zoom.
    @discardableResult
    func begin(now: Double, u: CGFloat) -> LODTier {
        frame += 1
        let t = IslandLOD.tier(u: u, previous: tier)
        tier = t
        lastWallStep = lastWall.map { min(0.25, max(0, now - $0)) } ?? 0
        lastWall = now
        return t
    }

    private var lastWallStep: Double = 0

    /// A figure's own time, advanced by the time since the frame before if it was awake then;
    /// otherwise it resumes from where it stopped. `frozen` keeps it still (e.g. while talking).
    func time(_ id: String, now: Double, frozen: Bool = false) -> Double {
        guard var clock = clocks[id] else {
            clocks[id] = (now, frame, now)
            return now
        }
        if clock.frame == frame { return clock.time }
        if clock.frame == frame - 1, !frozen { clock.time += min(0.25, max(0, now - clock.wall)) }
        clock.frame = frame
        clock.wall = now
        clocks[id] = clock
        return clock.time
    }

    /// A figure's time without advancing it (for taps and speech bubbles).
    func peek(_ id: String) -> Double? { clocks[id]?.time }

    /// Works out which figures show this frame, and how strongly (fading over `IslandLOD.fade`).
    /// Figures whose home is off screen aren't looked at at all: their clocks stay paused.
    func plan(_ figures: @autoclosure () -> [Figure], now: Double, viewport: CGRect) -> [Shown] {
        let tier = tier ?? .far
        // Far out nobody shows: once the last has faded, nothing is worked out at all.
        if tier == .far && opacities.isEmpty {
            showing = []
            return []
        }
        let figures = figures()
        var candidates: [IslandLOD.Candidate] = []
        var awake: [String: (time: Double, point: CGPoint)] = [:]
        for f in figures where f.home.intersects(viewport) {
            let t = time(f.id, now: now, frozen: f.frozen)
            let p = f.position(t)
            awake[f.id] = (t, p)
            candidates.append(.init(id: f.id, point: p))
        }
        let selected = Set(IslandLOD.select(candidates, tier: tier, viewport: viewport, showing: showing))
        showing = selected
        let step = lastWallStep / IslandLOD.fade
        var out: [Shown] = []
        for (id, a) in awake {
            let target: Double = selected.contains(id) ? 1 : 0
            let now = opacities[id] ?? 0
            let next = target > now ? min(target, now + step) : max(target, now - step)
            if next <= 0 { opacities[id] = nil; continue }
            opacities[id] = next
            out.append(Shown(id: id, time: a.time, point: a.point, opacity: next))
        }
        // Anything that went off screen while showing starts from nothing when it comes back.
        for id in opacities.keys where awake[id] == nil { opacities[id] = nil }
        return out.sorted { $0.point.y < $1.point.y }
    }

    /// For tests: how strongly a figure shows now.
    func opacity(_ id: String) -> Double { opacities[id] ?? 0 }
}

/// DEBUG readout: how many things were drawn in the last frame (images, items and figures). The
/// island is drawn with `Canvas`, so this is the closest thing to a node count.
@MainActor
enum RenderStats {
    static var staticLayer = 0
    static var life = 0
    static var figures = 0
    /// Everything the island holds (items and figures): its "node count".
    static var nodes = 0
    static var total: Int { staticLayer + life + figures }
}
