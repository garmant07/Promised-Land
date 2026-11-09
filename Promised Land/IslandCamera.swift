import SwiftUI

/// Camera and depth maths for the island, kept pure so they can be tested at every turn.
///
/// Screen points and the *turned* grid are linked by the isometric projection
/// (`X = rx − ry`, `Y = (rx + ry) / 2`), so anything on screen can be put back into turned-grid
/// coordinates without knowing the turn: `rx = Y + X/2`, `ry = Y − X/2`. "In front" on the turned
/// grid means a larger `rx` or `ry`, at any of the four turns.
enum IslandCamera {
    /// The centre of the area the island is drawn in (the screen less the status pill and the bar),
    /// `fraction` of the way down it (0.5 = the middle).
    static func freeCentre(size: CGSize, insets: EdgeInsets, fraction: CGFloat = 0.5) -> CGPoint {
        CGPoint(x: insets.leading + (size.width - insets.leading - insets.trailing) / 2,
                y: insets.top + (size.height - insets.top - insets.bottom) * fraction)
    }

    /// The grid point to centre on for an item: the middle of its Place (a building's whole plot),
    /// otherwise the middle of its own footprint, otherwise where it stands.
    static func focus(of item: Island.Item, in island: Island) -> CGPoint {
        if let key = item.plotKey, let plot = island.allPlots.first(where: { $0.bookID == key }) {
            return plot.centre
        }
        if item.footprint.width > 0, item.footprint.height > 0 {
            return CGPoint(x: item.footprint.midX, y: item.footprint.midY)
        }
        return CGPoint(x: item.gx, y: item.gy)
    }

    /// The pan that puts a grid point at `target` (default: the middle of the free area) at a zoom
    /// and turn. The layout's turn is applied before projecting, so it works at every rotation.
    static func pan(toCentre grid: CGPoint, island: Island, size: CGSize, insets: EdgeInsets, zoom: CGFloat,
                    quarter: Int, target: CGPoint? = nil) -> CGSize {
        let layout = IslandLayout(island: island, size: size, insets: insets, zoom: zoom, angle: CGFloat(quarter))
        let p = layout.point(grid.x, grid.y)
        let t = target ?? freeCentre(size: size, insets: insets)
        return CGSize(width: t.x - p.x, height: t.y - p.y)
    }

    /// How far the camera may pan at a zoom so that any Place (and the Library) can still be
    /// centred, at any turn: the largest pan centring a plot needs, plus a margin.
    static func reach(island: Island, size: CGSize, insets: EdgeInsets, zoom: CGFloat) -> CGSize {
        var hasher = Hasher()
        hasher.combine(island.signature); hasher.combine(island.items.count); hasher.combine(zoom)
        hasher.combine(size.width); hasher.combine(size.height)
        hasher.combine(insets.top); hasher.combine(insets.leading); hasher.combine(insets.bottom); hasher.combine(insets.trailing)
        let key = hasher.finalize()
        if let known = reachMemo[key] { return known }
        // Everything that can be centred on: each Place's middle, and buildings standing on their own.
        let focuses = island.allPlots.map(\.centre) + island.items.filter { $0.plotKey == nil }.map { focus(of: $0, in: island) }
        var w: CGFloat = 0, h: CGFloat = 0
        let centre = freeCentre(size: size, insets: insets)
        for quarter in 0..<4 {
            let layout = IslandLayout(island: island, size: size, insets: insets, zoom: zoom, angle: CGFloat(quarter))
            for f in focuses {
                let p = layout.point(f.x, f.y)
                w = max(w, abs(centre.x - p.x)); h = max(h, abs(centre.y - p.y))
            }
        }
        let reach = CGSize(width: w + 24, height: h + 24)
        if reachMemo.count > 64 { reachMemo.removeAll() }
        reachMemo[key] = reach
        return reach
    }

    /// `reach` per island, zoom and screen (it's asked on every drag event).
    private static var reachMemo: [Int: CGSize] = [:]

    // MARK: Visiting

    /// How much of the free area's width a building's Place fills when you step up to it.
    static let visitFill: CGFloat = 0.75

    /// The zoom at which an item's Place (or its own footprint) fills `visitFill` of the free area's
    /// width. A square plot's diamond is the same width at every turn (2 × tiles × scale), so this
    /// holds at all four rotations. Never past the island's closest zoom.
    static func visitZoom(for item: Island.Item, in island: Island, size: CGSize, insets: EdgeInsets, quarter: Int = 0) -> CGFloat {
        let tiles: CGFloat
        if let key = item.plotKey, let plot = island.allPlots.first(where: { $0.bookID == key }) {
            tiles = CGFloat(plot.size)
        } else {
            tiles = max(1, footprint(of: item).width)
        }
        // The island's fitting scale depends on the turn (it's fitted to the screen as it lies).
        let layout = IslandLayout(island: island, size: size, insets: insets, angle: CGFloat(quarter))
        let area = max(1, size.width - insets.leading - insets.trailing)
        let zoom = visitFill * area / (2 * tiles * layout.fit)
        return min(layout.maxZoom, max(IslandLayout.minZoom, zoom))
    }

    // MARK: Depth

    /// A screen point in turned-grid units (larger = further forward).
    static func turned(_ p: CGPoint, layout: IslandLayout) -> CGPoint {
        let X = (p.x - layout.origin.x) / layout.scale, Y = (p.y - layout.origin.y) / layout.scale
        return CGPoint(x: Y + X / 2, y: Y - X / 2)
    }

