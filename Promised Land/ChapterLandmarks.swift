import Foundation
import CoreGraphics

// Story-specific objects built by reading particular chapters.
//
// CONTENT RULE: every entry is unreviewed (`reviewed: false`) until checked by a person.
// Release builds hide unreviewed entries (see ContentGate.swift). Map positions are on a
// stylised map and are approximate; placement notes flag where an object sits outside
// its book's region or where the geography is simplified.

nonisolated enum ChapterObjectKind: String, Sendable {
    case edenTrees, ark, ladder, tower, sinai, bush, plague, redSea, fallenWalls
    case valley, stronghold, pasture, shipAndFish, lionsDen, boats, weddingHouse
    case vineyard, hillsideCrowd, pentecost, shipwreck, altarCourt
}

struct ChapterLandmark: Identifiable, Hashable, ReviewableContent {
    let id: String
    let bookID: String
    /// Reading any of these chapters builds the object.
    let chapters: ClosedRange<Int>
    let name: String
    /// One line on what the chapter tells, shown on the "Why is this here?" card.
    let summary: String
    let kind: ChapterObjectKind
    /// North-west corner on the world grid; the object covers `size × size` tiles.
    let x: Int, y: Int
    let size: Int
    /// Sits on water (sea or lake) rather than land.
    var onWater = false
    /// Variant for kinds with several looks (e.g. which plague marker).
    var variant = 0
    let reference: String
    let source: String
    /// Placement or content notes for the reviewer.
    var note: String = ""
    var reviewed = false

    var center: CGPoint { CGPoint(x: Double(x) + Double(size) / 2, y: Double(y) + Double(size) / 2) }
    var book: Book? { BibleCatalog.book(id: bookID) }

    /// "John 15" or "Genesis 6–9".
    var chapterLabel: String {
        let name = book?.name ?? bookID
        return chapters.count == 1 ? "\(name) \(chapters.lowerBound)" : "\(name) \(chapters.lowerBound)–\(chapters.upperBound)"
    }
}

enum ChapterLandmarks {
    /// Entries visible in this build (reviewed only in Release).
    static var visible: [ChapterLandmark] { ContentGate.visible(all) }

    static func entries(for bookID: String, chapter: Int) -> [ChapterLandmark] {
        visible.filter { $0.bookID == bookID && $0.chapters.contains(chapter) }
    }

    static func entry(id: String) -> ChapterLandmark? { all.first { $0.id == id } }

