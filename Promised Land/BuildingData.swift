import Foundation

// What each book builds on your island.
//
// Every one of the 66 books has its own building, put together from a few parts: a family
// (its overall shape), a roof, a crest on top, a width, a number of storeys, and wings.
// No two books share the same combination (checked by a test), so every building has its
// own silhouette. Names come from the world map's landmarks (WorldData).
//
// These are design choices, not historical claims: a "tower" for Isaiah's watchman or a
// "harbour" for Joppa is an illustration, and the art is stylised.

nonisolated enum BuildingFamily: String, Sendable, CaseIterable {
    case hall, tower, ziggurat, temple, fort, gate, pavilion, house, garden, harbour, well, mountain, lighthouse
}

nonisolated enum RoofKind: String, Sendable, CaseIterable {
    case pyramid, dome, goldDome, flat, crenellated, gable, spire, tent
}

nonisolated enum Crest: String, Sendable, CaseIterable {
    case none, star, flame, flag, bell, orb, lamp, cross, crown, scroll, dove, palm, wheat, harp, jar, grapes
}

nonisolated enum WallTone: String, Sendable {
    case sand, cream, clay, wood
}

/// Small things placed around a book's plot, one per chapter read.
nonisolated enum ArtifactKind: String, Sendable, CaseIterable {
    case olive, palm, cypress, bush, flowers, sheep, tent, well, scroll, jar, stele, altar
    case boat, fishBasket, wheat, vine, oilLamp, harp, domedHouse
}

nonisolated struct BuildingSpec: Sendable, Equatable {
    let bookID: String
    let family: BuildingFamily
    let roof: RoofKind
    let crest: Crest
    /// 1...3: how much of its plot it covers.
    let width: Int
    /// 1...4: storeys when first built (each full reread adds one more).
    let storeys: Int
    /// 0...2: extra annexes behind the main building.
    let wings: Int
    var walls: WallTone = .sand
    /// Chapter artifacts cycle through these.
    let theme: [ArtifactKind]

    /// Everything that shapes the outline. Must be unique per book.
    var silhouette: String { "\(family.rawValue)-\(roof.rawValue)-\(crest.rawValue)-w\(width)-s\(storeys)-g\(wings)" }

    /// The art-swap image id (see ART_ASSETS.md).
    var imageID: String { "bld_\(bookID)" }
}

