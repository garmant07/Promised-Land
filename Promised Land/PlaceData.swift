import Foundation

// Every book of the Bible owns ONE Place on the island: a small complex that grows with every
// chapter read. Reading the first chapter founds it; each chapter after that adds something
// (a new building, or more of something already there: a wider field, more homes, more
// boats); finishing the book completes it. Rereads make it richer (up to 5 levels) without
// adding land.
//
// Places, captions and their links to the text are content: each spec carries `reference`,
// `source` and `reviewed: false`. Most captions describe the illustration ("a barn is
// built"), not a historical claim; anything that does point to the text is listed in
// REVIEW.md. Art-swap names: `place_<book>_<piece>_<level>` (see ART_ASSETS.md).

/// The overall look of a Place, which also sets its produce and its villagers' routine.
nonisolated enum PlaceStyle: String, Sendable, CaseIterable {
    case garden, camp, courts, farmstead, musicGarden, wisdomHouse, harbour, fishingVillage
    case gatheringTown, coastTown, newJerusalem, fortress, city, palace, walledTown, watchtower
    case vineyard, oasis, mountain, shepherds, scrollHouse

    /// Water Places sit on the coast, beside a bay of open water.
    var isWaterside: Bool { [.harbour, .fishingVillage, .coastTown].contains(self) }

    /// What a complete Place produces on days you read.
    var produce: ProduceKind {
        switch self {
        case .harbour, .fishingVillage, .coastTown: .fish
        case .farmstead, .gatheringTown, .city: .bread
        case .vineyard: .grapes
        case .garden, .musicGarden, .newJerusalem: .fruit
        case .courts, .palace, .wisdomHouse, .scrollHouse, .watchtower: .oil
        case .camp, .shepherds, .mountain: .wool
        case .oasis: .figs
        case .fortress, .walledTown: .wheat
        }
    }
}

/// Little gifts a complete Place produces (see VillagerData / produce rules).
nonisolated enum ProduceKind: String, Sendable, CaseIterable, Codable {
    case fish, bread, wheat, grapes, oil, fruit, wool, figs

    var name: String {
        switch self {
        case .fish: "Fish"
        case .bread: "Bread"
        case .wheat: "Wheat"
        case .grapes: "Grapes"
        case .oil: "Olive oil"
        case .fruit: "Fruit"
        case .wool: "Wool"
        case .figs: "Figs"
        }
    }

    var symbol: String {
        switch self {
        case .fish: "fish.fill"
        case .bread: "birthday.cake.fill"
        case .wheat: "leaf.fill"
        case .grapes: "circle.grid.3x3.fill"
        case .oil: "drop.fill"
        case .fruit: "apple.logo"
        case .wool: "cloud.fill"
        case .figs: "circle.fill"
        }
    }
}

/// Something drawn in a Place. Growable kinds get fuller with every chapter they're given.
nonisolated enum PieceKind: String, Sendable, CaseIterable {
    // Growable
    case garden, field, orchard, grove, vineyard, tents, houses, terraces, flock, dock, stalls
    case wall, scrolls, lamps, river, flowers, cedars, palms, crowd
    // Built once
    case soil, tent, tabernacle, altar, basin, lampstand, courtFence, farmhouse, barn, threshingFloor
    case mill, oven, gate, well, hut, tower, palace, temple, house, upperRoom, fountain, pavilion
    case hall, lighthouse, pillar, marketHall, goldGate, ship, olivePress, winepress, meetingHouse
    case nets, hill, cave, throneSeat

    var isGrowable: Bool {
        switch self {
        case .garden, .field, .orchard, .grove, .vineyard, .tents, .houses, .terraces, .flock, .dock, .stalls,
             .wall, .scrolls, .lamps, .river, .flowers, .cedars, .palms, .crowd: true
        default: false
        }
    }
}

/// Where a piece stands inside its Place (a fraction of the footprint; front = lower on screen).
nonisolated enum Spot: String, Sendable, CaseIterable {
    case centre, back, front, left, right, backLeft, backRight, frontLeft, frontRight
    /// Beside the Place's bay (the front if it has none).
    case shore

    /// (x, y) as fractions of the footprint, before the Place is turned. Grid +x runs down to
    /// the right on screen and +y down to the left, so "front" is +x +y.
    var fraction: (x: Double, y: Double) {
        switch self {
        case .centre: (0.5, 0.5)
        case .back: (0.24, 0.24)
        case .front: (0.76, 0.76)
        case .right: (0.76, 0.24)
        case .left: (0.24, 0.76)
        case .backRight: (0.5, 0.2)
        case .backLeft: (0.2, 0.5)
        case .frontRight: (0.8, 0.5)
        case .frontLeft: (0.5, 0.8)
        case .shore: (0.78, 0.78)
        }
    }
}

nonisolated struct GrowthPiece: Sendable, Equatable {
    let kind: PieceKind
    let spot: Spot
    /// The share of the book's chapters read when it appears (0 = founding).
    let at: Double
    /// "the barn is built" (shown as "Ruth 2: the barn is built").
    let caption: String
    /// For growable pieces: what a step of growth looks like ("the wheat field grows").
    let growCaption: String?
    /// For growable pieces: how many steps of growth it can show.
    let cap: Int

    var isGrowable: Bool { kind.isGrowable }
}

struct PlaceSpec: Equatable, ReviewableContent {
    let bookID: String
    let name: String
    let style: PlaceStyle
    let pieces: [GrowthPiece]
    /// What rereads add (shown in the Place's card).
    let richness: String
    let reference: String
    let source: String
    var reviewed = false

