import SwiftUI

// MARK: - Model

/// The home island. Every piece of reading adds one thing, in the order it happened,
/// so nothing already placed ever moves. The island grows new grass tiles as it fills.
struct Island: Equatable {
    struct Tile: Hashable { let x: Int; let y: Int }

    enum Kind: Equatable {
        case tuft, flower, flowers, bush, rock, olive, cypress, palm, sheep, tent, well, house
        case fruitTree   // a quiz passed
        case lantern     // a verse memorised
        case landmark(BuildingStyle) // a book finished
        case library     // a feature building: appears after the first journal entry

        /// How much of a tile it takes up (4 = a whole tile).
        var weight: Int {
            switch self {
            case .landmark, .library: 4
            case .house, .well, .tent, .fruitTree: 2
            default: 1
            }
        }

        /// Tall things are redrawn in front of the character when it walks behind them.
        var isTall: Bool {
            switch self {
            case .tuft, .flower, .flowers, .rock, .bush, .sheep: false
            default: true
            }
        }
    }

    /// What put an item on the island, so tapping it can explain itself.
    enum Source: Equatable {
        case chapter(book: String, chapter: Int)
        case quiz(book: String)
        case verse(book: String)
        case finished(book: String)
        case feature(Feature)

        var bookID: String? {
            switch self {
            case .chapter(let b, _), .quiz(let b), .verse(let b), .finished(let b): b
            case .feature: nil
            }
        }
    }

    /// Feature buildings: features unlock as buildings on the island.
    enum Feature: String, CaseIterable {
        case library
    }

    struct Item: Equatable {
        let kind: Kind
        let gx: CGFloat
        let gy: CGFloat
        let seed: Int
        var source: Source = .feature(.library)
        /// The patch of ground it stands on, in grid units (for hit testing).
        var footprint: CGRect = .zero
    }

    let tiles: [Tile]
    let items: [Item]

    static let empty = Island.build(chapters: [], quizzes: [], verses: [])

    /// Index of the feature building's item, if it's on the island.
    func index(of feature: Feature) -> Int? {
        items.firstIndex { $0.source == .feature(feature) }
    }

    // MARK: Building

    private enum Event {
        case chapter(book: String, chapter: Int)
        case quiz(book: String)
        case verse(book: String)
        case finished(book: String)

        var order: Int {
            switch self { case .chapter: 0; case .finished: 1; case .quiz: 2; case .verse: 3 }
        }
        var key: String {
            switch self {
            case .chapter(let b, let c): "\(b)#\(String(format: "%04d", c))"
            case .quiz(let b), .verse(let b), .finished(let b): b
            }
        }
    }

    static func build(chapters: [(book: String, chapter: Int, date: Date)],
                      quizzes: [(book: String, date: Date)],
                      verses: [(book: String, date: Date)],
                      features: Set<Feature> = []) -> Island {
        // Gather every piece of reading as a dated event.
        var events: [(Date, Event)] = chapters.map { ($0.date, .chapter(book: $0.book, chapter: $0.chapter)) }
        events += quizzes.map { ($0.date, .quiz(book: $0.book)) }
        events += verses.map { ($0.date, .verse(book: $0.book)) }
        // A finished book counts from the moment its last chapter was read.
        for (bookID, reads) in Dictionary(grouping: chapters, by: \.book) {
            guard let book = BibleCatalog.book(id: bookID) else { continue }
            let distinct = Set(reads.map(\.chapter)).filter { book.chapterNumbers.contains($0) }
            if distinct.count >= book.chapterCount, let last = reads.map(\.date).max() {
                events.append((last, .finished(book: bookID)))
            }
        }
        events.sort { ($0.0, $0.1.order, $0.1.key) < ($1.0, $1.1.order, $1.1.key) }

        // Turn events into things, and lay them out tile by tile.
        var placement = IslandPlacement()
        var items: [Item] = []
        var chapterCount = 0
        for (_, event) in events {
            let kind: Kind
            let source: Source
            let seed = Self.hash(event.key)
            switch event {
            case .chapter(let b, let c):
                kind = chapterKind(chapterCount, seed: seed)
                chapterCount += 1
                source = .chapter(book: b, chapter: c)
            case .quiz(let b): kind = .fruitTree; source = .quiz(book: b)
            case .verse(let b): kind = .lantern; source = .verse(book: b)
            case .finished(let bookID):
                kind = .landmark(WorldData.landmark(bookID: bookID)?.style ?? .house)
                source = .finished(book: bookID)
            }
            items.append(placement.place(kind, seed: seed, source: source))
        }
        // Feature buildings take their reserved spots near the centre (added last, so they build in).
        for feature in Feature.allCases where features.contains(feature) {
            items.append(placement.place(feature))
        }
        return Island(tiles: placement.tiles(including: features), items: items)
    }

