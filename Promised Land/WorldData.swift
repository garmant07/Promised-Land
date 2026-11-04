import Foundation
import CoreGraphics

// The static layout of the world. Progress lives in SwiftData (Persistence.swift);
// this file never changes at runtime.
//
// Grid coordinates: x runs west → east, y runs north → south, 0...mapWidth/Height.
// The isometric projection puts north-west at the top of the screen.

// MARK: - Geometry

struct GridRect: Hashable {
    let x: Int, y: Int, w: Int, h: Int

    var center: CGPoint { CGPoint(x: Double(x) + Double(w) / 2, y: Double(y) + Double(h) / 2) }

    func contains(_ gx: Double, _ gy: Double) -> Bool {
        gx >= Double(x) && gx < Double(x + w) && gy >= Double(y) && gy < Double(y + h)
    }
}

// MARK: - Regions

struct Region: Identifiable, Hashable {
    let id: String
    let name: String
    let bounds: GridRect
    /// Ground tint (hex) blended into the terrain inside the region.
    let ground: String
}

// MARK: - Landmarks

enum BuildingStyle: String, CaseIterable {
    case garden, pyramid, tabernacle, tents, mountain, walls, village, field, palace,
         temple, tower, gate, harbour, house, outpost, portCity, hill, glowCity, well, vineyard
}

struct Landmark: Identifiable, Hashable {
    let bookID: String
    let name: String
    let regionID: String
    /// North-west corner of the footprint on the grid.
    let x: Int, y: Int
    /// Footprint is `size × size` tiles.
    let size: Int
    let style: BuildingStyle

    var id: String { bookID }
    var book: Book? { BibleCatalog.book(id: bookID) }
    var region: Region? { WorldData.region(id: regionID) }
    var footprint: GridRect { GridRect(x: x, y: y, w: size, h: size) }
    var center: CGPoint { footprint.center }
    var learning: BookLearning? { LearningData.forBook(bookID) }
    var characters: [WorldCharacter] { WorldData.characters.filter { $0.bookID == bookID } }
}

// MARK: - Connections

struct Connection: Identifiable, Hashable {
    let a: String
    let b: String
    let title: String
    let text: String
    var id: String { "\(a)-\(b)" }
}

// MARK: - Characters

struct WorldCharacter: Identifiable, Hashable {
    let id: String          // asset name is "char_<id>"
    let name: String
    let bookID: String
    let line: String
    let robe: String        // hex colour for the placeholder figure

    var imageName: String { "char_\(id)" }
}

// MARK: - Terrain features

struct Ellipse: Hashable {
    let cx: Double, cy: Double, rx: Double, ry: Double

    func contains(_ x: Double, _ y: Double, padding: Double = 0) -> Bool {
        let dx = (x - cx) / (rx + padding), dy = (y - cy) / (ry + padding)
        return dx * dx + dy * dy <= 1
    }
}

// MARK: - World

enum WorldData {
    static let mapWidth = 128
    static let mapHeight = 96

    static func region(id: String) -> Region? { regions.first { $0.id == id } }
    static func landmark(bookID: String) -> Landmark? { landmarksByBook[bookID] }
    private static let landmarksByBook = Dictionary(uniqueKeysWithValues: landmarks.map { ($0.bookID, $0) })

    // MARK: Regions

