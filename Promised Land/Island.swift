import SwiftUI

// MARK: - Layout

/// Maps island grid coordinates to points, scaled so the whole island fits inside the
/// area left by `insets`, then zoomed about that area's centre. The island can be turned in
/// quarter turns about its middle (`angle`, in quarter turns; fractional while turning).
/// Panning is applied by the view as an offset (see `IslandHitTester`).
struct IslandLayout {
    let scale: CGFloat      // points per grid half-unit (a tile is 2 × scale wide)
    private(set) var origin: CGPoint
    let depth: CGFloat      // height of the earth sides
    let zoom: CGFloat
    /// Quarter turns (0…4, fractional while animating).
    let angle: CGFloat
    /// The grid point the island turns about.
    let pivot: CGPoint
    private let cosA: CGFloat, sinA: CGFloat
    /// The scale that fits the whole island (zoom 1), and the furthest you can zoom in.
    let fit: CGFloat
    let maxZoom: CGFloat

    /// Zoom 1 shows the whole island with a margin. Zooming in goes at least to 4×, and further
    /// on big islands: until a tile is over a third of the screen across, so a single Place
    /// (3–6 tiles) can fill the screen and a building be looked at up close.
    static let minZoom: CGFloat = 1, baseMaxZoom: CGFloat = 4
    /// Points per half tile when fully zoomed in, for a free area this wide.
    static func closestScale(width: CGFloat) -> CGFloat { max(45, width / 5.5) }

    static func maxZoom(island: Island, size: CGSize, insets: EdgeInsets = EdgeInsets()) -> CGFloat {
        IslandLayout(island: island, size: size, insets: insets).maxZoom
    }

