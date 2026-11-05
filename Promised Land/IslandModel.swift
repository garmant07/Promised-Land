import SwiftUI

// MARK: - Model

/// The home island. Every book you read founds ONE Place (see PlaceData.swift) that grows with
/// every chapter: new buildings, wider fields, more homes. Rereads make Places richer. Passing a
/// book's quiz raises a banner, and memorising its verse lights a lantern or grows a fruit tree.
/// Tree chapters across the Bible grow a shared forest. Places sit loosely around a central
/// plaza (the starting square and the Library), joined by dirt roads (see IslandPlacer).
/// Everything is worked out from the reading history, so the island never changes on its own.
struct Island: Equatable {
    struct Tile: Hashable { let x: Int; let y: Int }

    enum Kind: Hashable {
        /// One growth piece of a book's Place.
        case piece(PieceKind)
        /// Extra flowers and greenery in a Place whose pieces are all full.
        case flourish
        /// A quiz banner, or a verse's lantern or fruit tree.
        case reward(RewardKind)
        /// A tree in the shared forest.
        case tree
        /// The Library: the reading hub, always on the island.
        case library
        /// The throne room: appears at the far edge once the whole Bible is read.
        case throne
        /// A decoration you placed in edit mode.
        case extra(ExtraKind)

        /// Tall things are redrawn in front of a character walking behind them.
        var isTall: Bool {
            switch self {
            case .piece(let k): ![.soil, .garden, .field, .flowers, .flock, .river, .dock, .threshingFloor, .crowd, .nets].contains(k)
            case .flourish: false
            case .extra(let k): k.isTall
            default: true
            }
        }
    }

    /// What put an item on the island, so tapping it can explain itself.
    enum Source: Equatable {
        /// A piece of a book's Place (its index in the Place's spec).
        case place(book: String, piece: Int)
        case flourish(book: String)
        case quiz(book: String)
        case verse(book: String)
        /// A forest tree, grown by a tree chapter.
        case forest(book: String, chapter: Int)
        case feature(Feature)
        /// A placed extra (its stored id).
        case extra(String)

        var bookID: String? {
            switch self {
            case .place(let b, _), .flourish(let b), .quiz(let b), .verse(let b), .forest(let b, _): b
            case .feature, .extra: nil
            }
        }
    }

    /// Feature buildings: features unlock as buildings on the island.
    enum Feature: String, CaseIterable {
        case library, throne, forest
    }

    struct Item: Equatable {
        let kind: Kind
        let gx: CGFloat
        let gy: CGFloat
        let seed: Int
        var source: Source = .feature(.library)
        /// The patch of ground it stands on, in grid units (for hit testing).
        var footprint: CGRect = .zero
        /// For Place pieces: distinct chapters read of the book, out of its chapters.
        var progress = 0
        var total = 0
        /// Place pieces: the Place's richness (1–5, from rereads).
        var level = 0
        /// Quarter turns of its Place (set in edit mode).
        var turned = 0
        /// Growable pieces: how far grown (1…cap); flourish: how many flowers.
        var growth: CGFloat = 0
        var cap = 1
        /// The Place's side in tiles (art scales with it).
        var span: CGFloat = 3
        /// Which way the Place's bay lies (0 +y, 1 +x, 2 −y, 3 −x), for docks and boats.
        var facing = 1
    }

    /// A Place's square of land (size × size tiles from x, y).
    struct Plot: Equatable {
        /// A book id, or a feature key (`IslandPlacement.libraryKey`, `forestKey`).
        let bookID: String
        let x: Int, y: Int, size: Int
        var rotation = 0
        /// The side its bay of water is on (see `Item.facing`), for waterside Places.
        var bay: Int?
        var centre: CGPoint { CGPoint(x: CGFloat(x) + CGFloat(size) / 2, y: CGFloat(y) + CGFloat(size) / 2) }
        var rect: CGRect { CGRect(x: x, y: y, width: size, height: size) }
    }