    static let regions: [Region] = [
        Region(id: "eden", name: "Eden & Beginnings", bounds: GridRect(x: 86, y: 4, w: 38, h: 22), ground: "#CBD49C"),
        Region(id: "egypt", name: "Egypt", bounds: GridRect(x: 30, y: 78, w: 28, h: 16), ground: "#F2DCA8"),
        Region(id: "wilderness", name: "The Wilderness", bounds: GridRect(x: 58, y: 62, w: 24, h: 32), ground: "#F1D6A6"),
        Region(id: "promised", name: "The Promised Land", bounds: GridRect(x: 34, y: 26, w: 24, h: 24), ground: "#DCDCA4"),
        Region(id: "kingdom", name: "Jerusalem & the Kingdom", bounds: GridRect(x: 58, y: 26, w: 18, h: 26), ground: "#F4DFB6"),
        Region(id: "prophets", name: "Hills of the Prophets", bounds: GridRect(x: 32, y: 50, w: 26, h: 28), ground: "#E6D6A6"),
        Region(id: "babylon", name: "Babylon & Persia", bounds: GridRect(x: 84, y: 28, w: 38, h: 54), ground: "#EFD3AA"),
        Region(id: "galilee", name: "Galilee", bounds: GridRect(x: 58, y: 2, w: 28, h: 22), ground: "#D3DBA8"),
        Region(id: "church", name: "Jerusalem of the Early Church", bounds: GridRect(x: 58, y: 52, w: 20, h: 10), ground: "#F3E0BC"),
        Region(id: "mediterranean", name: "Roads of the Mediterranean", bounds: GridRect(x: 4, y: 2, w: 54, h: 22), ground: "#E9DEB2"),
        Region(id: "patmos", name: "Patmos & the New Jerusalem", bounds: GridRect(x: 8, y: 32, w: 16, h: 16), ground: "#EFE6CC"),
    ]

    // MARK: Landmarks (all 66 books)