    /// Iso bounds of the island's tiles, per island and turn (worked out once, not every frame).
    private static var boundsMemo: [Int: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat, pivot: CGPoint)] = [:]

    /// How far past the limits a pinch may go (it rubber-bands back on release). The camera keeps
    /// its zoom inside this too, so every layer works from the very same number.
    static func clampedZoom(_ zoom: CGFloat, maxZoom: CGFloat) -> CGFloat { min(maxZoom * 1.3, max(minZoom * 0.75, zoom)) }

    /// The nearest whole quarter turn, 0…3.
    var quarter: Int { ((Int((angle).rounded()) % 4) + 4) % 4 }
    /// Code-drawn art is mirrored on odd quarter turns, so buildings face the new way.
    var mirrored: Bool { quarter % 2 == 1 }

    init(island: Island, size: CGSize, insets: EdgeInsets = EdgeInsets(), zoom: CGFloat = 1, angle: CGFloat = 0) {
        self.angle = angle
        cosA = cos(angle * .pi / 2)
        sinA = sin(angle * .pi / 2)
        // Iso units: X = gx - gy, Y = (gx + gy) / 2 (after turning).
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity, minY = CGFloat.infinity, maxY = -CGFloat.infinity
        var memoKey: Int?
        if island.signature != 0 {
            var h = Hasher(); h.combine(island.signature); h.combine(angle); memoKey = h.finalize()
        }
        if let memoKey, let b = Self.boundsMemo[memoKey] {
            (minX, maxX, minY, maxY) = (b.minX, b.maxX, b.minY, b.maxY)
            pivot = b.pivot
        } else {
            let xs = island.tiles.map(\.x), ys = island.tiles.map(\.y)
            let pivot = CGPoint(x: CGFloat((xs.min() ?? 0) + (xs.max() ?? 0) + 1) / 2,
                                y: CGFloat((ys.min() ?? 0) + (ys.max() ?? 0) + 1) / 2)
            self.pivot = pivot
            for t in island.tiles {
                for (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1)] {
                    let r = Self.turn(CGFloat(t.x + dx), CGFloat(t.y + dy), pivot: pivot, cos: cosA, sin: sinA)
                    minX = min(minX, r.x - r.y); maxX = max(maxX, r.x - r.y)
                    minY = min(minY, (r.x + r.y) / 2); maxY = max(maxY, (r.x + r.y) / 2)
                }
            }
            if island.tiles.isEmpty { minX = -1; maxX = 1; minY = 0; maxY = 1 }
            if let memoKey {
                if Self.boundsMemo.count > 64 { Self.boundsMemo.removeAll() }
                Self.boundsMemo[memoKey] = (minX, maxX, minY, maxY, pivot)
            }
        }
        let area = CGSize(width: max(1, size.width - insets.leading - insets.trailing),
                          height: max(1, size.height - insets.top - insets.bottom))
        let depthUnits: CGFloat = 0.3, headroom: CGFloat = 1.3
        let w = maxX - minX, h = maxY - minY + depthUnits + headroom
        let fit = min(area.width / w, area.height / h, 92)
        self.fit = fit
        maxZoom = max(Self.baseMaxZoom, Self.closestScale(width: area.width) / fit)
        // A little past either limit is allowed while pinching (it rubber-bands back on release).
        let z = Self.clampedZoom(zoom, maxZoom: maxZoom)
        let fitOrigin = CGPoint(x: insets.leading + (area.width - w * fit) / 2 - minX * fit,
                                y: insets.top + (area.height - h * fit) / 2 + headroom * fit - minY * fit)
        let centre = CGPoint(x: insets.leading + area.width / 2, y: insets.top + area.height / 2)
        scale = fit * z
        self.zoom = z
        depth = depthUnits * scale
        origin = CGPoint(x: centre.x + (fitOrigin.x - centre.x) * z, y: centre.y + (fitOrigin.y - centre.y) * z)
    }

    private static func turn(_ gx: CGFloat, _ gy: CGFloat, pivot: CGPoint, cos c: CGFloat, sin s: CGFloat) -> CGPoint {
        let dx = gx - pivot.x, dy = gy - pivot.y
        return CGPoint(x: pivot.x + dx * c - dy * s, y: pivot.y + dx * s + dy * c)
    }

    func point(_ gx: CGFloat, _ gy: CGFloat) -> CGPoint {
        let r = Self.turn(gx, gy, pivot: pivot, cos: cosA, sin: sinA)
        return CGPoint(x: origin.x + (r.x - r.y) * scale, y: origin.y + (r.x + r.y) / 2 * scale)
    }

    /// The grid position under a point (the inverse of `point`).
    func grid(_ p: CGPoint) -> CGPoint {
        let X = (p.x - origin.x) / scale, Y = (p.y - origin.y) / scale
        return Self.turn(Y + X / 2, Y - X / 2, pivot: pivot, cos: cosA, sin: -sinA)
    }

    /// The same layout, slid by a pan offset. The island is drawn with the pan built in, so the
    /// drawing always fills the screen however far you zoom and pan.
    func panned(_ d: CGSize) -> IslandLayout {
        var l = self
        l.origin = CGPoint(x: origin.x + d.width, y: origin.y + d.height)
        return l
    }

    /// Drawing order: things lower on screen are in front.
    func depth(_ gx: CGFloat, _ gy: CGFloat) -> CGFloat { point(gx, gy).y }

    /// Size unit for drawing things, so they scale with the tiles.
    var u: CGFloat { scale / 22 }
}

// MARK: - Tapping

/// A touch only counts as a tap if the finger barely moved; anything more is a pan.
enum TapClassifier {
    static let slop: CGFloat = 10
    static func isTap(translation: CGSize) -> Bool { hypot(translation.width, translation.height) < slop }
}

/// Finds the island item under a touch, through the shared `HitPicker`: each item's ground
/// patch, plus the bounds of what is actually drawn (from the same numbers the painter uses),
/// in reverse depth order, with a 44pt minimum target.
enum IslandHitTester {
    /// Small things are always at least this easy to hit (in points).
    static let minimumTarget: CGFloat = 44

    /// - Parameters:
    ///   - point: the touch, in the island view's coordinates.
    ///   - pan: the view's current pan offset (subtracted before mapping to the grid).
    /// - Returns: the index of the front-most item under the touch, or nil for empty ground.
    static func hit(point: CGPoint, layout: IslandLayout, pan: CGSize = .zero, items: [Island.Item]) -> Int? {
        let p = CGPoint(x: point.x - pan.width, y: point.y - pan.height)
        return HitPicker.pick(p, from: candidates(at: p, layout: layout, items: items), minimumTarget: minimumTarget)
    }