nonisolated enum BuildingData {
    static func spec(for bookID: String) -> BuildingSpec {
        byID[bookID] ?? BuildingSpec(bookID: bookID, family: .house, roof: .flat, crest: .none, width: 1,
                                     storeys: 1, wings: 0, theme: [.olive, .flowers, .jar])
    }

    private static let byID: [String: BuildingSpec] = Dictionary(uniqueKeysWithValues: all.map { ($0.bookID, $0) })

    private static func b(_ id: String, _ family: BuildingFamily, _ roof: RoofKind, _ crest: Crest,
                          w: Int, s: Int, g: Int = 0, _ theme: [ArtifactKind], _ walls: WallTone = .sand) -> BuildingSpec {
        BuildingSpec(bookID: id, family: family, roof: roof, crest: crest, width: w, storeys: s, wings: g,
                     walls: walls, theme: theme)
    }

    static let all: [BuildingSpec] = [
        // Law
        b("genesis", .garden, .dome, .none, w: 2, s: 1, [.olive, .flowers, .palm]),
        b("exodus", .ziggurat, .pyramid, .none, w: 3, s: 3, [.tent, .stele, .jar]),
        b("leviticus", .pavilion, .tent, .flame, w: 2, s: 1, g: 1, [.altar, .oilLamp, .jar], .cream),
        b("numbers", .pavilion, .tent, .flag, w: 2, s: 1, g: 2, [.tent, .sheep, .well]),
        b("deuteronomy", .mountain, .flat, .star, w: 3, s: 2, [.stele, .scroll, .cypress]),
        // History
        b("joshua", .fort, .crenellated, .flag, w: 3, s: 1, [.stele, .tent, .palm]),
        b("judges", .house, .flat, .palm, w: 1, s: 1, g: 1, [.palm, .tent, .sheep]),
        b("ruth", .house, .gable, .wheat, w: 1, s: 1, g: 2, [.wheat, .wheat, .jar], .cream),
        b("1samuel", .tower, .crenellated, .flag, w: 1, s: 3, [.sheep, .harp, .stele]),
        b("2samuel", .hall, .crenellated, .crown, w: 2, s: 2, g: 1, [.harp, .cypress, .jar]),
        b("1kings", .temple, .gable, .flame, w: 2, s: 2, g: 2, [.cypress, .oilLamp, .altar], .cream),
        b("2kings", .gate, .crenellated, .crown, w: 2, s: 2, [.stele, .well, .olive]),
        b("1chronicles", .hall, .gable, .scroll, w: 2, s: 2, [.scroll, .jar, .olive]),
        b("2chronicles", .fort, .crenellated, .crown, w: 3, s: 2, [.altar, .stele, .cypress]),
        b("ezra", .temple, .flat, .flame, w: 1, s: 1, g: 1, [.altar, .scroll, .stele]),
        b("nehemiah", .fort, .crenellated, .none, w: 2, s: 2, g: 1, [.stele, .stele, .well]),
        b("esther", .hall, .goldDome, .crown, w: 3, s: 2, g: 2, [.cypress, .jar, .flowers], .cream),
        // Poetry & wisdom
        b("job", .pavilion, .tent, .none, w: 2, s: 1, [.sheep, .tent, .bush]),
        b("psalms", .temple, .flat, .harp, w: 3, s: 1, g: 2, [.harp, .flowers, .sheep], .cream),
        b("proverbs", .house, .dome, .scroll, w: 1, s: 2, g: 1, [.scroll, .olive, .jar]),
        b("ecclesiastes", .hall, .dome, .orb, w: 2, s: 2, g: 2, [.flowers, .scroll, .bush]),
        b("songofsongs", .garden, .gable, .dove, w: 2, s: 1, g: 1, [.vine, .flowers, .palm]),
        // Prophets
        b("isaiah", .tower, .pyramid, .lamp, w: 1, s: 4, [.scroll, .oilLamp, .olive]),
        b("jeremiah", .house, .flat, .jar, w: 1, s: 1, [.jar, .jar, .scroll], .clay),
        b("lamentations", .fort, .flat, .none, w: 2, s: 1, [.stele, .oilLamp, .bush]),
        b("ezekiel", .well, .dome, .none, w: 2, s: 1, [.well, .palm, .stele]),
        b("daniel", .gate, .crenellated, .orb, w: 3, s: 2, [.oilLamp, .scroll, .palm], .clay),
        b("hosea", .garden, .gable, .grapes, w: 1, s: 1, [.vine, .vine, .olive]),
        b("joel", .garden, .flat, .none, w: 1, s: 1, g: 1, [.olive, .wheat, .vine]),
        b("amos", .pavilion, .tent, .none, w: 1, s: 1, g: 1, [.sheep, .bush, .olive]),
        b("obadiah", .mountain, .flat, .none, w: 2, s: 1, [.stele, .bush, .cypress]),
        b("jonah", .harbour, .gable, .none, w: 1, s: 1, [.boat, .fishBasket, .bush]),
        b("micah", .house, .pyramid, .none, w: 1, s: 1, g: 2, [.domedHouse, .olive, .sheep]),
        b("nahum", .tower, .crenellated, .none, w: 1, s: 2, [.stele, .cypress, .bush]),
        b("habakkuk", .fort, .crenellated, .lamp, w: 1, s: 2, [.scroll, .stele, .olive]),
        b("zephaniah", .gate, .pyramid, .bell, w: 1, s: 2, [.oilLamp, .stele, .bush]),
        b("haggai", .temple, .flat, .none, w: 1, s: 1, [.stele, .altar, .wheat]),
        b("zechariah", .hall, .flat, .lamp, w: 2, s: 1, g: 1, [.oilLamp, .olive, .scroll], .cream),
        b("malachi", .well, .pyramid, .star, w: 1, s: 1, g: 1, [.well, .altar, .jar]),
        // Gospels & Acts
        b("matthew", .mountain, .dome, .cross, w: 2, s: 1, [.flowers, .scroll, .olive]),
        b("mark", .house, .flat, .none, w: 2, s: 1, g: 1, [.boat, .fishBasket, .domedHouse]),
        b("luke", .house, .pyramid, .star, w: 1, s: 1, g: 1, [.sheep, .domedHouse, .oilLamp]),
        b("john", .harbour, .flat, .none, w: 2, s: 1, g: 1, [.boat, .vine, .oilLamp]),
        b("acts", .house, .flat, .flame, w: 1, s: 2, [.scroll, .boat, .domedHouse]),
        // Letters
        b("romans", .hall, .dome, .cross, w: 3, s: 3, g: 2, [.scroll, .cypress, .domedHouse], .cream),
        b("1corinthians", .tower, .dome, .cross, w: 1, s: 3, [.scroll, .jar, .flowers]),
        b("2corinthians", .harbour, .pyramid, .flag, w: 2, s: 1, [.boat, .jar, .scroll]),
        b("galatians", .mountain, .pyramid, .none, w: 1, s: 1, [.sheep, .bush, .scroll]),
        b("ephesians", .temple, .gable, .none, w: 3, s: 2, g: 1, [.cypress, .scroll, .oilLamp], .cream),
        b("philippians", .gate, .gable, .none, w: 2, s: 1, [.flowers, .scroll, .olive]),
        b("colossians", .house, .gable, .none, w: 1, s: 1, g: 1, [.olive, .scroll, .flowers], .clay),
        b("1thessalonians", .harbour, .dome, .cross, w: 3, s: 2, [.boat, .oilLamp, .scroll]),
        b("2thessalonians", .house, .dome, .none, w: 1, s: 1, [.scroll, .bush, .oilLamp]),
        b("1timothy", .house, .gable, .star, w: 1, s: 2, [.scroll, .olive, .jar]),
        b("2timothy", .harbour, .flat, .flag, w: 1, s: 1, g: 1, [.scroll, .boat, .oilLamp]),
        b("titus", .harbour, .crenellated, .none, w: 2, s: 2, [.boat, .olive, .scroll]),
        b("philemon", .hall, .gable, .none, w: 1, s: 1, g: 2, [.jar, .scroll, .flowers], .clay),
        b("hebrews", .hall, .flat, .star, w: 3, s: 2, [.altar, .scroll, .stele]),
        b("james", .well, .flat, .none, w: 2, s: 1, g: 1, [.jar, .wheat, .well]),
        b("1peter", .harbour, .gable, .cross, w: 1, s: 1, g: 1, [.sheep, .boat, .stele]),
        b("2peter", .tower, .spire, .star, w: 1, s: 3, [.oilLamp, .scroll, .cypress]),
        b("1john", .hall, .dome, .cross, w: 2, s: 2, [.oilLamp, .flowers, .domedHouse]),
        b("2john", .garden, .dome, .cross, w: 1, s: 1, [.flowers, .domedHouse, .bush]),
        b("3john", .house, .gable, .lamp, w: 2, s: 1, [.domedHouse, .jar, .oilLamp]),
        b("jude", .lighthouse, .dome, .lamp, w: 1, s: 4, [.oilLamp, .stele, .boat]),
        b("revelation", .hall, .goldDome, .star, w: 3, s: 3, g: 2, [.oilLamp, .palm, .flowers], .cream),
    ]
}