    static let landmarks: [Landmark] = [
        // Eden & Beginnings
        Landmark(bookID: "genesis", name: "Eden Garden", regionID: "eden", x: 100, y: 9, size: 8, style: .garden),
        // Egypt
        Landmark(bookID: "exodus", name: "Land of Goshen", regionID: "egypt", x: 46, y: 82, size: 6, style: .pyramid),
        // The Wilderness
        Landmark(bookID: "leviticus", name: "The Tabernacle", regionID: "wilderness", x: 60, y: 66, size: 5, style: .tabernacle),
        Landmark(bookID: "numbers", name: "Camp of the Tribes", regionID: "wilderness", x: 66, y: 77, size: 5, style: .tents),
        Landmark(bookID: "deuteronomy", name: "Mount Nebo", regionID: "wilderness", x: 73, y: 66, size: 5, style: .mountain),
        // The Promised Land
        Landmark(bookID: "joshua", name: "Walls of Jericho", regionID: "promised", x: 51, y: 30, size: 5, style: .walls),
        Landmark(bookID: "judges", name: "Deborah's Palm", regionID: "promised", x: 38, y: 43, size: 4, style: .village),
        Landmark(bookID: "ruth", name: "Fields of Bethlehem", regionID: "promised", x: 42, y: 32, size: 5, style: .field),
        // Jerusalem & the Kingdom
        Landmark(bookID: "1samuel", name: "David's Stronghold", regionID: "kingdom", x: 58, y: 29, size: 4, style: .tower),
        Landmark(bookID: "2samuel", name: "City of David", regionID: "kingdom", x: 64, y: 29, size: 4, style: .palace),
        Landmark(bookID: "1kings", name: "Solomon's Temple", regionID: "kingdom", x: 70, y: 29, size: 4, style: .temple),
        Landmark(bookID: "2kings", name: "Kings' Gate", regionID: "kingdom", x: 58, y: 35, size: 4, style: .gate),
        Landmark(bookID: "1chronicles", name: "House of Records", regionID: "kingdom", x: 64, y: 35, size: 4, style: .house),
        Landmark(bookID: "2chronicles", name: "Jerusalem Walls", regionID: "kingdom", x: 70, y: 35, size: 4, style: .walls),
        Landmark(bookID: "psalms", name: "Temple Courts", regionID: "kingdom", x: 58, y: 41, size: 4, style: .temple),
        Landmark(bookID: "proverbs", name: "House of Wisdom", regionID: "kingdom", x: 64, y: 41, size: 4, style: .house),
        Landmark(bookID: "ecclesiastes", name: "Preacher's Palace", regionID: "kingdom", x: 70, y: 41, size: 4, style: .palace),
        Landmark(bookID: "songofsongs", name: "Garden of Songs", regionID: "kingdom", x: 64, y: 47, size: 4, style: .garden),
        // Hills of the Prophets
        Landmark(bookID: "isaiah", name: "Watchman's Tower", regionID: "prophets", x: 35, y: 52, size: 3, style: .tower),
        Landmark(bookID: "jeremiah", name: "Potter's House", regionID: "prophets", x: 41, y: 52, size: 3, style: .house),
        Landmark(bookID: "lamentations", name: "Weeping Walls", regionID: "prophets", x: 47, y: 52, size: 3, style: .walls),
        Landmark(bookID: "ezekiel", name: "Ezekiel's Spring", regionID: "prophets", x: 53, y: 52, size: 3, style: .well),
        Landmark(bookID: "hosea", name: "Hosea's Vineyard", regionID: "prophets", x: 35, y: 58, size: 3, style: .vineyard),
        Landmark(bookID: "joel", name: "Valley Orchard", regionID: "prophets", x: 41, y: 58, size: 3, style: .garden),
        Landmark(bookID: "amos", name: "Shepherd's Fold", regionID: "prophets", x: 47, y: 58, size: 3, style: .tents),
        Landmark(bookID: "obadiah", name: "Rock of Edom", regionID: "prophets", x: 53, y: 58, size: 3, style: .hill),
        Landmark(bookID: "zephaniah", name: "Zephaniah's Gate", regionID: "prophets", x: 35, y: 64, size: 3, style: .gate),
        Landmark(bookID: "micah", name: "Moresheth Village", regionID: "prophets", x: 41, y: 64, size: 3, style: .village),
        Landmark(bookID: "nahum", name: "Nineveh Watch", regionID: "prophets", x: 47, y: 64, size: 3, style: .tower),
        Landmark(bookID: "habakkuk", name: "Habakkuk's Rampart", regionID: "prophets", x: 53, y: 64, size: 3, style: .walls),
        Landmark(bookID: "jonah", name: "Harbour at Joppa", regionID: "prophets", x: 34, y: 70, size: 3, style: .harbour),
        Landmark(bookID: "haggai", name: "Temple Stones", regionID: "prophets", x: 41, y: 70, size: 3, style: .temple),
        Landmark(bookID: "zechariah", name: "Lampstand Court", regionID: "prophets", x: 47, y: 70, size: 3, style: .palace),
        Landmark(bookID: "malachi", name: "Messenger's Well", regionID: "prophets", x: 53, y: 70, size: 3, style: .well),
        // Babylon & Persia
        Landmark(bookID: "daniel", name: "Babylon Gate", regionID: "babylon", x: 92, y: 38, size: 6, style: .gate),
        Landmark(bookID: "ezra", name: "Rebuilt Altar", regionID: "babylon", x: 94, y: 52, size: 4, style: .temple),
        Landmark(bookID: "nehemiah", name: "Rebuilt Walls", regionID: "babylon", x: 87, y: 60, size: 5, style: .walls),
        Landmark(bookID: "esther", name: "Persian Palace", regionID: "babylon", x: 104, y: 33, size: 6, style: .palace),
        Landmark(bookID: "job", name: "Desert Outpost of Uz", regionID: "babylon", x: 100, y: 72, size: 4, style: .outpost),
        // Galilee
        Landmark(bookID: "matthew", name: "Mount of Beatitudes", regionID: "galilee", x: 80, y: 5, size: 4, style: .hill),
        Landmark(bookID: "mark", name: "Capernaum", regionID: "galilee", x: 61, y: 18, size: 4, style: .house),
        Landmark(bookID: "luke", name: "Nazareth", regionID: "galilee", x: 60, y: 5, size: 4, style: .village),
        Landmark(bookID: "john", name: "Sea of Galilee", regionID: "galilee", x: 64, y: 11, size: 4, style: .harbour),
        // Jerusalem of the Early Church
        Landmark(bookID: "acts", name: "Upper Room", regionID: "church", x: 63, y: 55, size: 4, style: .house),
        // Roads of the Mediterranean — west to east along the coastal road
        Landmark(bookID: "romans", name: "Rome", regionID: "mediterranean", x: 7, y: 4, size: 4, style: .portCity),
        Landmark(bookID: "1corinthians", name: "Corinth", regionID: "mediterranean", x: 14, y: 4, size: 3, style: .tower),
        Landmark(bookID: "2corinthians", name: "Cenchreae Port", regionID: "mediterranean", x: 20, y: 4, size: 3, style: .harbour),
        Landmark(bookID: "galatians", name: "Galatian Hills", regionID: "mediterranean", x: 26, y: 4, size: 3, style: .hill),
        Landmark(bookID: "ephesians", name: "Ephesus", regionID: "mediterranean", x: 32, y: 4, size: 3, style: .temple),
        Landmark(bookID: "philippians", name: "Philippi", regionID: "mediterranean", x: 38, y: 4, size: 3, style: .gate),
        Landmark(bookID: "colossians", name: "Colossae", regionID: "mediterranean", x: 44, y: 4, size: 3, style: .village),
        Landmark(bookID: "1thessalonians", name: "Thessalonica", regionID: "mediterranean", x: 50, y: 4, size: 3, style: .portCity),
        Landmark(bookID: "2thessalonians", name: "Berea", regionID: "mediterranean", x: 8, y: 12, size: 3, style: .house),
        Landmark(bookID: "1timothy", name: "Lystra", regionID: "mediterranean", x: 14, y: 12, size: 3, style: .village),
        Landmark(bookID: "2timothy", name: "Troas", regionID: "mediterranean", x: 20, y: 12, size: 3, style: .harbour),
        Landmark(bookID: "titus", name: "Crete Harbour", regionID: "mediterranean", x: 26, y: 12, size: 3, style: .portCity),
        Landmark(bookID: "philemon", name: "Philemon's Villa", regionID: "mediterranean", x: 32, y: 12, size: 3, style: .house),
        Landmark(bookID: "hebrews", name: "Hall of Faith", regionID: "mediterranean", x: 38, y: 12, size: 3, style: .palace),
        Landmark(bookID: "james", name: "Market of Deeds", regionID: "mediterranean", x: 44, y: 12, size: 3, style: .well),
        Landmark(bookID: "1peter", name: "Pontus Shore", regionID: "mediterranean", x: 50, y: 12, size: 3, style: .harbour),
        Landmark(bookID: "2peter", name: "Watchtower of Hope", regionID: "mediterranean", x: 11, y: 19, size: 3, style: .tower),
        Landmark(bookID: "1john", name: "House of Love", regionID: "mediterranean", x: 19, y: 19, size: 3, style: .house),
        Landmark(bookID: "2john", name: "Chosen Lady's Garden", regionID: "mediterranean", x: 27, y: 19, size: 3, style: .garden),
        Landmark(bookID: "3john", name: "Gaius' Inn", regionID: "mediterranean", x: 35, y: 19, size: 3, style: .village),
        Landmark(bookID: "jude", name: "Lighthouse of Jude", regionID: "mediterranean", x: 43, y: 19, size: 3, style: .tower),
        // Patmos & the New Jerusalem
        Landmark(bookID: "revelation", name: "New Jerusalem", regionID: "patmos", x: 12, y: 36, size: 7, style: .glowCity),
    ]