    static func candidates(at p: CGPoint, layout: IslandLayout, items: [Island.Item]) -> [HitCandidate<Int>] {
        let g = layout.grid(p)
        return items.enumerated().map { i, item in
            HitCandidate(id: i, depth: layout.depth(item.gx, item.gy), onGround: item.footprint.contains(g),
                         bounds: IslandPainter.drawnBounds(of: item, layout: layout))
        }
    }

    /// The drawn shape of code-drawn things, in view points (sizes match the painters).
    static func shape(of item: Island.Item, base: CGPoint, u: CGFloat) -> CGRect {
        switch item.kind {
        case .piece:
            return rect(PlaceArt.size(item), base: base, u: u)
        case .flourish:
            return .zero
        case .reward(let kind):
            return rect(RewardArt.size(kind), base: base, u: u)
        case .tree:
            return rect(CGSize(width: 18, height: 30), base: base, u: u)
        case .extra(let kind):
            return rect(PlaceArt.extraSize(kind), base: base, u: u)
        case .library:
            return rect(LibraryArt.size(LibraryArt.stage(of: item)), base: base, u: u)
        case .throne:
            return rect(CGSize(width: 46, height: 66), base: base, u: u)
        }
    }

    private static func rect(_ size: CGSize, base: CGPoint, u: CGFloat) -> CGRect {
        CGRect(x: base.x - size.width / 2 * u, y: base.y - size.height * u, width: size.width * u, height: size.height * u + 2 * u)
    }
}

// MARK: - Drawing