    /// Side of the square footprint in tiles: longer books get more room.
    var size: Int {
        let n = BibleCatalog.book(id: bookID)?.chapterCount ?? 1
        return n <= 4 ? 3 : n <= 13 ? 4 : n <= 36 ? 5 : 6
    }

    var produce: ProduceKind { style.produce }
    var isWaterside: Bool { style.isWaterside }

    /// The art-swap image name for a piece at a richness level.
    func imageName(piece: Int, level: Int) -> String { "place_\(bookID)_\(pieces[piece].kind.rawValue)_\(level)" }
}

// MARK: - Growth

/// How far a Place has grown after `n` of its `N` chapters. Pure, so it's testable.
struct PlaceGrowth: Equatable {
    /// Growth per piece: nil = not yet built; 1 = just built; growable pieces count up to their cap.
    var pieces: [Int?]
    /// Extra flowers and greenery once every piece is full (a long book's last chapters).
    var flourish = 0
    /// What the latest step added (the piece index, or nil for flourish).
    var lastPieces: [Int] = []

    static let flourishCap = 60

    var isFounded: Bool { pieces.contains { $0 != nil } }

    /// The chapter step (1…N) at which each piece appears.
    static func thresholds(_ spec: PlaceSpec, chapters total: Int) -> [Int] {
        let count = spec.pieces.count
        var out: [Int] = []
        for (i, piece) in spec.pieces.enumerated() {
            var t = max(1, min(total, Int((piece.at * Double(total)).rounded(.up))))
            if i == 0 { t = 1 }
            if let last = out.last {
                // Keep pieces apart when there are enough chapters; otherwise they share steps.
                t = total >= count ? max(t, last + 1) : max(t, last)
            }
            out.append(t)
        }
        if total >= count {
            // Pull back any that ran past the last chapter, keeping them one step apart.
            for i in stride(from: count - 1, through: 0, by: -1) {
                out[i] = min(out[i], total - (count - 1 - i))
            }
        }
        return out
    }

    /// The Place after `n` distinct chapters have been read.
    static func after(_ n: Int, spec: PlaceSpec, chapters total: Int) -> PlaceGrowth {
        var state = PlaceGrowth(pieces: Array(repeating: nil, count: spec.pieces.count))
        guard n > 0 else { return state }
        let t = thresholds(spec, chapters: total)
        for step in 1...min(n, total) {
            state.lastPieces = []
            let arriving = t.indices.filter { t[$0] == step }
            if !arriving.isEmpty {
                for i in arriving { state.pieces[i] = 1 }
                state.lastPieces = arriving
                continue
            }
            // No new piece: the newest growable piece with room grows a step.
            let grower = state.pieces.indices.reversed().first { i in
                guard let g = state.pieces[i], spec.pieces[i].isGrowable else { return false }
                return g < spec.pieces[i].cap
            }
            if let grower {
                state.pieces[grower]! += 1
                state.lastPieces = [grower]
            } else {
                state.flourish += 1
            }
        }
        return state
    }

    /// Rereads: 1 for a first read-through, rising with every full reread's worth, up to 5.
    static func richness(totalReads: Int, chapters: Int) -> Int {
        guard totalReads > 0 else { return 0 }
        return min(5, max(1, totalReads / max(1, chapters)))
    }
}

// MARK: - The 66 Places

enum PlaceData {
    static func spec(for bookID: String) -> PlaceSpec {
        byID[bookID] ?? PlaceSpec(bookID: bookID, name: BibleCatalog.book(id: bookID)?.name ?? bookID, style: .city,
                                  pieces: [s(.house, .centre, 0, "a house is built"), g(.houses, .left, 0.3, "neighbours move in", "another home is built")],
                                  richness: "", reference: bookID, source: "Design")
    }

    static var all: [PlaceSpec] { BibleCatalog.books.map { spec(for: $0.id) } }

    private static let byID: [String: PlaceSpec] = Dictionary(uniqueKeysWithValues: specs.map { ($0.bookID, $0) })

    // Builders: a piece built once, and a piece that grows.
    private static func s(_ kind: PieceKind, _ spot: Spot, _ at: Double, _ caption: String) -> GrowthPiece {
        GrowthPiece(kind: kind, spot: spot, at: at, caption: caption, growCaption: nil, cap: 1)
    }

    private static func g(_ kind: PieceKind, _ spot: Spot, _ at: Double, _ caption: String, _ grow: String, cap: Int = 14) -> GrowthPiece {
        GrowthPiece(kind: kind, spot: spot, at: at, caption: caption, growCaption: grow, cap: cap)
    }

    private static func p(_ id: String, _ name: String, _ style: PlaceStyle, _ richness: String, _ pieces: [GrowthPiece]) -> PlaceSpec {
        let book = BibleCatalog.book(id: id)
        let ref = book.map { $0.chapterCount == 1 ? "\($0.name) 1" : "\($0.name) 1–\($0.chapterCount)" } ?? id
        return PlaceSpec(bookID: id, name: name, style: style, pieces: pieces, richness: richness, reference: ref,
                         source: "An illustration of \(book?.name ?? id) (ASV); the buildings are design choices")
    }