    static let tileOrderShared: [Tile] = tileOrder

    /// Chapters add small things mostly, with trees, sheep and buildings mixed in.
    private static func chapterKind(_ n: Int, seed: Int) -> Kind {
        if n == 0 { return .flowers }
        if n % 47 == 46 { return .house }
        if n % 61 == 30 { return .well }
        if n % 37 == 18 { return .tent }
        if n % 23 == 11 { return .sheep }
        if n % 13 == 6 { return .olive }
        if n % 17 == 8 { return .cypress }
        if n % 29 == 20 { return .palm }
        let small: [Kind] = [.tuft, .flower, .flowers, .bush, .tuft, .rock, .flower]
        return small[seed % small.count]
    }

    /// The centre of a run of `weight` quarter-spots starting at `start` within a tile.
    static func spotCentre(start: Int, weight: Int) -> CGPoint {
        switch weight {
        case 4: return CGPoint(x: 0.5, y: 0.5)
        case 2: return [CGPoint(x: 0.5, y: 0.3), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.72)][min(start, 2)]
        default: return [CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.72, y: 0.32), CGPoint(x: 0.3, y: 0.72), CGPoint(x: 0.7, y: 0.7)][start % 4]
        }
    }

    /// Tiles in the order the island grows: outward from the middle, with a little
    /// randomness so the coastline stays organic.
    private static let tileOrder: [Tile] = {
        let n = 26, mid = Double(n - 1) / 2
        var cells: [(Tile, Double)] = []
        for y in 0..<n {
            for x in 0..<n {
                let d = hypot(Double(x) - mid, Double(y) - mid)
                cells.append((Tile(x: x, y: y), d + Noise.hash(x, y, seed: 77) * 1.1))
            }
        }
        return cells.sorted { $0.1 < $1.1 }.map(\.0)
    }()

    static func hash(_ s: String) -> Int {
        Int(s.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 } & 0xFFFFFF)
    }

    static func unit(_ seed: Int, _ salt: Int) -> CGFloat {
        CGFloat(Noise.hash(seed, salt, seed: 5))
    }
}

// MARK: - Layout

/// Maps island grid coordinates to points, scaled so the whole island fits inside the
/// area left by `insets`, then zoomed about that area's centre. Panning is applied by the
/// view as an offset (see `IslandHitTester`).
struct IslandLayout {
    let scale: CGFloat      // points per grid half-unit (a tile is 2 × scale wide)
    let origin: CGPoint
    let depth: CGFloat      // height of the earth sides
    let zoom: CGFloat

    static let minZoom: CGFloat = 1, maxZoom: CGFloat = 4