enum IslandPainter {
    /// The ground: sand on two soft layers of earth, a shallow band and foam where it meets
    /// the sea, and a warmer courtyard for each book's plot.
    /// - Parameter visible: only tiles near this rect (in the layout's points) are drawn, so a
    ///   ground chunk draws just its own part of a big island.
    static func drawTiles(_ c: inout GraphicsContext, island: Island, layout: IslandLayout, visible: CGRect? = nil) {
        let set = Set(island.tiles)
        let reach = layout.scale * 2 + layout.u * 30 + layout.depth
        let near: (Island.Tile) -> Bool = { t in
            guard let visible else { return true }
            let p = layout.point(CGFloat(t.x) + 0.5, CGFloat(t.y) + 0.5)
            return visible.insetBy(dx: -reach, dy: -reach).contains(p)
        }
        let tiles = visible == nil ? island.tiles : island.tiles.filter(near)
        func corners(_ t: Island.Tile) -> [CGPoint] {
            [layout.point(CGFloat(t.x), CGFloat(t.y)), layout.point(CGFloat(t.x + 1), CGFloat(t.y)),
             layout.point(CGFloat(t.x + 1), CGFloat(t.y + 1)), layout.point(CGFloat(t.x), CGFloat(t.y + 1))]
        }
        let round = StrokeStyle(lineWidth: layout.u * 3, lineJoin: .round)
        let down = layout.depth, half = layout.depth * 0.42

        // Shallow water and foam around the shore, at sea level.
        let base = Path { p in
            for t in tiles { p.addLines(corners(t).map { CGPoint(x: $0.x, y: $0.y + down) }); p.closeSubpath() }
        }
        c.stroke(base, with: .color(Earthy.shallow), style: StrokeStyle(lineWidth: layout.u * 30, lineJoin: .round))
        c.stroke(base, with: .color(Earthy.foam), style: StrokeStyle(lineWidth: layout.u * 9, lineJoin: .round))

        // Earth sides where the edge faces you: an upper and a lower layer, left lighter.
        func side(_ a: CGPoint, _ b: CGPoint, top: Color, bottom: Color) {
            let upper = Path { $0.addLines([a, b, CGPoint(x: b.x, y: b.y + half), CGPoint(x: a.x, y: a.y + half)]); $0.closeSubpath() }
            let lower = Path { $0.addLines([CGPoint(x: a.x, y: a.y + half), CGPoint(x: b.x, y: b.y + half),
                                            CGPoint(x: b.x, y: b.y + down), CGPoint(x: a.x, y: a.y + down)]); $0.closeSubpath() }
            c.fill(lower, with: .color(bottom)); c.stroke(lower, with: .color(bottom), style: round)
            c.fill(upper, with: .color(top)); c.stroke(upper, with: .color(top), style: round)
        }
        // Neighbour across each edge (corner i to i + 1).
        let across = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        for t in tiles.sorted(by: { corners($0).map(\.y).max()! < corners($1).map(\.y).max()! }) {
            let q = corners(t)
            let bottom = q.indices.max { q[$0].y < q[$1].y }!
            // The two edges meeting at the lowest corner face the viewer.
            for edge in [(bottom + 3) % 4, bottom] {
                let n = across[edge]
                guard !set.contains(Island.Tile(x: t.x + n.0, y: t.y + n.1)) else { continue }
                let a = q[edge], b = q[(edge + 1) % 4]
                let isLeft = min(a.x, b.x) < q[bottom].x - 0.5
                side(a.x < b.x ? a : b, a.x < b.x ? b : a, top: isLeft ? Earthy.strataLeftTop : Earthy.strataRightTop,
                     bottom: isLeft ? Earthy.strataLeft : Earthy.strataRight)
            }
        }
        // The top, as one seamless sheet of sand.
        let top = Path { p in for t in tiles { p.addLines(corners(t)); p.closeSubpath() } }
        c.fill(top, with: .color(Earthy.ground))
        c.stroke(top, with: .color(Earthy.ground), style: round)

        // Each Place gets a soft, warmer patch of ground.
        for plot in island.allPlots {
            let inset: CGFloat = 0.3
            let x0 = CGFloat(plot.x) + inset, y0 = CGFloat(plot.y) + inset
            let x1 = CGFloat(plot.x + plot.size) - inset, y1 = CGFloat(plot.y + plot.size) - inset
            let yard = Path { $0.addLines([layout.point(x0, y0), layout.point(x1, y0), layout.point(x1, y1), layout.point(x0, y1)]); $0.closeSubpath() }
            let tint = plot.bookID == IslandPlacement.forestKey ? Color(hex: "#E3DCA6") : Earthy.groundWarm
            c.fill(yard, with: .color(tint.opacity(0.7)))
            c.stroke(yard, with: .color(tint.opacity(0.7)), style: StrokeStyle(lineWidth: layout.u * 14, lineJoin: .round))
        }
        drawRoads(&c, island: island, layout: layout)
        // A few light patches, so the sand isn't flat.
        for t in tiles where Noise.hash(t.x, t.y, seed: 41) > 0.9 {
            let p = layout.point(CGFloat(t.x) + 0.5, CGFloat(t.y) + 0.5)
            let w = layout.u * (10 + 8 * Noise.hash(t.x, t.y, seed: 43))
            c.fill(Path(ellipseIn: CGRect(x: p.x - w, y: p.y - w * 0.32, width: 2 * w, height: w * 0.64)), with: .color(Earthy.groundLight))
        }
    }

    /// Soft dirt roads between Places, through the middle of their tiles.
    static func drawRoads(_ c: inout GraphicsContext, island: Island, layout: IslandLayout) {
        guard !island.roads.isEmpty else { return }
        let path = Path { p in
            for road in island.roads where road.count > 1 {
                p.move(to: layout.point(CGFloat(road[0].x) + 0.5, CGFloat(road[0].y) + 0.5))
                for t in road.dropFirst() { p.addLine(to: layout.point(CGFloat(t.x) + 0.5, CGFloat(t.y) + 0.5)) }
            }
        }
        c.stroke(path, with: .color(Earthy.groundWarm), style: StrokeStyle(lineWidth: layout.scale * 0.62, lineCap: .round, lineJoin: .round))
        c.stroke(path, with: .color(Earthy.path), style: StrokeStyle(lineWidth: layout.scale * 0.42, lineCap: .round, lineJoin: .round))
    }