    let tiles: [Tile]
    let items: [Item]
    var plots: [Plot] = []
    /// Bays of open water cut into the coast beside waterside Places.
    var water: Set<Tile> = []
    /// The Library's spot.
    var library: Plot?
    /// The forest's spot, once a tree chapter has been read.
    var forest: Plot?
    /// Dirt roads joining every Place, as runs of tiles.
    var roads: [[Tile]] = []
    /// Plots placed on top of (or too close to) another: only while editing.
    var conflicts: Set<String> = []
    /// Each Place's growth, by book (for reveals and cards).
    var growth: [String: PlaceGrowth] = [:]

    /// Every plot's current place (books, the Library and the forest), for edit mode.
    var placements: [String: IslandPlacement] {
        var out: [String: IslandPlacement] = [:]
        for p in allPlots { out[p.bookID] = IslandPlacement(x: p.x, y: p.y, rotation: p.rotation) }
        return out
    }

    /// Book Places plus the Library and forest.
    var allPlots: [Plot] { plots + [library, forest].compactMap { $0 } }

    static let empty = Island.build(chapters: [], quizzes: [], verses: [])

    /// Index of the feature building's item, if it's on the island.
    func index(of feature: Feature) -> Int? {
        items.firstIndex { $0.source == .feature(feature) }
    }

    /// The first (founding) item of a book's Place.
    func placeIndex(_ bookID: String) -> Int? {
        items.firstIndex { if case .place(bookID, _) = $0.source { true } else { false } }
    }

    // MARK: Building

    private static var memo: (key: Int, island: Island)?

    /// - Parameters:
    ///   - chapters: every read.
    ///   - started: books opened (kept for callers; a Place is founded by its first read chapter).
    ///   - quizzes: first pass of each book's quiz.
    ///   - verses: memorised verses.
    ///   - unchecked: reads still waiting for their reading check (they don't build yet).
    ///   - richnessOverride: DEBUG preview: show every Place at this richness.
    static func build(chapters: [(book: String, chapter: Int, date: Date)],
                      started: [(book: String, date: Date)] = [],
                      quizzes: [(book: String, date: Date)],
                      verses: [(book: String, date: Date)],
                      features: Set<Feature> = [],
                      placements: [String: IslandPlacement] = [:],
                      unchecked: [(book: String, chapter: Int)] = [],
                      extras: [PlacedExtraInfo] = [],
                      richnessOverride: Int? = nil) -> Island {
        var hasher = Hasher()
        for r in chapters { hasher.combine(r.book); hasher.combine(r.chapter); hasher.combine(r.date) }
        hasher.combine(-2)
        for q in quizzes { hasher.combine(q.book); hasher.combine(q.date) }
        hasher.combine(-3)
        for v in verses { hasher.combine(v.book); hasher.combine(v.date) }
        hasher.combine(features.map(\.rawValue).sorted())
        for (k, p) in placements.sorted(by: { $0.key < $1.key }) { hasher.combine(k); hasher.combine(p) }
        hasher.combine(-4)
        for u in unchecked { hasher.combine(u.book); hasher.combine(u.chapter) }
        hasher.combine(extras)
        hasher.combine(richnessOverride)
        let key = hasher.finalize()
        if let memo, memo.key == key { return memo.island }
        let island = make(chapters: chapters, quizzes: quizzes, verses: verses, features: features,
                          placements: placements, unchecked: unchecked, extras: extras, richnessOverride: richnessOverride)
        memo = (key, island)
        return island
    }