    init(island: Island, size: CGSize, insets: EdgeInsets = EdgeInsets(), zoom: CGFloat = 1) {
        // Iso units: X = gx - gy, Y = (gx + gy) / 2.
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity, minY = CGFloat.infinity, maxY = -CGFloat.infinity
        for t in island.tiles {
            for (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1)] {
                let gx = CGFloat(t.x + dx), gy = CGFloat(t.y + dy)
                minX = min(minX, gx - gy); maxX = max(maxX, gx - gy)
                minY = min(minY, (gx + gy) / 2); maxY = max(maxY, (gx + gy) / 2)
            }
        }
        let area = CGSize(width: max(1, size.width - insets.leading - insets.trailing),
                          height: max(1, size.height - insets.top - insets.bottom))
        let depthUnits: CGFloat = 0.3, headroom: CGFloat = 1.3
        let w = maxX - minX, h = maxY - minY + depthUnits + headroom
        let fit = min(area.width / w, area.height / h, 92)
        let z = min(Self.maxZoom, max(Self.minZoom, zoom))
        let fitOrigin = CGPoint(x: insets.leading + (area.width - w * fit) / 2 - minX * fit,
                                y: insets.top + (area.height - h * fit) / 2 + headroom * fit - minY * fit)
        let centre = CGPoint(x: insets.leading + area.width / 2, y: insets.top + area.height / 2)
        scale = fit * z
        self.zoom = z
        depth = depthUnits * scale
        origin = CGPoint(x: centre.x + (fitOrigin.x - centre.x) * z, y: centre.y + (fitOrigin.y - centre.y) * z)
    }

    func point(_ gx: CGFloat, _ gy: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + (gx - gy) * scale, y: origin.y + (gx + gy) / 2 * scale)
    }

    /// The grid position under a point (the inverse of `point`).
    func grid(_ p: CGPoint) -> CGPoint {
        let X = (p.x - origin.x) / scale, Y = (p.y - origin.y) / scale
        return CGPoint(x: Y + X / 2, y: Y - X / 2)
    }

    /// Size unit for drawing things, so they scale with the tiles.
    var u: CGFloat { scale / 22 }
}

// MARK: - Tapping

/// A touch only counts as a tap if the finger barely moved; anything more is a pan.
enum TapClassifier {
    static let slop: CGFloat = 10
    static func isTap(translation: CGSize) -> Bool { hypot(translation.width, translation.height) < slop }
}

/// Finds the island item under a touch.
enum IslandHitTester {
    /// Small things are always at least this easy to hit (in points).
    static let minimumTarget: CGFloat = 44

    /// - Parameters:
    ///   - point: the touch, in the island view's coordinates.
    ///   - pan: the view's current pan offset (subtracted before mapping to the grid).
    /// - Returns: the index of the top-most item whose ground (or drawn shape, for tall
    ///   things) is under the touch; failing that, the nearest item within 22pt.
    static func hit(point: CGPoint, layout: IslandLayout, pan: CGSize = .zero, items: [Island.Item]) -> Int? {
        let p = CGPoint(x: point.x - pan.width, y: point.y - pan.height)
        let g = layout.grid(p)
        var direct: [(index: Int, depth: CGFloat, distance: CGFloat)] = []
        var near: (index: Int, distance: CGFloat)?
        for (i, item) in items.enumerated() {
            let base = layout.point(item.gx, item.gy)
            let distance = hypot(p.x - base.x, p.y - base.y)
            let onGround = item.footprint.contains(g)
            let onShape = shape(of: item, base: base, u: layout.u).contains(p)
            if onGround || onShape {
                direct.append((i, item.gx + item.gy, distance))
            } else if distance <= minimumTarget / 2, distance < (near?.distance ?? .infinity) {
                near = (i, distance)
            }
        }
        // Reverse depth order: the item drawn in front wins; ties go to the nearest.
        if let best = direct.max(by: { ($0.depth, -$0.distance) < ($1.depth, -$1.distance) }) { return best.index }
        return near?.index
    }