    /// Gentle waves on the sea around the island (drawn under it, animated by `time`). Their
    /// spots are worked out once per island; only those on screen are drawn.
    static func drawWaves(_ c: inout GraphicsContext, island: Island, layout: IslandLayout, time: Double, visible: CGRect? = nil) {
        let u = layout.u
        let w = 7 * u, h = 2.2 * u
        for spot in WaveSpots.spots(island) {
            let drift = sin(time * 0.7 + spot.phase) * 0.12
            let p = layout.point(spot.x + 0.5 + drift, spot.y + 0.5)
            if let visible, !visible.contains(p) { continue }
            let alpha = 0.35 + 0.35 * sin(time * 1.1 + spot.phase)
            let wave = Path { path in
                path.move(to: CGPoint(x: p.x - w, y: p.y + layout.depth))
                path.addQuadCurve(to: CGPoint(x: p.x, y: p.y + layout.depth), control: CGPoint(x: p.x - w / 2, y: p.y + layout.depth - h))
                path.addQuadCurve(to: CGPoint(x: p.x + w, y: p.y + layout.depth), control: CGPoint(x: p.x + w / 2, y: p.y + layout.depth - h))
            }
            c.stroke(wave, with: .color(Earthy.foam.opacity(max(0, alpha))), style: StrokeStyle(lineWidth: 1.4 * u, lineCap: .round))
        }
    }

    /// The open sea: wave marks over the whole of `visible`, however far out you zoom, in one tiled
    /// fill of a small cached picture. The tiling is anchored to the island's grid (it pans, zooms
    /// and turns with the island) and lies under the land, which covers it. A gentle overall shimmer
    /// keeps it alive; the surf along the coast is drawn separately (`drawWaves`).
    static func drawOpenSea(_ c: inout GraphicsContext, island: Island, layout: IslandLayout, time: Double, visible: CGRect) {
        guard let tile = OpenSea.tile() else { return }
        let fill = OpenSea.fill(layout: layout)
        var g = c
        g.opacity = 0.75 + 0.25 * sin(time * 0.9)
        g.fill(Path(visible), with: .tiledImage(Image(decorative: tile, scale: OpenSea.tileScale), origin: fill.origin,
                                                 sourceRect: CGRect(x: 0, y: 0, width: 1, height: 1), scale: fill.scale))
    }

    static func drawItem(_ c: inout GraphicsContext, _ item: Island.Item, layout: IslandLayout, scale: CGFloat = 1) {
        let p = layout.point(item.gx, item.gy)
        var g = c
        g.translateBy(x: p.x, y: p.y)
        let mirrored = layout.mirrored != (item.turned % 2 != 0)
        g.scaleBy(x: mirrored ? -scale : scale, y: scale)
        draw(&g, item, u: layout.u, tileWidth: layout.scale * 2, rotation: layout.quarter, mirrored: mirrored)
    }

    /// Draws an item around the context's origin (its ground point), as `drawItem` does.
    static func drawAtOrigin(_ c: inout GraphicsContext, _ item: Island.Item, u: CGFloat, quarter: Int, layoutMirrored: Bool) {
        let mirrored = layoutMirrored != (item.turned % 2 != 0)
        if mirrored { c.scaleBy(x: -1, y: 1) }
        draw(&c, item, u: u, tileWidth: u * 44, rotation: quarter, mirrored: mirrored)
    }

    private static func draw(_ c: inout GraphicsContext, _ item: Island.Item, u: CGFloat, tileWidth: CGFloat, rotation: Int,
                             mirrored: Bool) {
        if let art = art(for: item) {
            c.draw(Image(decorative: art.image, scale: 2), in: imageRect(art, item: item, tileWidth: tileWidth))
            return
        }
        let pen = IsoPen(c: c, u: u)
        switch item.kind {
        case .piece(let kind):
            if case .place(let bookID, _) = item.source,
               let custom = ArtAssets.place(bookID, piece: kind.rawValue, level: max(1, item.level), rotation: rotation) {
                drawCustom(&c, custom, tileWidth: tileWidth)
                return
            }
            // Which way the bay lies on screen, after the island's turn and any mirroring.
            var side = ((item.facing + 3 * rotation) % 4 + 4) % 4
            if mirrored { side = [1, 0, 3, 2][side] }
            PlaceArt.draw(pen, item: item, kind: kind, side: side)
        case .flourish:
            PlaceArt.flourish(pen, count: Int(item.growth), span: item.span, seed: item.seed)
        case .reward(let kind):
            RewardArt.draw(pen, kind, seed: item.seed)
        case .tree:
            PlaceArt.forestTree(pen, seed: item.seed)
        case .extra(let kind):
            PlaceArt.extra(pen, kind, seed: item.seed)
        case .library:
            let stage = LibraryArt.stage(of: item)
            if let custom = LibraryArt.custom(stage, rotation: rotation) {
                drawCustom(&c, custom, tileWidth: tileWidth)
                return
            }
            LibraryArt.draw(pen, item: item)
        case .throne:
            ThroneArt.draw(pen)
        }
    }