    // MARK: Connections

    static let connections: [Connection] = [
        Connection(a: "genesis", b: "hebrews", title: "Abraham's faith",
                   text: "Genesis tells how Abraham trusted God's promise; Hebrews 11 remembers him in its great roll call of faith."),
        Connection(a: "isaiah", b: "matthew", title: "Prophecy fulfilled",
                   text: "Isaiah foretold a child called Immanuel, \"God with us\"; Matthew 1 sees it fulfilled in Jesus' birth."),
        Connection(a: "exodus", b: "john", title: "The Lamb",
                   text: "The Passover lamb saved Israel in Exodus 12; John the Baptist calls Jesus \"the Lamb of God\" in John 1."),
        Connection(a: "psalms", b: "acts", title: "Psalms preached",
                   text: "At Pentecost in Acts 2, Peter quotes Psalm 16 to explain the resurrection."),
        Connection(a: "ruth", b: "matthew", title: "A family line",
                   text: "Ruth the Moabitess became great-grandmother of King David, and is named in Jesus' family tree in Matthew 1."),
        Connection(a: "jonah", b: "matthew", title: "The sign of Jonah",
                   text: "Jesus points to Jonah's three days in the fish as a sign of his own death and rising (Matthew 12)."),
        Connection(a: "daniel", b: "revelation", title: "Visions of the kingdom",
                   text: "Daniel's visions of beasts and an everlasting kingdom echo through John's visions in Revelation."),
        Connection(a: "genesis", b: "revelation", title: "The tree of life",
                   text: "The tree of life stands in Eden in Genesis 2, and again beside the river of the New Jerusalem in Revelation 22."),
        Connection(a: "leviticus", b: "hebrews", title: "The great high priest",
                   text: "Leviticus describes the priests and sacrifices; Hebrews presents Jesus as the high priest who fulfils them."),
    ]

