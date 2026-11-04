import SwiftUI

// MARK: - Model

/// The home island. Every book you open gets a plot: its foundations go down in the middle,
/// and each chapter you read places an artifact around it (a story object where the chapter
/// has one, otherwise something from the book's theme). Finishing the book raises its
/// building; each full reread adds a floor. Rereading a chapter levels its artifact up to 5.
/// Passing the quiz raises a banner, and memorising the verse lights a lantern or grows a
/// fruit tree. Nothing already placed ever moves: plots are laid out in the order books were
/// opened, and each chapter has its own fixed spot in its plot.
struct Island: Equatable {
    struct Tile: Hashable { let x: Int; let y: Int }

    enum Kind: Hashable {
        /// A book's building (by book id).
        case building(String)
        /// A chapter's artifact.
        case artifact(ArtifactKind)
        /// A story object (a `ChapterLandmark` id).
        case story(String)
        /// A quiz banner, or a verse's lantern or fruit tree.
        case reward(RewardKind)
        /// A feature building: appears after the first journal entry.
        case library

        /// How much of a tile it takes up (4 = a whole tile).
        var weight: Int {
            switch self {
            case .building, .library: 4
            case .story: 2
            default: 1
            }
        }

        /// Tall things are redrawn in front of the character when it walks behind them.
        var isTall: Bool {
            switch self {
            case .artifact(let kind): ![.bush, .flowers, .sheep, .scroll, .jar, .fishBasket].contains(kind)
            default: true
            }
        }
    }

    /// What put an item on the island, so tapping it can explain itself.
    enum Source: Equatable {
        case chapter(book: String, chapter: Int)
        case story(id: String, book: String)
        case quiz(book: String)
        case verse(book: String)
        /// A book's building.
        case book(String)
        case feature(Feature)