    private static func make(chapters: [(book: String, chapter: Int, date: Date)],
                             quizzes: [(book: String, date: Date)],
                             verses: [(book: String, date: Date)],
                             features: Set<Feature>,
                             placements: [String: IslandPlacement],
                             unchecked: [(book: String, chapter: Int)],
                             extras: [PlacedExtraInfo],
                             richnessOverride: Int?) -> Island {
        let reads = ReadTally(chapters: chapters, unchecked: unchecked)
        let quizDate = Dictionary(quizzes.map { ($0.book, $0.date) }, uniquingKeysWith: min)
        let verseDate = Dictionary(verses.map { ($0.book, $0.date) }, uniquingKeysWith: min)
        let forestReads = reads.forestChapters
        var keys = reads.booksInOrder
        // The forest is founded (and placed) when its first tree chapter is read.
        if let first = forestReads.first {
            let index = keys.firstIndex(of: first.bookID).map { $0 + 1 } ?? keys.count
            keys.insert(IslandPlacement.forestKey, at: min(index, keys.count))
        }

        var placer = IslandPlacer(placements: placements, keys: keys)
        var plots: [Plot] = []
        var items: [Item] = []
        var growths: [String: PlaceGrowth] = [:]
        var forestPlot: Plot?
        for key in keys {
            if key == IslandPlacement.forestKey {
                let plot = placer.place(key, size: IslandPlacer.forestSize, waterside: false, testament: .old)
                forestPlot = plot
                continue
            }
            guard let book = BibleCatalog.book(id: key) else { continue }
            let spec = PlaceData.spec(for: key)
            let plot = placer.place(key, size: spec.size, waterside: spec.isWaterside, testament: book.testament)
            plots.append(plot)
            let n = reads.distinct[key] ?? 0
            let growth = PlaceGrowth.after(n, spec: spec, chapters: book.chapterCount)
            growths[key] = growth
            let richness = richnessOverride ?? PlaceGrowth.richness(totalReads: reads.total[key] ?? 0, chapters: book.chapterCount)
            items += placeItems(spec, plot: plot, growth: growth, progress: n, total: book.chapterCount, richness: richness)
            let s = CGFloat(plot.size)
            if quizDate[key] != nil {
                items.append(rewardItem(.reward(RewardData.quiz), at: CGPoint(x: 0.1, y: 0.92), plot: plot, span: s,
                                        source: .quiz(book: key)))
            }
            if verseDate[key] != nil {
                items.append(rewardItem(.reward(RewardData.verse(for: key)), at: CGPoint(x: 0.92, y: 0.1), plot: plot, span: s,
                                        source: .verse(book: key)))
            }
        }
        if let forestPlot {
            items += forestItems(forestReads, plot: forestPlot)
        }
        var library: Plot?
        if features.contains(.library) {
            let plot = placer.libraryPlot
            library = plot
            // First in the list, so things added later are always at the end.
            items.insert(Self.featureItem(.library, at: plot), at: 0)
        }
        if features.contains(.throne) {
            let plot = placer.placeThrone()
            let c = plot.centre
            items.insert(Item(kind: .throne, gx: c.x, gy: c.y, seed: 1, source: .feature(.throne),
                              footprint: CGRect(x: c.x - 0.95, y: c.y - 0.95, width: 1.9, height: 1.9)), at: 0)
        }
        let tiles = placer.tiles(features: features)
        let land = Set(tiles)
        let roads = IslandRoads.route(plots: plots + (forestPlot.map { [$0] } ?? []), library: library, land: land,
                                      blocked: placer.blocked)
        for extra in extras {
            items.append(Item(kind: .extra(extra.kind), gx: extra.x, gy: extra.y, seed: hash(extra.id), source: .extra(extra.id),
                              footprint: CGRect(x: extra.x - 0.3, y: extra.y - 0.3, width: 0.6, height: 0.6), turned: extra.rotation))
        }
        return Island(tiles: tiles, items: items, plots: plots, water: placer.water, library: library, forest: forestPlot,
                      roads: roads, conflicts: placer.conflicts, growth: growths)
    }

    /// One Place on its own patch of land (for its inside page and share card).
    static func single(bookID: String, distinct: Int, totalReads: Int) -> Island {
        guard let book = BibleCatalog.book(id: bookID) else { return Island(tiles: [], items: []) }
        let spec = PlaceData.spec(for: bookID)
        let plot = Plot(bookID: bookID, x: 0, y: 0, size: spec.size, bay: spec.isWaterside ? 1 : nil)
        let growth = PlaceGrowth.after(distinct, spec: spec, chapters: book.chapterCount)
        let items = placeItems(spec, plot: plot, growth: growth, progress: distinct, total: book.chapterCount,
                               richness: PlaceGrowth.richness(totalReads: totalReads, chapters: book.chapterCount))
        var tiles: [Tile] = []
        var water: Set<Tile> = []
        for ty in -1...spec.size { for tx in -1...spec.size { tiles.append(Tile(x: tx, y: ty)) } }
        if spec.isWaterside { for t in IslandPlacer.bay(x: 0, y: 0, size: spec.size, side: 1) { water.insert(t) } }
        return Island(tiles: tiles, items: items, plots: [plot], water: water, growth: [bookID: growth])
    }