    // MARK: Characters

    static let characters: [WorldCharacter] = [
        WorldCharacter(id: "noah", name: "Noah", bookID: "genesis",
                       line: "I built an ark, and God kept us safe through the flood.", robe: "#9DB0C8"),
        WorldCharacter(id: "abraham", name: "Abraham", bookID: "genesis",
                       line: "God promised me descendants as many as the stars.", robe: "#B48A6A"),
        WorldCharacter(id: "sarah", name: "Sarah", bookID: "genesis",
                       line: "I laughed at the promise, then laughed for joy when Isaac was born.", robe: "#D7A0A8"),
        WorldCharacter(id: "moses", name: "Moses", bookID: "exodus",
                       line: "God led his people out of Egypt and through the sea.", robe: "#C98F6E"),
        WorldCharacter(id: "samson", name: "Samson", bookID: "judges",
                       line: "My strength came from God, not from my hair.", robe: "#A9905C"),
        WorldCharacter(id: "ruth", name: "Ruth", bookID: "ruth",
                       line: "Where you go, I will go. Your God will be my God.", robe: "#E3B07E"),
        WorldCharacter(id: "david", name: "David", bookID: "1samuel",
                       line: "A shepherd boy, a sling, and a giant who fell.", robe: "#8FA3C7"),
        WorldCharacter(id: "solomon", name: "Solomon", bookID: "1kings",
                       line: "I asked God for wisdom, and he gave it generously.", robe: "#B79AD6"),
        WorldCharacter(id: "daniel", name: "Daniel", bookID: "daniel",
                       line: "I kept praying three times a day, even with lions waiting.", robe: "#7FA7A0"),
        WorldCharacter(id: "jesus", name: "Jesus", bookID: "matthew",
                       line: "Come to me, all who are weary, and I will give you rest.", robe: "#F2EBDD"),
        WorldCharacter(id: "mary", name: "Mary", bookID: "luke",
                       line: "Be it unto me according to thy word.", robe: "#93AECF"),
        WorldCharacter(id: "john", name: "John", bookID: "john",
                       line: "In the beginning was the Word.", robe: "#C7A27A"),
        WorldCharacter(id: "paul", name: "Paul", bookID: "acts",
                       line: "I travelled these roads to share the good news.", robe: "#A88D7A"),
    ]

    // MARK: Terrain features (used by the terrain generator)

    /// The Mediterranean, as a polygon in grid coordinates.
    static let mediterranean: [CGPoint] = [
        CGPoint(x: -2, y: 27), CGPoint(x: 10, y: 26), CGPoint(x: 20, y: 27.5), CGPoint(x: 28, y: 26),
        CGPoint(x: 33.5, y: 28), CGPoint(x: 33, y: 40), CGPoint(x: 32, y: 52), CGPoint(x: 31.5, y: 64),
        CGPoint(x: 31, y: 74), CGPoint(x: 27, y: 78.5), CGPoint(x: 18, y: 79.5), CGPoint(x: 8, y: 78),
        CGPoint(x: -2, y: 79),
    ]
    /// Patmos sits in the sea; it is land.
    static let patmos = Ellipse(cx: 15.5, cy: 39.5, rx: 7.5, ry: 7.5)
    static let seaOfGalilee = Ellipse(cx: 74, cy: 14, rx: 4.5, ry: 5)
    static let deadSea = Ellipse(cx: 81, cy: 58, rx: 2.6, ry: 5)