    /// The drawn shape of tall things (above their ground patch), in view points.
    static func shape(of item: Island.Item, base: CGPoint, u: CGFloat) -> CGRect {
        let size: (w: CGFloat, h: CGFloat)
        switch item.kind {
        case .olive: size = (15, 22)
        case .cypress: size = (7, 21)
        case .palm: size = (16, 20)
        case .house: size = (16, 23)
        case .well: size = (13, 19)
        case .tent: size = (16, 12)
        case .fruitTree: size = (18, 24)
        case .lantern: size = (8, 19)
        case .landmark, .library: size = (40, 50)
        case .tuft, .flower, .flowers, .bush, .rock, .sheep: return .zero
        }
        return CGRect(x: base.x - size.w / 2 * u, y: base.y - size.h * u, width: size.w * u, height: size.h * u)
    }
}

// MARK: - Drawing

enum IslandPainter {
    static func drawTiles(_ c: inout GraphicsContext, island: Island, layout: IslandLayout) {
        let set = Set(island.tiles)
        let shadow = Path { p in
            for t in island.tiles {
                let a = layout.point(CGFloat(t.x), CGFloat(t.y)), b = layout.point(CGFloat(t.x + 1), CGFloat(t.y))
                let d = layout.point(CGFloat(t.x + 1), CGFloat(t.y + 1)), e = layout.point(CGFloat(t.x), CGFloat(t.y + 1))
                let off = layout.depth * 1.8
                p.addLines([a, b, d, e].map { CGPoint(x: $0.x, y: $0.y + off) }); p.closeSubpath()
            }
        }
        c.fill(shadow, with: .color(Color.primaryBrown.opacity(0.05)))

        for t in island.tiles.sorted(by: { ($0.x + $0.y, $0.x) < ($1.x + $1.y, $1.x) }) {
            let n = layout.point(CGFloat(t.x), CGFloat(t.y)), east = layout.point(CGFloat(t.x + 1), CGFloat(t.y))
            let s = layout.point(CGFloat(t.x + 1), CGFloat(t.y + 1)), w = layout.point(CGFloat(t.x), CGFloat(t.y + 1))
            let down = CGPoint(x: 0, y: layout.depth)
            func poly(_ pts: [CGPoint], _ color: Color) {
                c.fill(Path { p in p.addLines(pts); p.closeSubpath() }, with: .color(color))
            }
            // Earth sides only where the island's edge is exposed: left lighter, right darker.
            if !set.contains(Island.Tile(x: t.x, y: t.y + 1)) {
                poly([w, s, s + down, w + down], .stoneLight)
            }
            if !set.contains(Island.Tile(x: t.x + 1, y: t.y)) {
                poly([s, east, east + down, s + down], .stoneShade)
            }
            let jitter = Noise.hash(t.x, t.y, seed: 31) - 0.5
            poly([n, east, s, w], Color(hex: "#C9D29A").opacity(0.94 + jitter * 0.12))
            poly([n, east, s, w], Color.olive.opacity(0.10 + jitter * 0.08))
        }
    }

    static func drawItem(_ c: inout GraphicsContext, _ item: Island.Item, layout: IslandLayout, scale: CGFloat = 1) {
        let p = layout.point(item.gx, item.gy)
        var g = c
        g.translateBy(x: p.x, y: p.y)
        g.scaleBy(x: scale, y: scale)
        draw(&g, item, u: layout.u, tileWidth: layout.scale * 2)
    }