    /// Hand-made art, bottom-centre on the ground point, at `ArtAssets.pointsPerTile` per tile.
    private static func drawCustom(_ c: inout GraphicsContext, _ art: ArtAssets.Art, tileWidth: CGFloat) {
        let k = tileWidth / ArtAssets.pointsPerTile
        let w = art.size.width * k, h = art.size.height * k
        c.draw(Image(decorative: art.image, scale: 1), in: CGRect(x: -w / 2, y: -h, width: w, height: h))
    }

    /// The pre-drawn picture for image-based kinds. None on the island now: the Library is drawn
    /// in code for its stage (LibraryArt); `LandmarkMiniCache.library()` stays for the reading lists.
    static func art(for item: Island.Item) -> LandmarkImage? { nil }

    /// Where an image-based item is drawn, relative to its ground point. Shared by drawing and tapping.
    static func imageRect(_ art: LandmarkImage, item _: Island.Item, tileWidth: CGFloat) -> CGRect {
        // The Library's picture covers a 3-tile footprint; it's shown on its 2 × 2 spot.
        let k = tileWidth / Iso.tileWidth * 0.95 * 2 / 3
        let w = art.pointSize.width * k, h = art.pointSize.height * k
        return CGRect(x: -w / 2, y: -(1 - art.anchor.y) * h, width: w, height: h)
    }

    /// The bounds of what's actually drawn for an item, in view points (before panning).
    static func drawnBounds(of item: Island.Item, layout: IslandLayout) -> CGRect {
        let base = layout.point(item.gx, item.gy)
        guard let art = art(for: item) else {
            return IslandHitTester.shape(of: item, base: base, u: layout.u)
        }
        let rect = imageRect(art, item: item, tileWidth: layout.scale * 2).offsetBy(dx: base.x, dy: base.y)
        let visible = LandmarkMiniCache.opaqueUnitRect(item.kind, level: item.level, art)
        return CGRect(x: rect.minX + visible.minX * rect.width, y: rect.minY + visible.minY * rect.height,
                      width: visible.width * rect.width, height: visible.height * rect.height)
    }
}

/// Small finished-landmark pictures for the island, drawn once per style.
@MainActor
enum LandmarkMiniCache {
    private static var libraryArt: LandmarkImage?
    private static var opaque: [String: CGRect] = [:]

    /// The visible part of an item's picture (a unit rect, y down), measured once per picture.
    static func opaqueUnitRect(_ kind: Island.Kind, level: Int, _ art: LandmarkImage) -> CGRect {
        let key = "\(kind)-\(level)"
        if let cached = opaque[key] { return cached }
        let rect = OpaqueBounds.unitRect(of: art.image)
        opaque[key] = rect
        return rect
    }

    /// The Library building, drawn by the same painter as on the world map (3-tile footprint).
    static func library() -> LandmarkImage? {
        if let libraryArt { return libraryArt }
        libraryArt = LandmarkPainter.canvas(size: 3, scale: 2) { $0.libraryBuilding() }
        return libraryArt
    }
}

private extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
}

/// Where waves ripple around an island: open-sea tiles near it, picked once per island.
@MainActor
/// The open sea's pattern: a block of the island's diamond lattice (`cells` × `cells` lattice
/// steps) with a wave mark at every lattice point, nudged so it doesn't look gridded. On screen a
/// lattice step of `spacing` tiles is a `2·s·scale` × `s·scale` rectangle with points at its corner
/// and centre, at every turn, so the block tiles seamlessly in the island's own space.
enum OpenSea {
    static let cells = 4
    /// The tile picture's size in points (it's rendered at 2×).
    static let tileSize = CGSize(width: 512, height: 256)
    static let tileScale: CGFloat = 2