    /// A fishing village by the water (the Gospels).
    private static func village(_ id: String, _ name: String, middle: GrowthPiece) -> PlaceSpec {
        p(id, name, .fishingVillage, "More families move in, children play by the water and a little market opens.", [
            s(.hut, .centre, 0, "a fishing hut stands by the water"),
            g(.dock, .shore, 0.08, "a jetty reaches into the water", "another boat ties up at the jetty", cap: 12),
            s(.nets, .back, 0.2, "nets are hung out to dry"),
            g(.houses, .left, 0.3, "homes go up along the shore", "another family builds a home", cap: 12),
            middle,
            g(.stalls, .right, 0.62, "a little market opens", "another stall opens in the market", cap: 10),
            s(.well, .frontLeft, 0.8, "a well is dug for the village"),
            s(.meetingHouse, .backLeft, 0.95, "a meeting house is raised at the village's heart"),
        ])
    }

    /// A small town on the coast road (the letters).
    private static func coastTown(_ id: String, _ name: String, _ first: PieceKind, _ firstCaption: String,
                                  _ landmark: PieceKind, _ landmarkCaption: String) -> PlaceSpec {
        p(id, name, .coastTown, "Lamps along the road, more homes and a busier quay.", [
            s(first, .centre, 0, firstCaption),
            g(.houses, .left, 0.15, "homes line the coast road", "another home is built", cap: 10),
            g(.dock, .shore, 0.35, "a small quay is built", "another boat comes in", cap: 8),
            landmark.isGrowable ? g(landmark, .back, 0.55, landmarkCaption, "it grows a little more", cap: 6)
                : s(landmark, .back, 0.55, landmarkCaption),
            g(.lamps, .right, 0.75, "lamps are lit along the road", "another lamp is lit", cap: 8),
            s(.well, .frontRight, 1.0, "a well is dug in the square"),
        ])
    }