    static let all: [ChapterLandmark] = [
        // MARK: Genesis (Eden & Beginnings)
        // MARK: Leviticus (the Tabernacle)
        ChapterLandmark(id: "altar-offerings", bookID: "leviticus", chapters: 1...7, name: "Altar of Burnt-Offering",
                        summary: "The LORD calls to Moses out of the tent of meeting and gives the laws of the offerings brought to the altar.",
                        kind: .altarCourt, x: 66, y: 71, size: 2,
                        reference: "Leviticus 1:1–9", source: "Leviticus 1–7 (ASV)",
                        note: "Placed beside the Tabernacle landmark on the world map; check it doesn't overlap."),
        ChapterLandmark(id: "eden-garden", bookID: "genesis", chapters: 1...2, name: "Garden of Eden",
                        summary: "God plants a garden eastward in Eden, with a river to water it.",
                        kind: .edenTrees, x: 94, y: 12, size: 3,
                        reference: "Genesis 2:8–10", source: "Genesis 1–2 (ASV)"),
        ChapterLandmark(id: "ark", bookID: "genesis", chapters: 6...9, name: "Noah's Ark",
                        summary: "Noah builds the ark; the flood comes, the waters recede, and God sets his bow in the cloud.",
                        kind: .ark, x: 114, y: 8, size: 3,
                        reference: "Genesis 6:14; 8:4; 9:13", source: "Genesis 6–9 (ASV)",
                        note: "Drawn with its own small body of water. Ararat (8:4) is to the north; placed in the north-east of the map."),
        ChapterLandmark(id: "babel", bookID: "genesis", chapters: 11...11, name: "Tower of Babel",
                        summary: "People build a city and a tower in the land of Shinar, and their language is confused.",
                        kind: .tower, x: 110, y: 46, size: 3,
                        reference: "Genesis 11:2–9", source: "Genesis 11 (ASV)",
                        note: "Shinar (11:2) placed in the Babylon & Persia region, outside Genesis's own region."),
        ChapterLandmark(id: "jacobs-ladder", bookID: "genesis", chapters: 28...28, name: "Jacob's Ladder",
                        summary: "Jacob dreams of a ladder reaching to heaven, with angels ascending and descending.",
                        kind: .ladder, x: 88, y: 8, size: 2,
                        reference: "Genesis 28:12", source: "Genesis 28 (ASV)",
                        note: "Bethel (28:19) is in Canaan; placed in Genesis's region for simplicity."),

        // MARK: Exodus (Egypt; the Sinai stories sit in the Wilderness)
        ChapterLandmark(id: "burning-bush", bookID: "exodus", chapters: 3...3, name: "The Burning Bush",
                        summary: "At Horeb, the mountain of God, Moses sees a bush that burns but is not consumed.",
                        kind: .bush, x: 79, y: 90, size: 2,
                        reference: "Exodus 3:1–2", source: "Exodus 3 (ASV)",
                        note: "Horeb is not in Egypt; placed in the Wilderness region."),
        ChapterLandmark(id: "plague-7", bookID: "exodus", chapters: 7...7, name: "Plague Marker: Blood",
                        summary: "The waters of the river are turned to blood.",
                        kind: .plague, x: 54, y: 79, size: 2, variant: 0,
                        reference: "Exodus 7:20", source: "Exodus 7 (ASV)"),
        ChapterLandmark(id: "plague-8", bookID: "exodus", chapters: 8...8, name: "Plague Marker: Frogs, Lice, Flies",
                        summary: "Frogs, then lice, then swarms of flies come upon the land.",
                        kind: .plague, x: 55, y: 82, size: 2, variant: 1,
                        reference: "Exodus 8:6, 17, 24", source: "Exodus 8 (ASV)"),
        ChapterLandmark(id: "plague-9", bookID: "exodus", chapters: 9...9, name: "Plague Marker: Murrain, Boils, Hail",
                        summary: "Murrain on the cattle, boils on man and beast, and a grievous hail.",
                        kind: .plague, x: 56, y: 85, size: 2, variant: 2,
                        reference: "Exodus 9:3, 10, 23", source: "Exodus 9 (ASV)"),
        ChapterLandmark(id: "plague-10", bookID: "exodus", chapters: 10...10, name: "Plague Marker: Locusts, Darkness",
                        summary: "Locusts cover the face of the earth, then thick darkness for three days.",
                        kind: .plague, x: 56, y: 88, size: 2, variant: 3,
                        reference: "Exodus 10:14, 22", source: "Exodus 10 (ASV)"),
        ChapterLandmark(id: "plague-11", bookID: "exodus", chapters: 11...11, name: "Plague Marker: The Warning",
                        summary: "The death of the firstborn is announced.",
                        kind: .plague, x: 50, y: 90, size: 2, variant: 4,
                        reference: "Exodus 11:4–5", source: "Exodus 11 (ASV)"),
        ChapterLandmark(id: "plague-12", bookID: "exodus", chapters: 12...12, name: "Plague Marker: The Passover",
                        summary: "The Passover is kept, and the firstborn of Egypt die.",
                        kind: .plague, x: 47, y: 91, size: 2, variant: 5,
                        reference: "Exodus 12:11–13, 29", source: "Exodus 12 (ASV)"),
        ChapterLandmark(id: "red-sea", bookID: "exodus", chapters: 14...14, name: "The Parted Sea",
                        summary: "The waters are divided and Israel crosses on dry ground.",
                        kind: .redSea, x: 54, y: 91, size: 3,
                        reference: "Exodus 14:21–22", source: "Exodus 14 (ASV)",
                        note: "Drawn with its own strip of sea at the edge of Egypt; the map has no separate Red Sea."),
        ChapterLandmark(id: "sinai", bookID: "exodus", chapters: 19...20, name: "Mount Sinai",
                        summary: "Smoke and fire on the mount, and God speaks the commandments.",
                        kind: .sinai, x: 74, y: 86, size: 3,
                        reference: "Exodus 19:18–20; 20:1–17", source: "Exodus 19–20 (ASV)",
                        note: "Placed in the Wilderness region, south."),

        // MARK: Promised Land & Kingdom
        ChapterLandmark(id: "jericho-fallen", bookID: "joshua", chapters: 6...6, name: "Jericho's Fallen Walls",
                        summary: "Seven priests with trumpets of rams' horns; the people shout and the wall falls down flat.",
                        kind: .fallenWalls, x: 56, y: 37, size: 2,
                        reference: "Joshua 6:4, 20", source: "Joshua 6 (ASV)"),
        ChapterLandmark(id: "elah", bookID: "1samuel", chapters: 17...17, name: "Valley of Elah",
                        summary: "David chooses five smooth stones out of the brook and faces Goliath.",
                        kind: .valley, x: 58, y: 47, size: 3,
                        reference: "1 Samuel 17:2, 40", source: "1 Samuel 17 (ASV)",
                        note: "Elah lies west of Bethlehem; placed in the Kingdom region."),
        ChapterLandmark(id: "zion", bookID: "2samuel", chapters: 5...5, name: "Stronghold of Zion",
                        summary: "David takes the stronghold of Zion, the same is the city of David.",
                        kind: .stronghold, x: 70, y: 47, size: 3,
                        reference: "2 Samuel 5:7", source: "2 Samuel 5 (ASV)"),
        ChapterLandmark(id: "green-pastures", bookID: "psalms", chapters: 23...23, name: "Green Pastures",
                        summary: "He maketh me to lie down in green pastures; he leadeth me beside still waters.",
                        kind: .pasture, x: 66, y: 26, size: 2,
                        reference: "Psalm 23:2", source: "Psalm 23 (ASV)"),

        // MARK: Prophets, Babylon
        ChapterLandmark(id: "jonah-sea", bookID: "jonah", chapters: 1...2, name: "Ship and Great Fish",
                        summary: "Jonah flees by ship from Joppa; in the storm he is cast into the sea and swallowed by a great fish.",
                        kind: .shipAndFish, x: 27, y: 68, size: 3, onWater: true,
                        reference: "Jonah 1:3, 15, 17", source: "Jonah 1–2 (ASV)"),
        ChapterLandmark(id: "lions-den", bookID: "daniel", chapters: 6...6, name: "The Lions' Den",
                        summary: "Daniel is cast into the den of lions, and God shuts the lions' mouths.",
                        kind: .lionsDen, x: 86, y: 49, size: 3,
                        reference: "Daniel 6:16, 22", source: "Daniel 6 (ASV)"),

        // MARK: Galilee
        ChapterLandmark(id: "galilee-boats", bookID: "mark", chapters: 4...4, name: "Boat on the Sea",
                        summary: "Jesus teaches from a boat, then calms the wind and the sea.",
                        kind: .boats, x: 73, y: 14, size: 2, onWater: true,
                        reference: "Mark 4:1, 37–39", source: "Mark 4 (ASV)"),
        ChapterLandmark(id: "cana", bookID: "john", chapters: 2...2, name: "Wedding House at Cana",
                        summary: "At a marriage in Cana, six waterpots of stone are filled, and the water becomes wine.",
                        kind: .weddingHouse, x: 66, y: 4, size: 3,
                        reference: "John 2:1–9", source: "John 2 (ASV)"),
        ChapterLandmark(id: "true-vine", bookID: "john", chapters: 15...15, name: "The Vineyard",
                        summary: "\"I am the vine, ye are the branches.\"",
                        kind: .vineyard, x: 58, y: 11, size: 3,
                        reference: "John 15:5", source: "John 15 (ASV)",
                        note: "The discourse is set near Jerusalem, not Galilee; placed in John's region."),
        ChapterLandmark(id: "sermon-hillside", bookID: "matthew", chapters: 5...5, name: "The Hillside",
                        summary: "Seeing the multitudes, Jesus goes up into the mountain and teaches them.",
                        kind: .hillsideCrowd, x: 79, y: 11, size: 3,
                        reference: "Matthew 5:1–2", source: "Matthew 5 (ASV)"),

        // MARK: Early Church & the Mediterranean
        ChapterLandmark(id: "pentecost", bookID: "acts", chapters: 2...2, name: "Tongues of Fire",
                        summary: "On the day of Pentecost, tongues like as of fire rest on each of them.",
                        kind: .pentecost, x: 69, y: 56, size: 2,
                        reference: "Acts 2:1–4", source: "Acts 2 (ASV)"),
        ChapterLandmark(id: "shipwreck", bookID: "acts", chapters: 27...28, name: "Shipwreck off Melita",
                        summary: "The ship runs aground and breaks up; all reach land safely, on an island called Melita.",
                        kind: .shipwreck, x: 20, y: 57, size: 3, onWater: true,
                        reference: "Acts 27:41–44; 28:1–2", source: "Acts 27–28 (ASV)",
                        note: "Melita is usually identified as Malta; position in the sea is approximate."),
    ]
}
