import Foundation

// Bible characters who come to live on your island when you finish reading their books.
//
// CONTENT RULE: every entry is unreviewed (`reviewed: false`) until checked by a person;
// Release builds hide unreviewed characters. Speech lines quote the ASV where marked, or
// describe what the referenced chapter tells; references are given for the reviewer.

nonisolated enum Rarity: String, Sendable, CaseIterable {
    case common, rare, legendary

    var title: String { rawValue.capitalized }
}

struct BibleCharacter: Identifiable, Hashable, ReviewableContent {
    let id: String
    let name: String
    let rarity: Rarity
    /// Reading every chapter of all of these books unlocks the character.
    let books: [String]
    /// Finishing this story journey also unlocks them (see JourneyData), if set.
    var journeyID: String? = nil
    /// Whose plot they walk around (the first of `books` you've started, otherwise this one).
    let homeBook: String
    /// What they say when tapped.
    let line: String
    /// "Read their story" opens this chapter.
    let storyBook: String
    let storyChapter: Int
    /// The look used when there's no `char_<id>` image (the matching avatar preset).
    var look: Avatar { Avatar(config: AvatarPresets.config(for: id == "disciples" ? "john" : id)) }
    let reference: String
    let source: String
    var note: String = ""
    var reviewed = false

    /// Shown under the name: what unlocks them.
    var unlockText: String {
        let names = books.compactMap { BibleCatalog.book(id: $0)?.name }
        let list: String = switch names.count {
        case 0: ""
        case 1: names[0]
        case 2: "\(names[0]) and \(names[1])"
        default:
            books.count > 12 ? "every book from \(names.first!) to \(names.last!)" : "\(names.first!) to \(names.last!)"
        }
        if let journeyID, let journey = JourneyData.journey(id: journeyID) {
            return "Finish reading \(list), or complete \(journey.name)"
        }
        return "Finish reading \(list)"
    }
}

enum CharacterUnlocks {
    static var visible: [BibleCharacter] { ContentGate.visible(all) }
    static func character(id: String) -> BibleCharacter? { all.first { $0.id == id } }

    /// Characters unlocked, given the books finished and journeys completed.
    static func unlocked(finishedBooks: Set<String>, completedJourneys: Set<String> = []) -> [BibleCharacter] {
        visible.filter { c in
            Set(c.books).isSubset(of: finishedBooks) || c.journeyID.map(completedJourneys.contains) == true
        }
    }

    private static let pauline = ["acts", "romans", "1corinthians", "2corinthians", "galatians", "ephesians", "philippians",
                                  "colossians", "1thessalonians", "2thessalonians", "1timothy", "2timothy", "titus", "philemon"]

    static let all: [BibleCharacter] = [
        BibleCharacter(id: "ruth", name: "Ruth", rarity: .common, books: ["ruth"], homeBook: "ruth",
                       line: "\u{201C}Whither thou goest, I will go.\u{201D}", storyBook: "ruth", storyChapter: 1,
                       reference: "Ruth 1:16", source: "Ruth 1:16 (ASV)"),
        BibleCharacter(id: "jonah", name: "Jonah", rarity: .common, books: ["jonah"], journeyID: "jonah", homeBook: "jonah",
                       line: "I ran from the LORD's call, and spent three days and three nights in the belly of a great fish.",
                       storyBook: "jonah", storyChapter: 1,
                       reference: "Jonah 1:3, 1:17", source: "Jonah 1 (ASV)",
                       note: "Line paraphrases Jonah 1:3 and 1:17."),
        BibleCharacter(id: "daniel", name: "Daniel", rarity: .common, books: ["daniel"], homeBook: "daniel",
                       line: "\u{201C}My God hath sent his angel, and hath shut the lions' mouths.\u{201D}",
                       storyBook: "daniel", storyChapter: 6,
                       reference: "Daniel 6:22", source: "Daniel 6:22 (ASV)"),
        BibleCharacter(id: "david", name: "David", rarity: .rare, books: ["1samuel", "2samuel"], homeBook: "1samuel",
                       line: "I went out to meet Goliath with a sling and five smooth stones.",
                       storyBook: "1samuel", storyChapter: 17,
                       reference: "1 Samuel 17:40", source: "1 Samuel 17 (ASV)",
                       note: "Line paraphrases 1 Samuel 17:40."),
        BibleCharacter(id: "moses", name: "Moses", rarity: .rare,
                       books: ["exodus", "leviticus", "numbers", "deuteronomy"], homeBook: "exodus",
                       line: "I led the children of Israel out of Egypt, through the midst of the sea on dry ground.",
                       storyBook: "exodus", storyChapter: 14,
                       reference: "Exodus 14:21–22", source: "Exodus 14 (ASV)",
                       note: "Line paraphrases Exodus 14:21–22."),
        BibleCharacter(id: "disciples", name: "The disciples", rarity: .rare,
                       books: ["matthew", "mark", "luke", "john"], journeyID: "galilee", homeBook: "mark",
                       line: "\u{201C}And straightway they left the nets, and followed him.\u{201D}",
                       storyBook: "mark", storyChapter: 1,
                       reference: "Mark 1:18", source: "Mark 1:18 (ASV)",
                       note: "Shown with the picture drawn for John in the art direction."),
        BibleCharacter(id: "paul", name: "Paul", rarity: .legendary, books: pauline, journeyID: "paul-rome", homeBook: "acts",
                       line: "I sailed for Rome as a prisoner, and was shipwrecked on the island of Melita on the way.",
                       storyBook: "acts", storyChapter: 27,
                       reference: "Acts 27:1, 28:1", source: "Acts 27–28 (ASV)",
                       note: "Line paraphrases Acts 27:1 and 28:1. 'Acts plus letters' is taken as Acts and Romans–Philemon."),
        BibleCharacter(id: "jesus", name: "Jesus", rarity: .legendary,
                       books: BibleCatalog.books.filter { $0.testament == .new }.map(\.id), homeBook: "john",
                       line: "\u{201C}I am the good shepherd.\u{201D}", storyBook: "john", storyChapter: 10,
                       reference: "John 10:11", source: "John 10:11 (ASV)"),
    ]
}

/// Which character looks can be used in the avatar creator ("Start from a character").
enum PresetAccess {
    static let ids = ["ruth", "samson", "daniel", "sarah", "mary", "abraham", "solomon", "david", "john", "paul", "moses", "jesus", "jonah"]

    static func name(_ id: String) -> String { id.prefix(1).uppercased() + id.dropFirst() }

    /// Unlocked presets: a character's look is yours once their journey is complete.
    static func unlocked(_ progress: GameProgress) -> Set<String> {
        let finished = Set(BibleCatalog.books.filter { progress.chaptersRead($0.id) >= $0.chapterCount }.map(\.id))
        let ids = CharacterUnlocks.unlocked(finishedBooks: finished, completedJourneys: Set(progress.completedJourneys.map(\.id))).map(\.id)
        return Set(ids.map { $0 == "disciples" ? "john" : $0 })
    }
}