        var bookID: String? {
            switch self {
            case .chapter(let b, _), .quiz(let b), .verse(let b), .book(let b), .story(_, let b): b
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
        /// For a book's building: distinct chapters read, out of the book's chapters.
        var progress = 0
        var total = 0
        /// Artifacts and story objects: level 1–5 (one per read). Buildings: how many times
        /// the whole book has been read (0 until finished; each one after the first adds a floor).
        var level = 0
    }

    /// A book's plot of land (size × size tiles from x, y).
    struct Plot: Equatable {
        let bookID: String
        let x: Int, y: Int, size: Int
        var centre: CGPoint { CGPoint(x: CGFloat(x) + CGFloat(size) / 2, y: CGFloat(y) + CGFloat(size) / 2) }
    }

    let tiles: [Tile]
    let items: [Item]
    var plots: [Plot] = []

    static let empty = Island.build(chapters: [], quizzes: [], verses: [])

    /// Index of the feature building's item, if it's on the island.
    func index(of feature: Feature) -> Int? {
        items.firstIndex { $0.source == .feature(feature) }
    }

    // MARK: Building

    private static var memo: (key: Int, island: Island)?

    /// - Parameters:
    ///   - chapters: every read.
    ///   - started: books opened (their foundations go down even before a chapter is read).
    ///   - quizzes: first pass of each book's quiz.
    ///   - verses: memorised verses.
    static func build(chapters: [(book: String, chapter: Int, date: Date)],
                      started: [(book: String, date: Date)] = [],
                      quizzes: [(book: String, date: Date)],
                      verses: [(book: String, date: Date)],
                      features: Set<Feature> = []) -> Island {
        var hasher = Hasher()
        for r in chapters { hasher.combine(r.book); hasher.combine(r.chapter); hasher.combine(r.date) }
        hasher.combine(-1)
        for s in started { hasher.combine(s.book); hasher.combine(s.date) }
        hasher.combine(-2)
        for q in quizzes { hasher.combine(q.book); hasher.combine(q.date) }
        hasher.combine(-3)
        for v in verses { hasher.combine(v.book); hasher.combine(v.date) }
        hasher.combine(features.map(\.rawValue).sorted())
        let key = hasher.finalize()
        if let memo, memo.key == key { return memo.island }
        let island = make(chapters: chapters, started: started, quizzes: quizzes, verses: verses, features: features)
        memo = (key, island)
        return island
    }

    private static func make(chapters: [(book: String, chapter: Int, date: Date)],
                             started: [(book: String, date: Date)],
                             quizzes: [(book: String, date: Date)],
                             verses: [(book: String, date: Date)],
                             features: Set<Feature>) -> Island {
        // Each book's plot goes down when the book was opened (or first read).
        var startDate: [String: Date] = [:]
        var reads: [String: [Int: (count: Int, first: Date)]] = [:]
        for read in chapters {
            guard let book = BibleCatalog.book(id: read.book), book.chapterNumbers.contains(read.chapter) else { continue }
            startDate[read.book] = min(startDate[read.book] ?? read.date, read.date)
            let old = reads[read.book]?[read.chapter]
            reads[read.book, default: [:]][read.chapter] = ((old?.count ?? 0) + 1, min(old?.first ?? read.date, read.date))
        }
        for start in started where BibleCatalog.book(id: start.book) != nil {
            startDate[start.book] = min(startDate[start.book] ?? start.date, start.date)
        }
        let quizDate = Dictionary(quizzes.map { ($0.book, $0.date) }, uniquingKeysWith: min)
        let verseDate = Dictionary(verses.map { ($0.book, $0.date) }, uniquingKeysWith: min)
        let order = Dictionary(uniqueKeysWithValues: BibleCatalog.books.enumerated().map { ($1.id, $0) })
        let books = startDate.keys.sorted { (startDate[$0]!, order[$0] ?? 0) < (startDate[$1]!, order[$1] ?? 0) }

        var packer = IslandPlots()
        var plots: [Plot] = []
        var dated: [(date: Date, rank: Int, item: Item)] = []
        for bookID in books {
            guard let book = BibleCatalog.book(id: bookID) else { continue }
            let spec = BuildingData.spec(for: bookID)
            let plot = packer.place(bookID, size: IslandPlots.size(chapters: book.chapterCount))
            plots.append(plot)
            let slots = IslandPlots.slots(in: plot)
            let bookReads = reads[bookID] ?? [:]
            let start = startDate[bookID]!

            // The building, in the middle.
            let centre = plot.centre
            var building = Item(kind: .building(bookID), gx: centre.x, gy: centre.y, seed: hash(bookID), source: .book(bookID),
                                footprint: CGRect(x: centre.x - 0.5, y: centre.y - 0.5, width: 1, height: 1))
            building.progress = bookReads.count
            building.total = book.chapterCount
            building.level = bookReads.count == book.chapterCount ? (bookReads.values.map(\.count).min() ?? 0) : 0
            dated.append((start, 0, building))

            func item(_ kind: Kind, slot: Int, source: Source, level: Int = 0, salt: String) -> Item {
                let p = slots[min(slot, slots.count - 1)]
                return Item(kind: kind, gx: p.x, gy: p.y, seed: hash("\(bookID)-\(salt)"), source: source,
                            footprint: CGRect(x: p.x - 0.18, y: p.y - 0.18, width: 0.36, height: 0.36), level: level)
            }
            if let date = quizDate[bookID] {
                dated.append((date, 1, item(.reward(RewardData.quiz), slot: RewardData.quizSlot, source: .quiz(book: bookID), salt: "quiz")))
            }
            if let date = verseDate[bookID] {
                dated.append((date, 2, item(.reward(RewardData.verse(for: bookID)), slot: RewardData.verseSlot,
                                            source: .verse(book: bookID), salt: "verse")))
            }
            // Story objects take the spot of their first chapter, once any of their chapters is read.
            var storyStarts: Set<Int> = []
            for entry in ChapterLandmarks.visible where entry.bookID == bookID {
                let inRange = entry.chapters.compactMap { ch in bookReads[ch] }
                guard let first = inRange.map(\.first).min() else { continue }
                storyStarts.insert(entry.chapters.lowerBound)
                let level = min(5, inRange.map(\.count).max() ?? 1)
                dated.append((first, 3, item(.story(entry.id), slot: RewardData.firstChapterSlot + entry.chapters.lowerBound - 1,
                                             source: .story(id: entry.id, book: bookID), level: level, salt: entry.id)))
            }
            for (chapter, read) in bookReads where !storyStarts.contains(chapter) {
                let kind = spec.theme[(chapter - 1) % spec.theme.count]
                dated.append((read.first, 4 + chapter, item(.artifact(kind), slot: RewardData.firstChapterSlot + chapter - 1,
                                                            source: .chapter(book: bookID, chapter: chapter),
                                                            level: min(5, read.count), salt: "ch\(chapter)")))
            }
        }
        var items = dated.sorted { ($0.date, $0.rank, $0.item.gx + $0.item.gy) < ($1.date, $1.rank, $1.item.gx + $1.item.gy) }.map(\.item)
        // Feature buildings take their reserved spots near the start (added last, so they build in).
        for feature in Feature.allCases where features.contains(feature) {
            items.append(IslandPlots.item(for: feature))
        }
        return Island(tiles: packer.tiles(features: features), items: items, plots: plots)
    }

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
            HitCandidate(id: i, depth: item.gx + item.gy, onGround: item.footprint.contains(g),
                         bounds: IslandPainter.drawnBounds(of: item, layout: layout))
        }
    }