    private static func draw(_ c: inout GraphicsContext, _ item: Island.Item, u: CGFloat, tileWidth: CGFloat) {
        let petals: [Color] = [.terracotta, .lavender, .wheat, .cream]
        let hue = item.seed % petals.count
        let petal = petals[hue]
        func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
            c.fill(Path(ellipseIn: CGRect(x: (x - w / 2) * u, y: (y - h / 2) * u, width: w * u, height: h * u)), with: .color(color))
        }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color, radius: CGFloat = 0) {
            c.fill(Path(roundedRect: CGRect(x: x * u, y: y * u, width: w * u, height: h * u), cornerRadius: radius * u), with: .color(color))
        }
        func poly(_ pts: [(CGFloat, CGFloat)], _ color: Color) {
            c.fill(Path { p in p.addLines(pts.map { CGPoint(x: $0.0 * u, y: $0.1 * u) }); p.closeSubpath() }, with: .color(color))
        }
        func flower(_ x: CGFloat, _ y: CGFloat, _ color: Color) {
            rect(x - 0.4, y - 4, 0.8, 4, .olive, radius: 0.4)
            ellipse(x, y - 4.4, 2.8, 2.6, color)
        }
        func shadow(_ w: CGFloat) { ellipse(0, 0.6, w, w * 0.32, Color.primaryBrown.opacity(0.10)) }
        func tree(canopy: CGFloat, trunk: CGFloat, light: Color = .olive) {
            shadow(canopy * 0.9)
            rect(-trunk * 0.12, -trunk, trunk * 0.24, trunk, Color(hex: "#A9805C"), radius: trunk * 0.12)
            ellipse(canopy * 0.12, -trunk - canopy * 0.28, canopy, canopy * 0.82, Color(hex: "#929E66"))
            ellipse(-canopy * 0.08, -trunk - canopy * 0.36, canopy * 0.95, canopy * 0.8, light)
        }
        /// An isometric box with a pyramid roof (base at the origin).
        func building(width w: CGFloat, height h: CGFloat, roof: Color) {
            shadow(w * 1.3)
            poly([(-w / 2, 0), (0, w / 4), (0, w / 4 - h), (-w / 2, -h)], .stoneLight)
            poly([(0, w / 4), (w / 2, 0), (w / 2, -h), (0, w / 4 - h)], .stoneShade)
            let rw = w + 2
            poly([(-rw / 2, -h), (0, -h + rw / 4), (0, -h - w * 0.5)], roof)
            poly([(0, -h + rw / 4), (rw / 2, -h), (0, -h - w * 0.5)], roof.opacity(0.82))
            rect(-w * 0.32, -h * 0.55, w * 0.14, h * 0.45, Color.primaryBrown.opacity(0.2), radius: w * 0.07)
        }

        switch item.kind {
        case .tuft:
            ellipse(-1.4, 0, 4.6, 2.2, Color.olive.opacity(0.85))
            ellipse(1.6, -0.4, 4, 2, Color(hex: "#929E66").opacity(0.8))
        case .flower:
            ellipse(0, 0.2, 4.6, 2, Color.olive.opacity(0.7))
            flower(0, 0, petal)
        case .flowers:
            ellipse(0, 0.4, 8, 2.6, Color.olive.opacity(0.7))
            flower(-2.4, 0.6, petal)
            flower(0.6, -0.4, petals[(hue + 1) % 4])
            flower(2.8, 0.8, petal)
        case .bush:
            shadow(11)
            ellipse(1.6, -3, 11, 7.5, Color(hex: "#929E66"))
            ellipse(-0.8, -3.8, 10.5, 7, .olive)
            ellipse(-2.6, -5.2, 2, 2, petal)
        case .rock:
            shadow(9)
            ellipse(1.4, -1.8, 8, 5, .stoneShade)
            ellipse(-0.6, -2.4, 7.4, 4.8, .stoneLight)
        case .olive:
            tree(canopy: 15, trunk: 9)
        case .cypress:
            shadow(7)
            ellipse(1, -10, 6.4, 20, Color(hex: "#929E66"))
            ellipse(-0.6, -10.6, 6, 20, .olive)
        case .palm:
            shadow(10)
            rect(-0.9, -16, 1.8, 16, Color(hex: "#A9805C"), radius: 0.9)
            for (dx, dy) in [(-6.0, -15.0), (6.0, -15.0), (-3.5, -18.0), (3.5, -18.0)] {
                ellipse(dx, dy, 9, 3.6, Color(hex: "#9DAE6C"))
            }
        case .sheep:
            shadow(8)
            for (dx, dy) in [(-2.0, -3.4), (0.4, -4.4), (2.2, -3.2), (0.0, -2.4)] { ellipse(dx, dy, 4.4, 4, .cream) }
            ellipse(4.6, -4, 2.6, 2.4, Color(hex: "#6A5640"))
            rect(-2.2, -1.6, 0.8, 1.8, Color(hex: "#6A5640"))
            rect(1.6, -1.6, 0.8, 1.8, Color(hex: "#6A5640"))
        case .tent:
            shadow(16)
            poly([(-8, 0), (0, 3.5), (0, -11)], petal == .cream ? .terracotta : petal)
            poly([(0, 3.5), (8, 0), (0, -11)], (petal == .cream ? Color.terracotta : petal).opacity(0.8))
            poly([(-1.6, 2.8), (0.6, 3.3), (-0.4, -2.2)], Color.primaryBrown.opacity(0.25))
        case .well:
            shadow(14)
            ellipse(0, -2, 11, 5, .stoneShade)
            rect(-5.5, -6, 11, 4, .stoneLight)
            ellipse(0, -6, 11, 5, .stoneLight)
            ellipse(0, -6, 7.6, 3.2, .water)
            rect(-4.6, -15, 0.9, 9, Color(hex: "#A9805C"))
            rect(3.7, -15, 0.9, 9, Color(hex: "#A9805C"))
            poly([(-6.5, -14), (0, -18.5), (6.5, -14)], .terracotta)
        case .house:
            building(width: 14, height: 9, roof: item.seed % 3 == 0 ? .lavender : .terracotta)
        case .fruitTree:
            tree(canopy: 17, trunk: 10)
            for i in 0..<9 {
                let a = CGFloat(i) * 2.4, r = 2 + CGFloat(i % 3) * 2
                ellipse(cos(a) * r * 1.3 - 1, -16 + sin(a) * r * 0.8, 2.2, 2.2, i % 2 == 0 ? .terracotta : .wheat)
            }
            rect(-1.4, -6.5, 2.8, 1.2, .lavender, radius: 0.6)
        case .lantern:
            c.fill(Path(ellipseIn: CGRect(x: -9 * u, y: -21 * u, width: 18 * u, height: 14 * u)),
                   with: .radialGradient(Gradient(colors: [Color.wheat.opacity(0.55), Color.wheat.opacity(0)]),
                                         center: CGPoint(x: 0, y: -14 * u), startRadius: 0, endRadius: 9 * u))
            shadow(5)
            rect(-0.5, -12, 1, 12, Color(hex: "#7A4A2A"))
            rect(-2, -16, 4, 4.5, .wheat, radius: 1)
            ellipse(0, -14, 2.2, 2.2, .cream)
            poly([(-2.6, -16), (0, -18), (2.6, -16)], Color(hex: "#7A4A2A"))
        case .library:
            guard let art = LandmarkMiniCache.library() else { return }
            let k = tileWidth / Iso.tileWidth / 3 * 0.95
            let w = art.pointSize.width * k, h = art.pointSize.height * k
            c.draw(Image(decorative: art.image, scale: 2),
                   in: CGRect(x: -w / 2, y: -(1 - art.anchor.y) * h, width: w, height: h))
        case .landmark(let style):
            guard let art = LandmarkMiniCache.image(style) else { return }
            let k = tileWidth / Iso.tileWidth * 0.95
            let w = art.pointSize.width * k, h = art.pointSize.height * k
            c.draw(Image(decorative: art.image, scale: 2),
                   in: CGRect(x: -w / 2, y: -(1 - art.anchor.y) * h, width: w, height: h))
        }
    }
}