    /// The patch of ground an item covers, in grid units (a small square if it has no footprint).
    static func footprint(of item: Island.Item) -> CGRect {
        item.footprint.width > 0 && item.footprint.height > 0
            ? item.footprint
            : CGRect(x: item.gx - 0.5, y: item.gy - 0.5, width: 1, height: 1)
    }

    /// The front-most corner of an item's footprint, in turned-grid units: the largest `rx` and
    /// `ry` its footprint reaches at this turn.
    static func front(of item: Island.Item, layout: IslandLayout) -> CGPoint {
        let f = footprint(of: item)
        var rx = -CGFloat.infinity, ry = -CGFloat.infinity
        for (x, y) in [(f.minX, f.minY), (f.maxX, f.minY), (f.minX, f.maxY), (f.maxX, f.maxY)] {
            let r = turned(layout.point(x, y), layout: layout)
            rx = max(rx, r.x); ry = max(ry, r.y)
        }
        return CGPoint(x: rx, y: ry)
    }

    /// Is someone whose feet are at `feet` (a screen point) standing behind this item? Behind means
    /// not past its footprint's front edge on either turned axis, so the item is drawn over them.
    /// Someone beside it, or in front of either front face, is not behind it.
    static func isBehind(feet: CGPoint, item: Island.Item, layout: IslandLayout) -> Bool {
        let r = turned(feet, layout: layout)
        let f = front(of: item, layout: layout)
        return r.x < f.x && r.y < f.y
    }

    /// The depth to sort an item by against people: the screen y of its footprint's front-most
    /// corner. Anyone `isBehind` it always sorts before it.
    static func frontDepth(of item: Island.Item, layout: IslandLayout) -> CGFloat {
        let f = front(of: item, layout: layout)
        return layout.origin.y + (f.x + f.y) / 2 * layout.scale
    }
}

/// A camera glide (after a flick, to a building, back again): a pure function of time, so however
/// unevenly frames arrive the camera is always exactly where it should be at that moment.
struct CameraGlide: Equatable {
    let fromZoom: CGFloat, toZoom: CGFloat
    let fromPan: CGSize, toPan: CGSize
    let start: Double
    let duration: Double
    var easeOut = false

    /// 0…1 of the way through at `time` (seconds, same clock as `start`).
    func progress(at time: Double) -> Double { duration <= 0 ? 1 : min(1, max(0, (time - start) / duration)) }

    func isDone(at time: Double) -> Bool { progress(at: time) >= 1 }

    /// The camera at `time`.
    func camera(at time: Double) -> (zoom: CGFloat, pan: CGSize) {
        let t = progress(at: time)
        let e = CGFloat(easeOut ? 1 - pow(1 - t, 3) : t * t * (3 - 2 * t))
        return (fromZoom + (toZoom - fromZoom) * e,
                CGSize(width: fromPan.width + (toPan.width - fromPan.width) * e,
                       height: fromPan.height + (toPan.height - fromPan.height) * e))
    }
}

/// Pinch zoom without the wobble: the island's zoom follows the fingers like something on a short
/// string. It moves only once the fingers' zoom is more than `band` away (in log space, as zoom is
/// multiplicative), and then stays exactly `band` behind. A finger's small back-and-forth is
/// absorbed and never shows as the island twitching in and out; a real change of direction (more
/// than twice the band) still turns it round at once.
enum PinchSmoothing {
    /// About 2%.
    static let band: CGFloat = 0.02

    static func next(current: CGFloat, target: CGFloat) -> CGFloat {
        guard current > 0, target > 0 else { return target }
        let d = log(target) - log(current)
        if abs(d) <= band { return current }
        return exp(log(target) - (d > 0 ? band : -band))
    }
}

/// One drag of the island. The camera follows the finger 1:1 from the gesture's translation (not
/// added-up steps, which can skip or double up). The first few points tell a tap from a pan; the pan
/// starts from there (that slop is taken off), so it doesn't leap the moment a tap becomes a pan, as
/// it did. On release, the glide (eased out) starts at exactly the finger's speed.
struct DragPan: Equatable {
    /// The translation when the finger left the tap zone (nil while it could still be a tap).
    private(set) var slop: CGSize?

    var isPanning: Bool { slop != nil }

    /// The camera's pan for this translation, or nil while it's still a tap.
    mutating func pan(start: CGSize, translation: CGSize) -> CGSize? {
        if slop == nil {
            guard !TapClassifier.isTap(translation: translation) else { return nil }
            slop = translation
        }
        let s = slop ?? .zero
        return CGSize(width: start.width + translation.width - s.width, height: start.height + translation.height - s.height)
    }

    static let glideDuration = 0.55

    /// Where the glide after release ends: an ease-out cubic starts at three times its average speed,
    /// so going `velocity × duration ÷ 3` makes it start at exactly the finger's speed.
    static func glideTarget(from pan: CGSize, velocity: CGSize, duration: Double = glideDuration) -> CGSize {
        CGSize(width: pan.width + velocity.width * duration / 3, height: pan.height + velocity.height * duration / 3)
    }
}

/// Turning the island: from closer in, first ease out to the whole island (and stay there), then turn.
enum RotatePlan {
    static let zoomOutDuration = 0.5

    enum Step: Equatable { case zoomOut, turn }

    /// Zoomed in or panned away from the middle: zoom out first. Already at the whole island: turn now.
    static func steps(zoom: CGFloat, pan: CGSize) -> [Step] {
        zoom > IslandLayout.minZoom + 0.01 || hypot(pan.width, pan.height) > 1 ? [.zoomOut, .turn] : [.turn]
    }
}