    /// The drawn shape of code-drawn things, in view points (sizes match the painters).
    static func shape(of item: Island.Item, base: CGPoint, u: CGFloat) -> CGRect {
        switch item.kind {
        case .building(let bookID):
            let spec = BuildingData.spec(for: bookID)
            let built = item.total > 0 && item.progress >= item.total
            let half = BuildingArt.halfSpan(spec) * 44 * u
            let h = BuildingArt.height(spec, built: built, extraFloors: max(0, item.level - 1)) * u
            return CGRect(x: base.x - half, y: base.y - h, width: 2 * half, height: h + half * 0.5)
        case .artifact(let kind):
            return rect(ArtifactArt.size(kind), base: base, u: u)
        case .reward(let kind):
            return rect(RewardArt.size(kind), base: base, u: u)
        case .story, .library:
            return rect(CGSize(width: 40, height: 50), base: base, u: u)
        }
    }

    private static func rect(_ size: CGSize, base: CGPoint, u: CGFloat) -> CGRect {
        CGRect(x: base.x - size.width / 2 * u, y: base.y - size.height * u, width: size.width * u, height: size.height * u + 2 * u)
    }
}

// MARK: - Drawing

enum IslandPainter {
    /// The ground: sand on two soft layers of earth, with a warmer courtyard for each book's plot.
    static func drawTiles(_ c: inout GraphicsContext, island: Island, layout: IslandLayout) {
        let set = Set(island.tiles)
        func corners(_ t: Island.Tile) -> [CGPoint] {
            [layout.point(CGFloat(t.x), CGFloat(t.y)), layout.point(CGFloat(t.x + 1), CGFloat(t.y)),
             layout.point(CGFloat(t.x + 1), CGFloat(t.y + 1)), layout.point(CGFloat(t.x), CGFloat(t.y + 1))]
        }
        let round = StrokeStyle(lineWidth: layout.u * 3, lineJoin: .round)
        let shadow = Path { p in
            for t in island.tiles {
                p.addLines(corners(t).map { CGPoint(x: $0.x, y: $0.y + layout.depth * 2.2) }); p.closeSubpath()
            }
        }
        c.fill(shadow, with: .color(Earthy.shadow.opacity(0.22)))

        // Earth sides where the edge is exposed: an upper and a lower layer, left lighter.
        let down = layout.depth, half = layout.depth * 0.42
        func side(_ a: CGPoint, _ b: CGPoint, top: Color, bottom: Color) {
            let upper = Path { $0.addLines([a, b, CGPoint(x: b.x, y: b.y + half), CGPoint(x: a.x, y: a.y + half)]); $0.closeSubpath() }
            let lower = Path { $0.addLines([CGPoint(x: a.x, y: a.y + half), CGPoint(x: b.x, y: b.y + half),
                                            CGPoint(x: b.x, y: b.y + down), CGPoint(x: a.x, y: a.y + down)]); $0.closeSubpath() }
            c.fill(lower, with: .color(bottom)); c.stroke(lower, with: .color(bottom), style: round)
            c.fill(upper, with: .color(top)); c.stroke(upper, with: .color(top), style: round)
        }
        for t in island.tiles.sorted(by: { ($0.x + $0.y, $0.x) < ($1.x + $1.y, $1.x) }) {
            let q = corners(t)
            if !set.contains(Island.Tile(x: t.x, y: t.y + 1)) { side(q[3], q[2], top: Earthy.strataLeftTop, bottom: Earthy.strataLeft) }
            if !set.contains(Island.Tile(x: t.x + 1, y: t.y)) { side(q[2], q[1], top: Earthy.strataRightTop, bottom: Earthy.strataRight) }
        }
        // The top, as one seamless sheet of sand.
        let top = Path { p in for t in island.tiles { p.addLines(corners(t)); p.closeSubpath() } }
        c.fill(top, with: .color(Earthy.ground))
        c.stroke(top, with: .color(Earthy.ground), style: round)

        // Each plot gets a soft, warmer courtyard.
        for plot in island.plots {
            let inset: CGFloat = 0.25
            let x0 = CGFloat(plot.x) + inset, y0 = CGFloat(plot.y) + inset
            let x1 = CGFloat(plot.x + plot.size) - inset, y1 = CGFloat(plot.y + plot.size) - inset
            let yard = Path { $0.addLines([layout.point(x0, y0), layout.point(x1, y0), layout.point(x1, y1), layout.point(x0, y1)]); $0.closeSubpath() }
            c.fill(yard, with: .color(Earthy.groundWarm.opacity(0.75)))
            c.stroke(yard, with: .color(Earthy.groundWarm.opacity(0.75)), style: StrokeStyle(lineWidth: layout.u * 14, lineJoin: .round))
        }
        // A few light patches, so the sand isn't flat.
        for t in island.tiles where Noise.hash(t.x, t.y, seed: 41) > 0.9 {
            let p = layout.point(CGFloat(t.x) + 0.5, CGFloat(t.y) + 0.5)
            let w = layout.u * (10 + 8 * Noise.hash(t.x, t.y, seed: 43))
            c.fill(Path(ellipseIn: CGRect(x: p.x - w, y: p.y - w * 0.32, width: 2 * w, height: w * 0.64)), with: .color(Earthy.groundLight))
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
        if let art = art(for: item) {
            c.draw(Image(decorative: art.image, scale: 2), in: imageRect(art, item: item, tileWidth: tileWidth))
            return
        }
        let pen = IsoPen(c: c, u: u)
        switch item.kind {
        case .building(let bookID):
            if let custom = ArtAssets.building(bookID, level: buildingLevel(item)) {
                drawCustom(&c, custom, tileWidth: tileWidth)
                return
            }
            BuildingArt.draw(pen, spec: BuildingData.spec(for: bookID), progress: item.progress, total: item.total,
                             extraFloors: max(0, item.level - 1), seed: item.seed)
        case .artifact(let kind):
            if let custom = ArtAssets.artifact(kind.rawValue, level: item.level) {
                drawCustom(&c, custom, tileWidth: tileWidth)
                return
            }
            ArtifactArt.draw(pen, kind, level: item.level, seed: item.seed)
        case .reward(let kind):
            RewardArt.draw(pen, kind, seed: item.seed)
        case .story, .library:
            break // drawn from an image above
        }
    }

    /// Art-swap level for a building: 0 foundations, 1 built, 2–4 built with extra floors.
    static func buildingLevel(_ item: Island.Item) -> Int {
        guard item.total > 0, item.progress >= item.total else { return 0 }
        return min(4, max(1, item.level))
    }

    /// Hand-made art, bottom-centre on the ground point, at `ArtAssets.pointsPerTile` per tile.
    private static func drawCustom(_ c: inout GraphicsContext, _ art: ArtAssets.Art, tileWidth: CGFloat) {
        let k = tileWidth / ArtAssets.pointsPerTile
        let w = art.size.width * k, h = art.size.height * k
        c.draw(Image(decorative: art.image, scale: 1), in: CGRect(x: -w / 2, y: -h, width: w, height: h))
    }

    /// The pre-drawn picture for image-based kinds (the Library and story objects).
    static func art(for item: Island.Item) -> LandmarkImage? {
        switch item.kind {
        case .library: LandmarkMiniCache.library()
        case .story(let id): ChapterLandmarks.entry(id: id).flatMap { LandmarkMiniCache.story($0, level: item.level) }
        default: nil
        }
    }

    /// Where an image-based item is drawn, relative to its ground point. Shared by drawing and tapping.
    static func imageRect(_ art: LandmarkImage, item: Island.Item, tileWidth: CGFloat) -> CGRect {
        let k: CGFloat
        switch item.kind {
        case .story(let id):
            // A story object is shown about one tile across, whatever its size on the world map.
            let size = CGFloat(ChapterLandmarks.entry(id: id)?.size ?? 1)
            k = tileWidth / Iso.tileWidth * 0.8 / size
        default:
            // The Library's picture covers a 3-tile footprint; it's shown on its 2 × 2 spot.
            k = tileWidth / Iso.tileWidth * 0.95 * 2 / 3
        }
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
    private static var stories: [ChapterObjectLook: LandmarkImage] = [:]
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

    /// A story object, drawn by the world map's painter (its depth grows with rereads).
    static func story(_ entry: ChapterLandmark, level: Int) -> LandmarkImage? {
        let look = ChapterObjectLook(kind: entry.kind, depth: max(1, min(5, level)), variant: entry.variant, size: entry.size)
        if let cached = stories[look] { return cached }
        guard let image = ChapterObjectPainter.render(look, scale: 2) else { return nil }
        stories[look] = image
        return image
    }
}

private extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
}

// MARK: - Plots

/// Lays out books' plots. The starting square sits at the origin, with the Library's spot
/// beside it; each new book's plot goes in the nearest free place, keeping a one-tile path
/// between plots. Plot sizes depend only on the book's length, so nothing ever moves.
struct IslandPlots {
    /// The starting square (2 × 2 tiles from the origin), where your character begins.
    static let start = (x: 0, y: 0, size: 2)
    /// The Library's spot, beside the starting square.
    static let library = (x: -3, y: 0, size: 2)