/// Small finished-landmark pictures for the island, drawn once per style.
@MainActor
enum LandmarkMiniCache {
    private static var images: [BuildingStyle: LandmarkImage] = [:]
    private static var libraryArt: LandmarkImage?

    /// The Library building, drawn by the same painter as on the world map (3-tile footprint).
    static func library() -> LandmarkImage? {
        if let libraryArt { return libraryArt }
        libraryArt = LandmarkPainter.canvas(size: 3, scale: 2) { $0.libraryBuilding() }
        return libraryArt
    }

    static func image(_ style: BuildingStyle) -> LandmarkImage? {
        if let cached = images[style] { return cached }
        let look = LandmarkLook(style: style, stage: .complete, level: .base, size: 1, read: 1, total: 1)
        guard let image = LandmarkPainter.render(look, scale: 2) else { return nil }
        images[style] = image
        return image
    }
}

private extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
}

// MARK: - Placement engine

/// Decides where things go on the island. Reading fills tiles outward from the middle;
/// feature buildings (the Library, and any future ones) have reserved tiles near the centre
/// that reading never uses, so each building's spot is always free when it unlocks.
struct IslandPlacement {
    /// Reserved tile (index into the growth order) for each feature building.
    static let reserved: [Island.Feature: Int] = [.library: 1]