    /// Rivers as polylines (grid coordinates) with a half-width in tiles.
    static let rivers: [(points: [CGPoint], width: Double)] = [
        // Jordan: Galilee → Dead Sea
        ([CGPoint(x: 74, y: 18.5), CGPoint(x: 75.5, y: 26), CGPoint(x: 77.5, y: 34), CGPoint(x: 77.5, y: 42),
          CGPoint(x: 79.5, y: 48), CGPoint(x: 81, y: 53.5)], 0.7),
        // Nile → Mediterranean
        ([CGPoint(x: 44, y: 97), CGPoint(x: 43, y: 90), CGPoint(x: 41.5, y: 84), CGPoint(x: 38, y: 79)], 0.9),
        // Euphrates: out of Eden, through Babylon
        ([CGPoint(x: 102, y: 18), CGPoint(x: 100.5, y: 30), CGPoint(x: 101, y: 46), CGPoint(x: 106, y: 60),
          CGPoint(x: 114, y: 78), CGPoint(x: 128, y: 97)], 0.8),
        // Tigris
        ([CGPoint(x: 107, y: 18), CGPoint(x: 114, y: 30), CGPoint(x: 118, y: 50), CGPoint(x: 122, y: 70),
          CGPoint(x: 129, y: 86)], 0.7),
    ]

    /// Ancient roads that tie every region into one land (drawn into the terrain).
    static let roads: [[CGPoint]] = [
        // Via Maris: Egypt → coast → Promised Land → Galilee
        [CGPoint(x: 52, y: 88), CGPoint(x: 44, y: 76), CGPoint(x: 39, y: 62), CGPoint(x: 40, y: 50),
         CGPoint(x: 47, y: 40), CGPoint(x: 56, y: 26), CGPoint(x: 62, y: 23), CGPoint(x: 66, y: 16)],
        // Coastal road of the Mediterranean
        [CGPoint(x: 62, y: 23), CGPoint(x: 56, y: 10), CGPoint(x: 30, y: 10), CGPoint(x: 5, y: 10)],
        [CGPoint(x: 56, y: 17), CGPoint(x: 8, y: 17)],
        // Jerusalem → Upper Room → Wilderness → Egypt
        [CGPoint(x: 47, y: 40), CGPoint(x: 63, y: 40), CGPoint(x: 67, y: 54), CGPoint(x: 66, y: 64),
         CGPoint(x: 64, y: 76), CGPoint(x: 54, y: 86)],
        // King's road east over the Jordan to Babylon and Eden
        [CGPoint(x: 69, y: 34), CGPoint(x: 78, y: 38), CGPoint(x: 90, y: 46), CGPoint(x: 98, y: 37),
         CGPoint(x: 103, y: 28), CGPoint(x: 104, y: 19)],
        // Babylon south to Job's outpost, and west to Nehemiah's walls
        [CGPoint(x: 96, y: 46), CGPoint(x: 97, y: 58), CGPoint(x: 102, y: 72)],
        [CGPoint(x: 97, y: 58), CGPoint(x: 90, y: 62)],
        // Galilee to the Mount of Beatitudes
        [CGPoint(x: 66, y: 16), CGPoint(x: 72, y: 7), CGPoint(x: 82, y: 7)],
        // Prophets' hill road
        [CGPoint(x: 39, y: 62), CGPoint(x: 56, y: 62)],
        [CGPoint(x: 37, y: 56), CGPoint(x: 56, y: 56)],
        [CGPoint(x: 37, y: 68), CGPoint(x: 56, y: 68)],
    ]
}