    private var core: Set<Island.Tile> = []
    private var regions: [(x: Int, y: Int, size: Int)] = []

    init() {
        for r in [Self.start, Self.library] { mark(r.x, r.y, r.size) }
    }

    /// Side of a book's plot (odd, so the building sits on the middle tile): big enough for
    /// every chapter (four spots a tile) plus the rewards.
    static func size(chapters: Int) -> Int {
        var s = 3
        while 4 * (s * s - 1) < chapters + RewardData.firstChapterSlot { s += 2 }
        return s
    }

    private static let candidates: [(dx: Int, dy: Int)] = {
        let r = 46
        var all: [(dx: Int, dy: Int, d: Double)] = []
        for dy in -r...r { for dx in -r...r { all.append((dx, dy, hypot(Double(dx), Double(dy)))) } }
        return all.sorted { ($0.d, $0.dy, $0.dx) < ($1.d, $1.dy, $1.dx) }.map { ($0.dx, $0.dy) }
    }()

    mutating func place(_ bookID: String, size: Int) -> Island.Plot {
        for c in Self.candidates {
            // Centre the plot on the candidate offset from the starting square's middle.
            let x = 1 + c.dx - size / 2, y = 1 + c.dy - size / 2
            if fits(x, y, size) {
                mark(x, y, size)
                regions.append((x, y, size))
                return Island.Plot(bookID: bookID, x: x, y: y, size: size)
            }
        }
        return Island.Plot(bookID: bookID, x: 60, y: 60, size: size) // never reached in practice
    }

