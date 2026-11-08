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