    /// Lattice spacing in tiles for a tile this wide on screen: marks about 40+ points apart.
    static func spacing(tileWidth: CGFloat) -> Int {
        var step = 2
        while CGFloat(step) * tileWidth < 40, step < 1024 { step *= 2 }
        return step
    }

    /// Where the tiling starts (a lattice point, from the island's grid origin) and how much the
    /// picture is scaled, for this camera.
    static func fill(layout: IslandLayout) -> (origin: CGPoint, scale: CGFloat) {
        let step = CGFloat(spacing(tileWidth: layout.scale * 2))
        let blockWidth = 2 * step * layout.scale * CGFloat(cells)
        return (layout.point(0, 0), blockWidth / tileSize.width)
    }

    /// The pattern, drawn once.
    static func tile() -> CGImage? {
        if let cached { return cached }
        let size = tileSize
        let n = cells
        let renderer = ImageRenderer(content: Canvas { c, _ in
            let cw = size.width / CGFloat(n), ch = size.height / CGFloat(n)
            for j in 0..<n {
                for i in 0..<n {
                    for (k, centre) in [(0, CGPoint(x: 0, y: 0)), (1, CGPoint(x: cw / 2, y: ch / 2))] {
                        // A fixed nudge per point (the same every time, so the tiling is seamless).
                        let h = (i * 7 + j * 13 + k * 29) % 17
                        let p = CGPoint(x: CGFloat(i) * cw + centre.x + CGFloat(h - 8) * cw * 0.03,
                                        y: CGFloat(j) * ch + centre.y + CGFloat((h * 5) % 17 - 8) * ch * 0.04)
                        let w: CGFloat = 15, hgt: CGFloat = 5
                        let wave = Path { path in
                            path.move(to: CGPoint(x: p.x - w, y: p.y))
                            path.addQuadCurve(to: p, control: CGPoint(x: p.x - w / 2, y: p.y - hgt))
                            path.addQuadCurve(to: CGPoint(x: p.x + w, y: p.y), control: CGPoint(x: p.x + w / 2, y: p.y - hgt))
                        }
                        // Drawn again shifted by a whole tile where it crosses an edge, so it wraps.
                        for dx in [-size.width, 0, size.width] {
                            for dy in [-size.height, 0, size.height] {
                                c.stroke(wave.offsetBy(dx: dx, dy: dy), with: .color(Earthy.foam.opacity(0.35 + Double(h) / 17 * 0.3)),
                                         style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            }
                        }
                    }
                }
            }
        }.frame(width: size.width, height: size.height))
        renderer.scale = tileScale
        cached = renderer.cgImage
        return cached
    }

    private static var cached: CGImage?
}

enum WaveSpots {
    struct Spot { let x: CGFloat; let y: CGFloat; let phase: Double }
    private static var memo: (key: Int, spots: [Spot]) = (-1, [])

    private static var bySignature: (signature: Int, spots: [Spot]) = (0, [])

    static func spots(_ island: Island) -> [Spot] {
        // Called every wave frame: a built island's spots are looked up by its signature.
        if island.signature != 0, bySignature.signature == island.signature { return bySignature.spots }
        let spots = compute(island)
        if island.signature != 0 { bySignature = (island.signature, spots) }
        return spots
    }

    private static func compute(_ island: Island) -> [Spot] {
        let xs = island.tiles.map(\.x), ys = island.tiles.map(\.y)
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { return [] }
        var h = Hasher(); h.combine(x0); h.combine(x1); h.combine(y0); h.combine(y1); h.combine(island.tiles.count); h.combine(island.water.count)
        let key = h.finalize()
        if memo.key == key { return memo.spots }
        let land = Set(island.tiles)
        var out: [Spot] = []
        for ty in (y0 - 5)...(y1 + 5) {
            for tx in (x0 - 5)...(x1 + 5) where Noise.hash(tx, ty, seed: 57) > 0.72 && !land.contains(Island.Tile(x: tx, y: ty)) {
                out.append(Spot(x: CGFloat(tx), y: CGFloat(ty), phase: Noise.hash(tx, ty, seed: 59) * 6.28))
            }
        }
        memo = (key, out)
        return out
    }
}