    private(set) var tileIndex = 0
    private var used = 0
    private var anyPlaced = false

    private static var reservedIndices: Set<Int> { Set(reserved.values) }

    /// Places a reading item in the next free quarter-spots.
    mutating func place(_ kind: Island.Kind, seed: Int, source: Island.Source) -> Island.Item {
        if anyPlaced, used + kind.weight > 4 { tileIndex += 1; used = 0 }
        while Self.reservedIndices.contains(tileIndex) { tileIndex += 1; used = 0 }
        anyPlaced = true
        let order = Island.tileOrderShared
        let tile = order[min(tileIndex, order.count - 1)]
        let spot = Island.spotCentre(start: used, weight: kind.weight)
        let jx = kind.weight == 1 ? (Island.unit(seed, 1) - 0.5) * 0.14 : 0
        let jy = kind.weight == 1 ? (Island.unit(seed, 2) - 0.5) * 0.14 : 0
        used += kind.weight
        let centre = CGPoint(x: CGFloat(tile.x) + spot.x, y: CGFloat(tile.y) + spot.y)
        return Island.Item(kind: kind, gx: centre.x + jx, gy: centre.y + jy, seed: seed, source: source,
                           footprint: Self.footprint(centre: centre, weight: kind.weight))
    }

    /// Places a feature building on its reserved tile.
    func place(_ feature: Island.Feature) -> Island.Item {
        let tile = Island.tileOrderShared[Self.reserved[feature] ?? 0]
        let centre = CGPoint(x: CGFloat(tile.x) + 0.5, y: CGFloat(tile.y) + 0.5)
        return Island.Item(kind: .library, gx: centre.x, gy: centre.y, seed: 0, source: .feature(feature),
                           footprint: Self.footprint(centre: centre, weight: 4))
    }

    /// Tiles shown: everything used, the reserved spots of unlocked features, and some open grass.
    func tiles(including features: Set<Island.Feature>) -> [Island.Tile] {
        let usedTiles = anyPlaced ? tileIndex + 1 : 0
        let featureTiles = features.compactMap { Self.reserved[$0] }.map { $0 + 1 }.max() ?? 0
        let count = min(Island.tileOrderShared.count, max(4, usedTiles + 2 + usedTiles / 5, featureTiles))
        return Array(Island.tileOrderShared.prefix(count))
    }

    /// Ground patch: a quarter tile for small things, half for medium, the whole tile for big ones.
    static func footprint(centre: CGPoint, weight: Int) -> CGRect {
        switch weight {
        case 4: return CGRect(x: centre.x - 0.5, y: centre.y - 0.5, width: 1, height: 1)
        case 2: return CGRect(x: centre.x - 0.5, y: centre.y - 0.25, width: 1, height: 0.5)
        default: return CGRect(x: centre.x - 0.25, y: centre.y - 0.25, width: 0.5, height: 0.5)
        }
    }
}