    static let specs: [PlaceSpec] = [
        // MARK: Law
        p("genesis", "The Garden", .garden, "Fuller fruit trees, more flowers and birds in the branches.", [
            s(.soil, .centre, 0, "bare soil is turned"),
            g(.garden, .centre, 0.02, "the first green shoots appear", "the garden fills in", cap: 14),
            g(.flowers, .back, 0.08, "flowers bloom", "more flowers bloom", cap: 10),
            g(.orchard, .right, 0.14, "fruit trees are planted", "another fruit tree grows", cap: 10),
            s(.river, .backLeft, 0.2, "a river runs through the garden"),
            g(.grove, .left, 0.3, "a grove of trees grows", "the grove spreads", cap: 8),
            g(.tents, .frontLeft, 0.5, "tents are pitched at the garden's edge", "another tent is pitched", cap: 8),
            s(.well, .frontRight, 0.7, "a well is dug"),
            g(.flock, .front, 0.8, "flocks graze nearby", "the flock grows", cap: 10),
        ]),
        p("exodus", "The Camp", .camp, "More tents, banners over the tribes and cloud-white canopies.", [
            s(.tent, .centre, 0, "a single tent is pitched"),
            g(.tents, .left, 0.05, "the camp gathers around it", "the camp grows", cap: 14),
            s(.well, .frontLeft, 0.35, "a well gives water in the wilderness"),
            s(.pillar, .back, 0.5, "a stone pillar marks the mountain"),
            s(.courtFence, .right, 0.62, "the court's curtains are hung"),
            s(.tabernacle, .backRight, 0.7, "the tabernacle rises at the camp's centre"),
            g(.flock, .front, 0.85, "flocks graze around the camp", "the flock grows", cap: 8),
        ]),
        p("leviticus", "The Tabernacle Courts", .courts, "Brighter lamps, finer curtains and more people at the gate.", [
            s(.courtFence, .centre, 0, "the courts are marked out"),
            s(.altar, .front, 0.1, "the altar is built"),
            s(.basin, .frontRight, 0.25, "the basin is set in place"),
            s(.tabernacle, .back, 0.4, "the tent of meeting stands"),
            s(.lampstand, .backLeft, 0.55, "the lampstand is lit"),
            g(.lamps, .left, 0.65, "lamps line the courts", "another lamp is lit", cap: 8),
            g(.tents, .right, 0.8, "tents gather around the courts", "another tent is pitched", cap: 6),
        ]),
        p("numbers", "The Wilderness Camp", .camp, "Banners over every tribe, more flocks and fuller wells.", [
            s(.tent, .centre, 0, "a tent is pitched in the wilderness"),
            g(.tents, .back, 0.05, "the tribes camp around it", "another tent is pitched", cap: 14),
            g(.flock, .left, 0.25, "flocks graze", "the flock grows", cap: 12),
            s(.well, .frontLeft, 0.45, "a well is dug"),
            s(.tabernacle, .right, 0.6, "the tabernacle stands in the middle of the camp"),
            g(.palms, .front, 0.8, "palms grow at an oasis", "another palm grows", cap: 6),
        ]),
        p("deuteronomy", "The Mountain Overlook", .mountain, "Taller cedars, standing stones and a wider view.", [
            s(.hill, .centre, 0, "a hill rises"),
            s(.pillar, .front, 0.15, "a standing stone is set up"),
            g(.tents, .left, 0.25, "tents gather below the hill", "another tent is pitched", cap: 10),
            g(.scrolls, .right, 0.45, "the words are written down", "another scroll is written", cap: 8),
            g(.cedars, .back, 0.6, "cedars grow on the slopes", "another cedar grows", cap: 8),
            s(.altar, .frontRight, 0.85, "an altar of stones is built"),
        ]),
        // MARK: History
        p("joshua", "The Walled Town", .walledTown, "Stronger walls, more homes and fields beyond the gate.", [
            s(.tent, .centre, 0, "a camp is pitched by the river"),
            s(.pillar, .frontRight, 0.15, "twelve stones are set up"),
            g(.wall, .back, 0.3, "town walls rise", "the walls grow", cap: 10),
            g(.houses, .left, 0.45, "homes are built", "another home is built", cap: 10),
            s(.gate, .front, 0.65, "the town gate is built"),
            g(.field, .right, 0.8, "fields are sown in the new land", "the fields spread", cap: 8),
        ]),
        p("judges", "The Hill Country Village", .shepherds, "Fuller fields, a busier threshing floor and more homes.", [
            s(.house, .centre, 0, "a house stands in the hills"),
            g(.field, .left, 0.1, "a field is sown", "the field spreads", cap: 10),
            s(.threshingFloor, .back, 0.3, "a threshing floor is laid"),
            g(.houses, .right, 0.4, "neighbours build homes", "another home is built", cap: 10),
            s(.winepress, .frontLeft, 0.6, "a winepress is cut in the rock"),
            g(.palms, .front, 0.75, "palm trees grow", "another palm grows", cap: 6),
        ]),
        p("ruth", "The Farmstead", .farmstead, "A golden field, more sheaves, a bigger barn and gleaners in the rows.", [
            s(.farmhouse, .centre, 0, "a small farmhouse stands"),
            g(.field, .left, 0.2, "a wheat patch is sown", "the wheat field grows golden", cap: 10),
            s(.barn, .back, 0.4, "the barn is built"),
            s(.threshingFloor, .right, 0.6, "the threshing floor is laid"),
            s(.mill, .frontRight, 0.75, "a mill and oven are built"),
            s(.gate, .front, 1.0, "the town gate rises"),
        ]),
        p("1samuel", "The Shepherd's Hill", .shepherds, "Bigger flocks, a taller watchtower and music by the fold.", [
            s(.hut, .centre, 0, "a shepherd's hut stands on the hill"),
            g(.flock, .left, 0.05, "sheep graze", "the flock grows", cap: 14),
            s(.meetingHouse, .back, 0.2, "a house of prayer stands at Shiloh"),
            s(.well, .frontLeft, 0.4, "a well is dug"),
            s(.tower, .right, 0.55, "a watchtower is built"),
            g(.tents, .front, 0.7, "a camp gathers below", "another tent is pitched", cap: 8),
        ]),
        p("2samuel", "The City of David", .city, "Grander rooms, more homes and music in the palace.", [
            s(.palace, .centre, 0, "a palace is built"),
            g(.houses, .left, 0.1, "the city grows around it", "another home is built", cap: 12),
            g(.wall, .back, 0.3, "the city walls rise", "the walls grow", cap: 8),
            s(.pavilion, .right, 0.5, "a tent is pitched for the ark"),
            g(.cedars, .front, 0.7, "cedars are planted", "another cedar grows", cap: 6),
        ]),
        p("1kings", "The Temple Hill", .palace, "Gold on the temple, fuller courts and cedars on the hill.", [
            s(.palace, .left, 0, "a palace stands"),
            g(.cedars, .back, 0.08, "cedars are brought for building", "more cedars arrive", cap: 8),
            s(.temple, .centre, 0.25, "the temple rises"),
            s(.basin, .frontRight, 0.4, "a great basin is cast"),
            g(.houses, .right, 0.55, "the city fills in", "another home is built", cap: 10),
            g(.stalls, .front, 0.75, "traders bring their goods", "another stall opens", cap: 8),
        ]),
        p("2kings", "The Kings' City", .city, "More homes, a busier gate and fuller fields.", [
            s(.house, .centre, 0, "a house stands in the city"),
            g(.houses, .left, 0.08, "the city grows", "another home is built", cap: 12),
            s(.well, .frontLeft, 0.25, "a spring is found"),
            g(.wall, .back, 0.4, "walls are built", "the walls grow", cap: 10),
            s(.gate, .front, 0.6, "a city gate is built"),
            g(.field, .right, 0.8, "fields are sown", "the fields spread", cap: 8),
        ]),
        p("1chronicles", "The Hall of Records", .scrollHouse, "More scrolls, more singers and lamps in every window.", [
            s(.hall, .centre, 0, "a hall of records is built"),
            g(.scrolls, .left, 0.05, "the family lines are written down", "another scroll is written", cap: 14),
            s(.pavilion, .back, 0.5, "a tent is pitched for the ark"),
            g(.terraces, .right, 0.6, "singers gather with harps", "more singers join", cap: 8),
            g(.lamps, .front, 0.8, "lamps are lit", "another lamp is lit", cap: 6),
        ]),
        p("2chronicles", "The Temple City", .palace, "More worshippers, brighter lamps and stronger walls.", [
            s(.temple, .centre, 0, "the temple stands"),
            s(.altar, .front, 0.1, "a bronze altar is built"),
            g(.houses, .left, 0.2, "the city grows", "another home is built", cap: 12),
            g(.wall, .back, 0.45, "the walls rise", "the walls grow", cap: 10),
            g(.lamps, .right, 0.7, "lamps are lit", "another lamp is lit", cap: 8),
        ]),
        p("ezra", "The Rebuilt Temple", .courts, "Fuller courts, more homes and scrolls read aloud.", [
            s(.altar, .centre, 0, "the altar is rebuilt"),
            s(.temple, .back, 0.3, "the temple is rebuilt"),
            g(.houses, .left, 0.45, "families return home", "another family returns", cap: 6),
            g(.scrolls, .right, 0.7, "the law is read", "another scroll is read", cap: 5),
        ]),
        p("nehemiah", "The Rebuilt Walls", .walledTown, "Stronger walls, more homes and a busier gate.", [
            s(.gate, .front, 0, "a gate is repaired"),
            g(.wall, .centre, 0.08, "the walls are rebuilt", "another stretch of wall is rebuilt", cap: 10),
            g(.houses, .left, 0.5, "homes are built inside the walls", "another home is built", cap: 6),
            s(.tower, .right, 0.75, "a tower stands on the wall"),
        ]),
        p("esther", "The Palace Gardens", .palace, "Fuller gardens, banners and a glittering banquet hall.", [
            s(.palace, .centre, 0, "a palace rises"),
            g(.garden, .left, 0.1, "the palace gardens are laid out", "the gardens fill in", cap: 6),
            s(.pavilion, .back, 0.3, "a banquet tent is spread"),
            s(.gate, .front, 0.5, "the king's gate is built"),
            g(.lamps, .right, 0.7, "lamps are lit for the feast", "another lamp is lit", cap: 4),
        ]),
        // MARK: Poetry & wisdom
        p("job", "The Pasture", .shepherds, "Bigger flocks, more camels and a fuller tent.", [
            s(.tent, .centre, 0, "a tent stands in the land"),
            g(.flock, .left, 0.05, "flocks graze", "the flock grows", cap: 14),
            g(.field, .back, 0.3, "fields are ploughed", "the fields spread", cap: 10),
            s(.well, .frontLeft, 0.5, "a well is dug"),
            g(.tents, .right, 0.7, "more tents are pitched", "another tent is pitched", cap: 8),
            g(.flowers, .front, 0.9, "wildflowers bloom", "more wildflowers bloom", cap: 8),
        ]),
        p("psalms", "The Music Garden", .musicGarden, "More harps, more singers and terraces in full bloom.", [
            s(.pavilion, .centre, 0, "a music pavilion is raised"),
            g(.terraces, .back, 0.01, "a terrace of harps is built", "the harp terraces grow", cap: 24),
            g(.flowers, .left, 0.1, "flowers bloom", "more flowers bloom", cap: 20),
            s(.fountain, .front, 0.15, "a spring rises in the garden"),
            g(.garden, .right, 0.2, "the garden is planted", "the garden fills in", cap: 20),
            g(.orchard, .backLeft, 0.35, "fruit trees grow", "another fruit tree grows", cap: 16),
            g(.flock, .frontLeft, 0.5, "sheep graze in green pastures", "the flock grows", cap: 14),
            g(.lamps, .backRight, 0.65, "lamps light the paths", "another lamp is lit", cap: 14),
            g(.palms, .frontRight, 0.8, "palms grow beside the water", "another palm grows", cap: 12),
        ]),
        p("proverbs", "The House of Wisdom", .wisdomHouse, "More rooms, more scrolls and a fuller garden.", [
            s(.hall, .centre, 0, "the house of wisdom is built"),
            g(.scrolls, .left, 0.05, "scrolls fill the shelves", "another scroll is added", cap: 14),
            s(.well, .frontLeft, 0.3, "a well is dug in the courtyard"),
            g(.garden, .right, 0.4, "a garden is planted", "the garden fills in", cap: 10),
            g(.lamps, .back, 0.6, "lamps are lit in the windows", "another lamp is lit", cap: 6),
            g(.field, .front, 0.8, "fields are worked by diligent hands", "the fields spread", cap: 6),
        ]),
        p("ecclesiastes", "The Quiet Garden", .garden, "Fuller pools, more trees and shade to sit in.", [
            s(.fountain, .centre, 0, "a pool is dug"),
            g(.orchard, .left, 0.1, "fruit trees are planted", "another fruit tree grows", cap: 8),
            g(.vineyard, .back, 0.3, "vineyards are planted", "another row of vines", cap: 6),
            s(.house, .right, 0.6, "a house is built"),
            g(.flowers, .front, 0.8, "flowers bloom", "more flowers bloom", cap: 6),
        ]),
        p("songofsongs", "The Vineyard Garden", .vineyard, "Fuller vines, more blossoms and doves in the trees.", [
            s(.hut, .centre, 0, "a garden lodge is built"),
            g(.vineyard, .left, 0.12, "vines are planted", "another row of vines", cap: 6),
            g(.flowers, .back, 0.4, "blossoms appear", "more blossoms appear", cap: 6),
            g(.orchard, .right, 0.7, "fruit trees blossom", "another fruit tree grows", cap: 4),
        ]),
        // MARK: Prophets
        p("isaiah", "The Watchman's City", .city, "More homes, brighter lamps and gardens springing up.", [
            s(.tower, .centre, 0, "a watchman's tower is built"),
            g(.houses, .left, 0.02, "the city grows", "another home is built", cap: 14),
            g(.wall, .back, 0.2, "walls rise", "the walls grow", cap: 12),
            g(.vineyard, .right, 0.35, "a vineyard is planted on a hill", "another row of vines", cap: 10),
            g(.river, .backLeft, 0.55, "streams flow", "the streams spread", cap: 8),
            g(.flowers, .frontLeft, 0.65, "the desert blossoms", "more blossoms in the desert", cap: 10),
            g(.lamps, .front, 0.8, "lamps shine", "another lamp is lit", cap: 8),
        ]),
        p("jeremiah", "The Potter's Quarter", .city, "More homes, fuller fields and a busier workshop.", [
            s(.house, .centre, 0, "a potter's house is built"),
            g(.stalls, .left, 0.05, "pots line the workshop", "another pot is shaped", cap: 12),
            g(.houses, .back, 0.25, "the quarter fills with homes", "another home is built", cap: 12),
            g(.field, .right, 0.45, "a field is bought and sown", "the field spreads", cap: 10),
            g(.wall, .front, 0.65, "walls rise", "the walls grow", cap: 8),
        ]),
        p("lamentations", "The Mourning Wall", .walledTown, "Flowers among the stones and lamps of hope.", [
            s(.wall, .centre, 0, "a broken wall stands"),
            g(.flowers, .left, 0.2, "flowers grow among the stones", "more flowers grow", cap: 4),
            g(.lamps, .right, 0.6, "a lamp is lit", "another lamp is lit", cap: 3),
        ]),
        p("ezekiel", "The River Valley", .oasis, "Deeper river, more trees and fruit every month.", [
            s(.well, .centre, 0, "a spring rises"),
            g(.river, .back, 0.05, "a river begins to flow", "the river widens", cap: 12),
            g(.palms, .left, 0.25, "trees grow on its banks", "another tree grows", cap: 12),
            s(.temple, .right, 0.5, "a temple is measured out"),
            g(.orchard, .front, 0.7, "fruit trees line the river", "another fruit tree grows", cap: 10),
            g(.dock, .frontRight, 0.85, "fishers spread their nets by the river", "another fishing boat comes", cap: 6),
        ]),
        p("daniel", "The Royal Court", .palace, "Brighter lamps, a fuller garden and lions at rest.", [
            s(.palace, .centre, 0, "a royal palace stands"),
            g(.garden, .left, 0.15, "the court gardens grow", "the gardens fill in", cap: 6),
            s(.cave, .front, 0.5, "a den is dug"),
            g(.lamps, .right, 0.7, "lamps burn in an open window", "another lamp is lit", cap: 4),
        ]),
        p("hosea", "The Vineyard Valley", .vineyard, "Fuller vines, grain and olive trees.", [
            s(.house, .centre, 0, "a house is built in the valley"),
            g(.vineyard, .left, 0.1, "vines are planted", "another row of vines", cap: 8),
            g(.field, .back, 0.4, "grain grows", "the grain spreads", cap: 4),
            g(.grove, .right, 0.7, "olive trees grow", "another olive tree grows", cap: 4),
        ]),
        p("joel", "The Green Fields", .farmstead, "Fuller fields, vines and fig trees.", [
            s(.farmhouse, .centre, 0, "a farmhouse is rebuilt"),
            g(.field, .left, 0.3, "fields grow green again", "the fields spread", cap: 4),
            g(.vineyard, .right, 0.7, "vines and fig trees bear fruit", "another row of vines", cap: 4),
        ]),
        p("amos", "The Herdsman's Field", .shepherds, "Bigger flocks and fruit in the sycomore figs.", [
            s(.hut, .centre, 0, "a herdsman's hut is built"),
            g(.flock, .left, 0.1, "flocks graze", "the flock grows", cap: 6),
            g(.orchard, .back, 0.4, "fig trees grow", "another fig tree grows", cap: 4),
            s(.pillar, .right, 0.7, "a plumb line is held against a wall"),
        ]),
        p("obadiah", "The Rock", .mountain, "Flowers and a lamp on the rock.", [
            s(.hill, .centre, 0, "a high rock rises"),
            s(.cave, .left, 0, "homes are cut in the rock"),
            g(.flowers, .front, 0, "flowers grow below", "more flowers grow", cap: 3),
        ]),
        p("jonah", "The Harbour", .harbour, "More ships, a longer dock and a busier quay.", [
            s(.hut, .centre, 0, "a harbour house stands at Joppa"),
            g(.dock, .shore, 0.25, "the dock grows into the sea", "another ship comes in", cap: 6),
            s(.ship, .right, 0.5, "a ship sets sail"),
            s(.lighthouse, .back, 0.75, "a light is lit on the quay"),
        ]),
        p("micah", "The Little Town", .city, "More homes, vines and fig trees for everyone.", [
            s(.house, .centre, 0, "a little town begins"),
            g(.houses, .left, 0.15, "homes are built", "another home is built", cap: 4),
            g(.vineyard, .right, 0.45, "vines are planted", "another row of vines", cap: 3),
            g(.orchard, .back, 0.75, "fig trees grow", "another fig tree grows", cap: 3),
        ]),
        p("nahum", "The Watchtower", .watchtower, "A lamp on the tower and flowers at its foot.", [
            s(.tower, .centre, 0, "a watchtower is built"),
            g(.wall, .back, 0.3, "walls rise", "the walls grow", cap: 3),
            g(.flowers, .front, 0.7, "flowers grow on the mountains", "more flowers grow", cap: 3),
        ]),
        p("habakkuk", "The Rampart", .watchtower, "Fuller fig trees and vines, and a lamp on the rampart.", [
            s(.tower, .centre, 0, "a rampart is built to watch from"),
            g(.orchard, .left, 0.4, "fig trees grow", "another fig tree grows", cap: 3),
            g(.vineyard, .right, 0.7, "vines are planted", "another row of vines", cap: 3),
        ]),
        p("zephaniah", "The Gathering Square", .city, "More homes and songs in the square.", [
            s(.fountain, .centre, 0, "a square is laid out"),
            g(.houses, .left, 0.4, "people gather home", "another home is built", cap: 3),
            g(.lamps, .right, 0.7, "lamps are lit", "another lamp is lit", cap: 3),
        ]),
        p("haggai", "The Builders' Yard", .courts, "Fuller fields and a finer temple.", [
            s(.altar, .centre, 0, "the builders gather"),
            s(.temple, .back, 0.5, "the temple is rebuilt"),
            g(.field, .left, 0.5, "the fields are sown", "the fields spread", cap: 3),
        ]),
        p("zechariah", "The Lampstand Court", .courts, "Brighter lamps and fuller olive trees.", [
            s(.lampstand, .centre, 0, "a golden lampstand is lit"),
            g(.grove, .left, 0.1, "olive trees grow beside it", "another olive tree grows", cap: 8),
            g(.houses, .back, 0.3, "families return to the city", "another home is built", cap: 8),
            g(.wall, .right, 0.55, "the city grows", "the walls grow", cap: 6),
            g(.crowd, .front, 0.75, "children play in the streets", "more children play", cap: 6),
        ]),
        p("malachi", "The Storehouse", .farmstead, "Fuller barns and a brighter dawn.", [
            s(.barn, .centre, 0, "a storehouse is built"),
            g(.field, .left, 0.3, "fields are sown", "the fields spread", cap: 3),
            s(.altar, .back, 0.6, "an altar is rebuilt"),
            g(.flock, .right, 0.9, "calves leap in the stall", "the herd grows", cap: 3),
        ]),
        // MARK: Gospels & Acts
        village("matthew", "The Lakeside Village", middle: g(.crowd, .frontRight, 0.45, "a crowd gathers on the hillside", "the crowd grows", cap: 10)),
        village("mark", "The Fishers' Village", middle: s(.house, .frontRight, 0.45, "a house is opened to visitors")),
        village("luke", "The Shoreline Village", middle: g(.field, .frontRight, 0.45, "fields are sown above the village", "the fields spread", cap: 8)),
        village("john", "The Vine Village", middle: g(.vineyard, .frontRight, 0.45, "the vineyard is planted", "the vineyard grows another row", cap: 10)),
        p("acts", "The Upper Room Town", .gatheringTown, "More homes, a busier square and lamps in every window.", [
            s(.upperRoom, .centre, 0, "an upper room is built"),
            g(.crowd, .front, 0.05, "people gather", "more people gather", cap: 12),
            g(.houses, .left, 0.2, "homes open around it", "another home opens", cap: 12),
            g(.stalls, .right, 0.4, "a market square grows", "another stall opens", cap: 8),
            g(.dock, .frontRight, 0.6, "a road leads to the sea", "another ship sets out", cap: 8),
            s(.meetingHouse, .back, 0.8, "a meeting hall is built"),
        ]),
        // MARK: Letters
        coastTown("romans", "Roman Road Town", .hall, "a hall is built on the road", .marketHall, "a busy market hall opens"),
        coastTown("1corinthians", "Corinth Quay", .meetingHouse, "a meeting house is built", .marketHall, "a market hall opens by the quay"),
        coastTown("2corinthians", "Corinth Harbour", .house, "a house is built by the sea", .lighthouse, "a light shines on the quay"),
        coastTown("galatians", "Hill Road Town", .house, "a house is built on the road", .field, "fields are sown"),
        coastTown("ephesians", "Ephesus Quay", .hall, "a hall is built", .lamps, "lamps line the street"),
        coastTown("philippians", "Riverside Town", .house, "a house is built by the river", .garden, "a riverside garden is planted"),
        coastTown("colossians", "Valley Town", .house, "a house is built", .orchard, "fruit trees grow"),
        coastTown("1thessalonians", "Thessalonica Quay", .meetingHouse, "a meeting house is built", .marketHall, "a market hall opens"),
        coastTown("2thessalonians", "Workshop Lane", .house, "a workshop is built", .stalls, "workshops line the lane"),
        coastTown("1timothy", "Teacher's Town", .meetingHouse, "a meeting house is built", .scrolls, "a shelf of scrolls is filled"),
        coastTown("2timothy", "Scroll Harbour", .house, "a house is built", .scrolls, "books and parchments are kept safe"),
        coastTown("titus", "Island Port", .house, "a house is built on the island", .grove, "olive trees grow"),
        coastTown("philemon", "The Welcome House", .house, "a welcoming house is built", .garden, "a guest room is made ready"),
        p("hebrews", "The Pilgrims' Hall", .scrollHouse, "Brighter lamps and more scrolls.", [
            s(.hall, .centre, 0, "a hall is built"),
            g(.scrolls, .left, 0.1, "scrolls fill the shelves", "another scroll is added", cap: 6),
            s(.altar, .front, 0.3, "an altar stands in the court"),
            g(.lamps, .right, 0.5, "lamps are lit", "another lamp is lit", cap: 6),
            g(.tents, .back, 0.75, "pilgrims' tents are pitched", "another tent is pitched", cap: 4),
        ]),
        p("james", "The Well Square", .oasis, "Fuller fields and a busier well.", [
            s(.well, .centre, 0, "a well is dug in the square"),
            g(.field, .left, 0.2, "fields are sown", "the fields spread", cap: 4),
            g(.houses, .right, 0.6, "homes are built", "another home is built", cap: 3),
            g(.orchard, .back, 0.8, "fig trees grow", "another fig tree grows", cap: 3),
        ]),
        coastTown("1peter", "Shepherd's Cove", .hut, "a shepherd's hut is built by the sea", .field, "pastures are fenced"),
        coastTown("2peter", "Lamp Point", .house, "a house is built on the point", .lighthouse, "a lamp shines in a dark place"),
        p("1john", "The Lamplit Houses", .gatheringTown, "Brighter lamps and more homes.", [
            s(.house, .centre, 0, "a house of welcome is built"),
            g(.lamps, .left, 0.2, "lamps are lit", "another lamp is lit", cap: 4),
            g(.houses, .right, 0.6, "neighbours move in", "another home is built", cap: 3),
            g(.crowd, .front, 0.9, "friends gather", "more friends gather", cap: 3),
        ]),
        p("2john", "The Lady's House", .gatheringTown, "Flowers at the door.", [
            s(.house, .centre, 0, "a house is built"),
            g(.flowers, .left, 0, "flowers bloom at the door", "more flowers bloom", cap: 2),
        ]),
        p("3john", "The Guest House", .gatheringTown, "Lamps for travellers.", [
            s(.house, .centre, 0, "a guest house is built"),
            g(.lamps, .left, 0, "a lamp is lit for travellers", "another lamp is lit", cap: 2),
        ]),
        p("jude", "The Lighthouse", .watchtower, "A brighter beam.", [
            s(.lighthouse, .centre, 0, "a lighthouse is built"),
            g(.flowers, .left, 0, "flowers grow at its foot", "more flowers grow", cap: 2),
        ]),
        p("revelation", "The New Jerusalem", .newJerusalem, "The city glows brighter, with more trees and golden light.", [
            s(.goldGate, .front, 0, "a gate of pearl appears"),
            g(.wall, .back, 0.05, "the city's walls rise", "the walls grow", cap: 8),
            s(.throneSeat, .centre, 0.2, "a throne stands at the city's heart"),
            g(.river, .left, 0.35, "a river of water of life flows", "the river grows", cap: 6),
            g(.orchard, .right, 0.5, "trees of life grow on its banks", "another tree grows", cap: 6),
            g(.houses, .backLeft, 0.65, "the city's dwellings shine", "another dwelling shines", cap: 6),
            g(.lamps, .frontRight, 0.85, "the city glows with light", "the light grows", cap: 4),
        ]),
    ]
}