    /// Where a piece stands, as a grid point: its spot in the footprint, turned with the Place.
    static func position(_ spot: Spot, in plot: Plot) -> CGPoint {
        let s = CGFloat(plot.size)
        var f = spot.fraction
        if spot == .shore, let bay = plot.bay {
            // On the edge facing the bay, half a tile out (the dock reaches into the water).
            f = [(0.5, 1.0), (1.0, 0.5), (0.5, 0.0), (0.0, 0.5)][bay]
            let out: [(Double, Double)] = [(0, 0.5), (0.5, 0), (0, -0.5), (-0.5, 0)]
            return CGPoint(x: CGFloat(plot.x) + CGFloat(f.x) * s + CGFloat(out[bay].0),
                           y: CGFloat(plot.y) + CGFloat(f.y) * s + CGFloat(out[bay].1))
        }
        return turn(CGPoint(x: CGFloat(plot.x) + CGFloat(f.x) * s, y: CGFloat(plot.y) + CGFloat(f.y) * s), in: plot)
    }

    /// Turns a grid point about its plot's centre by the plot's quarter turns.
    static func turn(_ p: CGPoint, in plot: Plot) -> CGPoint {
        let c = plot.centre
        var d = CGPoint(x: p.x - c.x, y: p.y - c.y)
        for _ in 0..<(((plot.rotation % 4) + 4) % 4) { d = CGPoint(x: -d.y, y: d.x) }
        return CGPoint(x: c.x + d.x, y: c.y + d.y)
    }

    private static func placeItems(_ spec: PlaceSpec, plot: Plot, growth: PlaceGrowth, progress: Int, total: Int,
                                   richness: Int) -> [Item] {
        var out: [Item] = []
        let s = CGFloat(plot.size)
        for (i, piece) in spec.pieces.enumerated() {
            guard let g = growth.pieces[i] else { continue }
            let p = position(piece.spot, in: plot)
            let half = PlaceArt.groundRadius(piece.kind, span: s)
            var item = Item(kind: .piece(piece.kind), gx: p.x, gy: p.y, seed: hash("\(spec.bookID)-\(i)"),
                            source: .place(book: spec.bookID, piece: i),
                            footprint: CGRect(x: p.x - half, y: p.y - half, width: 2 * half, height: 2 * half),
                            progress: progress, total: total, level: max(1, richness), turned: plot.rotation)
            item.growth = CGFloat(g)
            item.cap = piece.cap
            item.span = s
            item.facing = plot.bay ?? 1
            out.append(item)
        }
        if growth.flourish > 0 {
            let c = plot.centre
            var item = Item(kind: .flourish, gx: c.x, gy: c.y, seed: hash("\(spec.bookID)-flourish"), source: .flourish(book: spec.bookID),
                            footprint: .zero, progress: progress, total: total, level: max(1, richness), turned: plot.rotation)
            item.growth = CGFloat(min(PlaceGrowth.flourishCap, growth.flourish))
            item.span = s
            out.append(item)
        }
        return out
    }

    private static func rewardItem(_ kind: Kind, at f: CGPoint, plot: Plot, span: CGFloat, source: Source) -> Item {
        let p = turn(CGPoint(x: CGFloat(plot.x) + f.x * span, y: CGFloat(plot.y) + f.y * span), in: plot)
        return Item(kind: kind, gx: p.x, gy: p.y, seed: hash("\(source)"), source: source,
                    footprint: CGRect(x: p.x - 0.2, y: p.y - 0.2, width: 0.4, height: 0.4), turned: plot.rotation)
    }