    private func fits(_ x: Int, _ y: Int, _ size: Int) -> Bool {
        for ty in (y - 1)...(y + size) {
            for tx in (x - 1)...(x + size) where core.contains(Island.Tile(x: tx, y: ty)) { return false }
        }
        return true
    }

    private mutating func mark(_ x: Int, _ y: Int, _ size: Int) {
        for ty in y..<(y + size) { for tx in x..<(x + size) { core.insert(Island.Tile(x: tx, y: ty)) } }
    }

    /// Land: the starting square, every plot (and the Library's spot once it's built), each
    /// with a one-tile border so plots are joined by paths. The starting square comes first.
    func tiles(features: Set<Island.Feature>) -> [Island.Tile] {
        var shown = [Self.start] + regions
        if features.contains(.library) { shown.append(Self.library) }
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
                    if seen.insert(t).inserted { out.append(t) }
                }
            }
        }
        // Fill any water enclosed by land, so there are no holes.
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
                if !seen.contains(t), !outside.contains(t) { out.append(t) }
            }
        }
        return out
    }

    /// The spots in a plot, in the order they're used: nearest the building first, front first.
    /// Four spots a tile; the building's middle tile is left free.
    static func slots(in plot: Island.Plot) -> [CGPoint] {
        let mid = plot.size / 2
        let c = plot.centre
        var tiles: [(tx: Int, ty: Int, ring: Int, front: CGFloat, side: CGFloat)] = []
        for ty in 0..<plot.size {
            for tx in 0..<plot.size {
                guard tx != mid || ty != mid else { continue }
                let ring = max(abs(tx - mid), abs(ty - mid))
                let dx = CGFloat(plot.x + tx) + 0.5 - c.x, dy = CGFloat(plot.y + ty) + 0.5 - c.y
                tiles.append((plot.x + tx, plot.y + ty, ring, dx + dy, dx - dy))
            }
        }
        tiles.sort { ($0.ring, -$0.front, abs($0.side), $0.side) < ($1.ring, -$1.front, abs($1.side), $1.side) }
        let spots: [CGPoint] = [CGPoint(x: 0.72, y: 0.72), CGPoint(x: 0.28, y: 0.72), CGPoint(x: 0.72, y: 0.28), CGPoint(x: 0.28, y: 0.28)]
        return tiles.flatMap { t in spots.map { CGPoint(x: CGFloat(t.tx) + $0.x, y: CGFloat(t.ty) + $0.y) } }
    }

    static func item(for feature: Island.Feature) -> Island.Item {
        let r = Self.library
        let centre = CGPoint(x: CGFloat(r.x) + CGFloat(r.size) / 2, y: CGFloat(r.y) + CGFloat(r.size) / 2)
        return Island.Item(kind: .library, gx: centre.x, gy: centre.y, seed: 0, source: .feature(feature),
                           footprint: CGRect(x: centre.x - 0.95, y: centre.y - 0.95, width: 1.9, height: 1.9))
    }
}