// MARK: - The shared forest

/// A chapter where trees are part of the story. Reading any of them adds trees to the forest
/// that spreads around the island's edge. Content: unreviewed (see REVIEW.md).
struct ForestChapter: ReviewableContent, Equatable {
    let bookID: String
    let chapter: Int
    /// The tree in the text, e.g. "the tree of life".
    let tree: String
    let reference: String
    var source: String { "\(reference) (ASV)" }
    var reviewed = false
}

enum ForestData {
    static let chapters: [ForestChapter] = [
        ForestChapter(bookID: "genesis", chapter: 2, tree: "every tree pleasant to the sight, and the tree of life", reference: "Genesis 2:9"),
        ForestChapter(bookID: "genesis", chapter: 18, tree: "the oaks of Mamre", reference: "Genesis 18:1"),
        ForestChapter(bookID: "judges", chapter: 9, tree: "the trees that went forth to anoint a king", reference: "Judges 9:8"),
        ForestChapter(bookID: "1kings", chapter: 19, tree: "a juniper-tree", reference: "1 Kings 19:4"),
        ForestChapter(bookID: "psalms", chapter: 1, tree: "a tree planted by the streams of water", reference: "Psalm 1:3"),
        ForestChapter(bookID: "psalms", chapter: 52, tree: "a green olive-tree", reference: "Psalm 52:8"),
        ForestChapter(bookID: "psalms", chapter: 92, tree: "the palm-tree and the cedar in Lebanon", reference: "Psalm 92:12"),
        ForestChapter(bookID: "isaiah", chapter: 55, tree: "the trees of the field shall clap their hands", reference: "Isaiah 55:12"),
        ForestChapter(bookID: "isaiah", chapter: 61, tree: "trees of righteousness", reference: "Isaiah 61:3"),
        ForestChapter(bookID: "jeremiah", chapter: 17, tree: "a tree planted by the waters", reference: "Jeremiah 17:8"),
        ForestChapter(bookID: "ezekiel", chapter: 31, tree: "a cedar in Lebanon", reference: "Ezekiel 31:3"),
        ForestChapter(bookID: "ezekiel", chapter: 47, tree: "trees for food on the river's banks", reference: "Ezekiel 47:12"),
        ForestChapter(bookID: "daniel", chapter: 4, tree: "a tree in the midst of the earth", reference: "Daniel 4:10"),
        ForestChapter(bookID: "hosea", chapter: 14, tree: "his beauty shall be as the olive-tree", reference: "Hosea 14:6"),
        ForestChapter(bookID: "zechariah", chapter: 4, tree: "two olive-trees", reference: "Zechariah 4:3"),
        ForestChapter(bookID: "matthew", chapter: 7, tree: "every good tree bringeth forth good fruit", reference: "Matthew 7:17"),
        ForestChapter(bookID: "matthew", chapter: 13, tree: "a grain of mustard seed that becometh a tree", reference: "Matthew 13:31–32"),
        ForestChapter(bookID: "mark", chapter: 11, tree: "a fig tree afar off having leaves", reference: "Mark 11:13"),
        ForestChapter(bookID: "luke", chapter: 13, tree: "a fig tree planted in his vineyard", reference: "Luke 13:6"),
        ForestChapter(bookID: "luke", chapter: 19, tree: "a sycomore tree", reference: "Luke 19:4"),
        ForestChapter(bookID: "romans", chapter: 11, tree: "the olive tree", reference: "Romans 11:17"),
        ForestChapter(bookID: "revelation", chapter: 22, tree: "the tree of life", reference: "Revelation 22:2"),
    ]

    static func entry(_ bookID: String, _ chapter: Int) -> ForestChapter? {
        chapters.first { $0.bookID == bookID && $0.chapter == chapter }
    }

    /// Trees each forest chapter adds (a small cluster, so the forest visibly spreads).
    static let treesPerChapter = 3
}