    /// Forest trees, spiralling out from the forest's middle as tree chapters are read.
    private static func forestItems(_ reads: [(bookID: String, chapter: Int)], plot: Plot) -> [Item] {
        var out: [Item] = []
        let c = plot.centre
        let radius = CGFloat(plot.size) / 2 - 0.35
        let capacity = ForestData.chapters.count * ForestData.treesPerChapter
        for (k, read) in reads.enumerated() {
            for j in 0..<ForestData.treesPerChapter {
                let n = k * ForestData.treesPerChapter + j
                let r = radius * sqrt((CGFloat(n) + 0.5) / CGFloat(capacity))
                let a = CGFloat(n) * 2.39996
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                out.append(Item(kind: .tree, gx: p.x, gy: p.y, seed: hash("tree-\(n)"),
                                source: .forest(book: read.bookID, chapter: read.chapter),
                                footprint: CGRect(x: p.x - 0.2, y: p.y - 0.2, width: 0.4, height: 0.4)))
            }
        }
        return out
    }

    static func featureItem(_ feature: Feature, at plot: Plot) -> Item {
        let centre = plot.centre
        return Item(kind: .library, gx: centre.x, gy: centre.y, seed: 0, source: .feature(feature),
                    footprint: CGRect(x: centre.x - 0.95, y: centre.y - 0.95, width: 1.9, height: 1.9), turned: plot.rotation)
    }

    static func hash(_ s: String) -> Int {
        Int(s.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 } & 0xFFFFFF)
    }

    static func unit(_ seed: Int, _ salt: Int) -> CGFloat {
        CGFloat(Noise.hash(seed, salt, seed: 5))
    }
}

/// Counts the reads that build Places: only checked reads count, and only real chapters.
struct ReadTally {
    /// Distinct checked chapters per book.
    var distinct: [String: Int] = [:]
    /// Every checked read per book (rereads included).
    var total: [String: Int] = [:]
    /// Books in the order their Place was founded (first checked read), canon order breaking ties.
    var booksInOrder: [String] = []
    /// Forest chapters read, in the order first read.
    var forestChapters: [(bookID: String, chapter: Int)] = []
    /// The date each Place was founded and the date it was completed (if it has been).
    var founded: [String: Date] = [:]
    var completed: [String: Date] = [:]

    init(chapters: [(book: String, chapter: Int, date: Date)], unchecked: [(book: String, chapter: Int)]) {
        var waiting: [String: Int] = [:]
        for u in unchecked { waiting["\(u.book)#\(u.chapter)", default: 0] += 1 }
        var seen: [String: Set<Int>] = [:]
        var forestSeen: Set<String> = []
        let order = Dictionary(uniqueKeysWithValues: BibleCatalog.books.enumerated().map { ($1.id, $0) })
        for read in chapters.sorted(by: { ($0.date, order[$0.book] ?? 0, $0.chapter) < ($1.date, order[$1.book] ?? 0, $1.chapter) }) {
            guard let book = BibleCatalog.book(id: read.book), book.chapterNumbers.contains(read.chapter) else { continue }
            let key = "\(read.book)#\(read.chapter)"
            // The newest reads of a chapter are the unchecked ones; skip that many from the end.
            if let w = waiting[key], w > 0, isAmongLatest(read, unchecked: w, in: chapters) { continue }
            total[read.book, default: 0] += 1
            if seen[read.book, default: []].insert(read.chapter).inserted {
                if founded[read.book] == nil { founded[read.book] = read.date; booksInOrder.append(read.book) }
                if seen[read.book]!.count == book.chapterCount { completed[read.book] = read.date }
            }
            if ForestData.entry(read.book, read.chapter) != nil, forestSeen.insert(key).inserted {
                forestChapters.append((read.book, read.chapter))
            }
        }
        distinct = seen.mapValues(\.count)
    }

    /// True if `read` is one of the `count` most recent reads of its chapter.
    private func isAmongLatest(_ read: (book: String, chapter: Int, date: Date), unchecked count: Int,
                               in all: [(book: String, chapter: Int, date: Date)]) -> Bool {
        let newer = all.filter { $0.book == read.book && $0.chapter == read.chapter && $0.date > read.date }.count
        return newer < count
    }
}
