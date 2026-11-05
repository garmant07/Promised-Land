import Foundation

// Character journeys: each follows one biblical character's story. Completing one (reading
// every required chapter) unlocks that character. Progress is worked out from every read
// ever recorded, so past reading counts.
//
// CONTENT RULE: every journey and stop is unreviewed (`reviewed: false`) until checked by a
// person. "What happened" follows the ASV text, with verse references. "What it may have
// looked like" is only filled where the text itself describes the scene; "why it matters" is
// left empty for review (see REVIEW.md). Release builds hide unreviewed text but keep the
// journeys working with plain wording.

/// A run of chapters in one book.
nonisolated struct ChapterSpan: Hashable, Sendable {
    let bookID: String
    let chapters: ClosedRange<Int>

    init(_ bookID: String, _ chapters: ClosedRange<Int>) { self.bookID = bookID; self.chapters = chapters }
    init(_ bookID: String, _ chapter: Int) { self.init(bookID, chapter...chapter) }
}

struct JourneyStopData: Identifiable, Hashable, ReviewableContent {
    let id: String
    let title: String
    /// Where it happened.
    let place: String
    /// What sort of place it was.
    var placeType = ""
    let spans: [ChapterSpan]
    let happened: String
    var lookedLike = ""
    /// TODO(review): left empty until a reviewed source is chosen.
    var whyItMatters = ""
    let reference: String
    var source = "ASV"
    var reviewed = false
}

struct CharacterJourney: Identifiable, Hashable, ReviewableContent {
    let id: String
    /// Matches the char_ asset.
    let characterId: String
    let title: String
    let subtitle: String
    let rarity: Rarity
    let required: [ChapterSpan]
    let stops: [JourneyStopData]
    /// Said when the character is unlocked (ASV quotation).
    let unlockLine: String
    let unlockReference: String
    let reference: String
    let source: String
    var note = ""
    var reviewed = false

    var name: String { title.replacingOccurrences(of: "'s journey", with: "") }

    /// Every chapter the journey needs, in order.
    var requiredChapters: [(book: String, chapter: Int)] {
        var seen: Set<String> = []
        var out: [(book: String, chapter: Int)] = []
        for span in required {
            for ch in span.chapters where seen.insert("\(span.bookID)#\(ch)").inserted { out.append((span.bookID, ch)) }
        }
        return out
    }

    /// Books whose plots the character strolls around (in order of the journey).
    var homeBooks: [String] {
        var out: [String] = []
        for span in required where !out.contains(span.bookID) { out.append(span.bookID) }
        return out
    }
}

enum CharacterJourneys {
    static func journey(id: String) -> CharacterJourney? { all.first { $0.id == id } }

    private static func book(_ id: String) -> ChapterSpan {
        ChapterSpan(id, 1...(BibleCatalog.book(id: id)?.chapterCount ?? 1))
    }
    private static func books(_ ids: ClosedRange<Int>) -> [ChapterSpan] {
        BibleCatalog.books[ids].map { book($0.id) }
    }
    private static let pauline = Array(44...56) // Romans … Philemon (canon positions)

    /// Shortest first (by chapters needed; ties keep the order below).
    static let all: [CharacterJourney] = written.enumerated()
        .sorted { ($0.element.requiredChapters.count, $0.offset) < ($1.element.requiredChapters.count, $1.offset) }
        .map(\.element)

    private static let written: [CharacterJourney] = [
        CharacterJourney(
            id: "ruth", characterId: "ruth", title: "Ruth's journey", subtitle: "From Moab to Bethlehem", rarity: .common,
            required: [ChapterSpan("ruth", 1...4)],
            stops: [
                JourneyStopData(id: "ruth-moab", title: "Moab", place: "Moab", placeType: "A neighbouring country",
                                spans: [ChapterSpan("ruth", 1)],
                                happened: "Naomi's husband and sons die in Moab. She sets out for home, and Ruth will not leave her.",
                                reference: "Ruth 1:1–18"),
                JourneyStopData(id: "ruth-road", title: "The road to Bethlehem", place: "Bethlehem-judah", placeType: "A town in Judah",
                                spans: [ChapterSpan("ruth", 1)],
                                happened: "Naomi and Ruth come to Bethlehem at the beginning of barley harvest.",
                                reference: "Ruth 1:19–22"),
                JourneyStopData(id: "ruth-field", title: "Boaz's field", place: "Bethlehem", placeType: "A barley field",
                                spans: [ChapterSpan("ruth", 2)],
                                happened: "Ruth gleans in the field of Boaz, a kinsman of Naomi's husband, and he is kind to her.",
                                lookedLike: "Reapers in the field, and Ruth gleaning after them.", reference: "Ruth 2:1–23"),
                JourneyStopData(id: "ruth-floor", title: "The threshing floor", place: "Bethlehem", placeType: "A threshing-floor",
                                spans: [ChapterSpan("ruth", 3)],
                                happened: "At Naomi's word, Ruth goes to Boaz at the threshing-floor and asks him to act as a near kinsman.",
                                lookedLike: "Boaz winnowing barley at night on the threshing-floor.", reference: "Ruth 3:1–18"),
                JourneyStopData(id: "ruth-gate", title: "The city gate", place: "Bethlehem", placeType: "The town gate",
                                spans: [ChapterSpan("ruth", 4)],
                                happened: "Before the elders at the gate, Boaz redeems the land and takes Ruth as his wife. Their son Obed is the grandfather of David.",
                                lookedLike: "Ten elders of the city sitting down at the gate.", reference: "Ruth 4:1–22"),
            ],
            unlockLine: "Whither thou goest, I will go.", unlockReference: "Ruth 1:16",
            reference: "Ruth 1–4", source: "Ruth (ASV)"),
        CharacterJourney(
            id: "jonah", characterId: "jonah", title: "Jonah's journey", subtitle: "From Joppa to Nineveh", rarity: .common,
            required: [ChapterSpan("jonah", 1...4)],
            stops: [
                JourneyStopData(id: "jonah-joppa", title: "Joppa", place: "Joppa", placeType: "A port",
                                spans: [ChapterSpan("jonah", 1)],
                                happened: "Jonah flees from the presence of Jehovah and finds a ship going to Tarshish.", reference: "Jonah 1:1–3"),
                JourneyStopData(id: "jonah-fish", title: "The great fish", place: "The sea", placeType: "Open sea",
                                spans: [ChapterSpan("jonah", 1...2)],
                                happened: "In a mighty tempest the sailors cast Jonah into the sea. A great fish swallows him, and he prays from its belly three days and three nights.",
                                lookedLike: "A mighty tempest, so that the ship was like to be broken.", reference: "Jonah 1:4–2:10"),
                JourneyStopData(id: "jonah-nineveh", title: "Nineveh", place: "Nineveh", placeType: "A great city",
                                spans: [ChapterSpan("jonah", 3)],
                                happened: "Jonah cries that Nineveh shall be overthrown; the people believe God and turn from their evil way.",
                                lookedLike: "An exceeding great city, of three days' journey.", reference: "Jonah 3:1–10"),
                JourneyStopData(id: "jonah-gourd", title: "The gourd", place: "East of the city", placeType: "A booth outside the city",
                                spans: [ChapterSpan("jonah", 4)],
                                happened: "Jonah is angry; God prepares a gourd to shade him, then a worm, and asks whether he should not have pity on Nineveh.",
                                lookedLike: "A booth on the east side of the city, and a gourd growing over Jonah's head.", reference: "Jonah 4:1–11"),
            ],
            unlockLine: "I cried by reason of mine affliction unto Jehovah, and he answered me.", unlockReference: "Jonah 2:2",
            reference: "Jonah 1–4", source: "Jonah (ASV)",
            note: "Bonus journey: Jonah was not in the 12, but his art was commissioned, so he stays (see NOTES.md)."),
        CharacterJourney(
            id: "samson", characterId: "samson", title: "Samson's journey", subtitle: "Strength and its secret", rarity: .common,
            required: [ChapterSpan("judges", 13...16)],
            stops: [
                JourneyStopData(id: "samson-birth", title: "His birth announced", place: "Zorah", placeType: "A town",
                                spans: [ChapterSpan("judges", 13)],
                                happened: "The angel of Jehovah tells Manoah's wife she will bear a son, a Nazirite unto God from the womb.",
                                reference: "Judges 13:2–25"),
                JourneyStopData(id: "samson-lion", title: "The lion and the riddle", place: "Timnah", placeType: "A town",
                                spans: [ChapterSpan("judges", 14)],
                                happened: "Samson tears a young lion; later he finds honey in its body and puts a riddle at his wedding feast.",
                                reference: "Judges 14:1–20"),
                JourneyStopData(id: "samson-lehi", title: "Against the Philistines", place: "Lehi", placeType: "A place in Judah",
                                spans: [ChapterSpan("judges", 15)],
                                happened: "Bound and handed over at Lehi, Samson breaks the cords and smites the Philistines with the jawbone of an ass.",
                                reference: "Judges 15:9–17"),
                JourneyStopData(id: "samson-delilah", title: "Delilah", place: "The valley of Sorek", placeType: "A valley",
                                spans: [ChapterSpan("judges", 16)],
                                happened: "Delilah presses Samson until he tells her the secret of his strength; his hair is shaved and he is taken.",
                                reference: "Judges 16:4–21"),
                JourneyStopData(id: "samson-dagon", title: "The temple of Dagon", place: "Gaza", placeType: "A Philistine city",
                                spans: [ChapterSpan("judges", 16)],
                                happened: "Blind and mocked at a feast to Dagon, Samson prays for strength once more and pulls down the house.",
                                lookedLike: "A house resting on two middle pillars, with about three thousand on the roof.", reference: "Judges 16:23–30"),
            ],
            unlockLine: "O Lord Jehovah, remember me, I pray thee, and strengthen me.", unlockReference: "Judges 16:28",
            reference: "Judges 13–16", source: "Judges (ASV)"),
        CharacterJourney(
            id: "daniel", characterId: "daniel", title: "Daniel's journey", subtitle: "Faithful in Babylon", rarity: .common,
            required: [book("daniel")],
            stops: [
                JourneyStopData(id: "daniel-court", title: "The king's court in Babylon", place: "Babylon", placeType: "A royal court",
                                spans: [ChapterSpan("daniel", 1)],
                                happened: "Taken to Babylon, Daniel and his friends will not eat the king's dainties; God gives them knowledge and wisdom.",
                                reference: "Daniel 1:1–21"),
                JourneyStopData(id: "daniel-statue", title: "The dream of the statue", place: "Babylon", placeType: "A royal court",
                                spans: [ChapterSpan("daniel", 2)],
                                happened: "Daniel tells Nebuchadnezzar his dream of a great image, and its meaning.",
                                lookedLike: "An image with a head of fine gold, struck by a stone cut out without hands.", reference: "Daniel 2:1–49"),
                JourneyStopData(id: "daniel-furnace", title: "The fiery furnace", place: "The plain of Dura", placeType: "A plain",
                                spans: [ChapterSpan("daniel", 3)],
                                happened: "Shadrach, Meshach and Abed-nego will not worship the golden image, and are kept safe in the furnace.",
                                reference: "Daniel 3:1–30"),
                JourneyStopData(id: "daniel-wall", title: "The writing on the wall", place: "Babylon", placeType: "The king's palace",
                                spans: [ChapterSpan("daniel", 5)],
                                happened: "At Belshazzar's feast a hand writes upon the wall; Daniel reads it and gives its meaning.",
                                reference: "Daniel 5:1–31"),
                JourneyStopData(id: "daniel-den", title: "The lions' den", place: "Babylon", placeType: "A den of lions",
                                spans: [ChapterSpan("daniel", 6)],
                                happened: "Daniel keeps praying three times a day, is cast into the den of lions, and God shuts the lions' mouths.",
                                reference: "Daniel 6:1–28"),
                JourneyStopData(id: "daniel-visions", title: "The visions", place: "Babylon", placeType: "Visions",
                                spans: [ChapterSpan("daniel", 7...12)],
                                happened: "Daniel sees visions of four beasts, a ram and a he-goat, and of the time of the end.",
                                reference: "Daniel 7–12"),
            ],
            unlockLine: "My God hath sent his angel, and hath shut the lions' mouths.", unlockReference: "Daniel 6:22",
            reference: "Daniel 1–12", source: "Daniel (ASV)"),
        CharacterJourney(
            id: "sarah", characterId: "sarah", title: "Sarah's journey", subtitle: "A promise kept", rarity: .common,
            required: [ChapterSpan("genesis", 11...23)],
            stops: [
                JourneyStopData(id: "sarah-ur", title: "Leaving Ur and Haran", place: "Ur of the Chaldees", placeType: "A city",
                                spans: [ChapterSpan("genesis", 11...12)],
                                happened: "Sarai goes with Abram from Ur of the Chaldees to Haran, and on into the land of Canaan.",
                                reference: "Genesis 11:31–12:5"),
                JourneyStopData(id: "sarah-egypt", title: "Egypt", place: "Egypt", placeType: "A country",
                                spans: [ChapterSpan("genesis", 12)],
                                happened: "In a famine they go down into Egypt, where Abram says Sarai is his sister.",
                                reference: "Genesis 12:10–20"),
                JourneyStopData(id: "sarah-promise", title: "The promise of a son", place: "The oaks of Mamre", placeType: "A camp by the oaks",
                                spans: [ChapterSpan("genesis", 17...18)],
                                happened: "God names her Sarah and promises she will bear a son. Hearing it at the tent door, she laughs.",
                                lookedLike: "Abraham sitting in the tent door in the heat of the day.", reference: "Genesis 17:15–19; 18:1–15"),
                JourneyStopData(id: "sarah-isaac", title: "Isaac is born", place: "Gerar", placeType: "Where they were sojourning",
                                spans: [ChapterSpan("genesis", 21)],
                                happened: "Sarah bears Isaac in her old age: \u{201C}God hath made me to laugh.\u{201D}",
                                reference: "Genesis 21:1–7",
                                source: "ASV. TODO(review): Genesis 20–21 places them in Gerar; confirm."),
                JourneyStopData(id: "sarah-hebron", title: "Hebron", place: "Hebron", placeType: "A town in Canaan",
                                spans: [ChapterSpan("genesis", 23)],
                                happened: "Sarah dies in Hebron, and Abraham buries her in the cave of the field of Machpelah.",
                                reference: "Genesis 23:1–20"),
            ],
            unlockLine: "God hath made me to laugh; every one that heareth will laugh with me.", unlockReference: "Genesis 21:6",
            reference: "Genesis 11–23", source: "Genesis (ASV)"),
        CharacterJourney(
            id: "mary", characterId: "mary", title: "Mary's journey", subtitle: "The mother of Jesus", rarity: .rare,
            required: [ChapterSpan("luke", 1...2), ChapterSpan("matthew", 1...2), ChapterSpan("john", 2), ChapterSpan("john", 19), ChapterSpan("acts", 1)],
            stops: [
                JourneyStopData(id: "mary-nazareth", title: "The angel's visit", place: "Nazareth", placeType: "A city of Galilee",
                                spans: [ChapterSpan("luke", 1)],
                                happened: "The angel Gabriel tells Mary she will bear a son and call his name Jesus.", reference: "Luke 1:26–38"),
                JourneyStopData(id: "mary-bethlehem", title: "Bethlehem", place: "Bethlehem", placeType: "The city of David",
                                spans: [ChapterSpan("luke", 2), ChapterSpan("matthew", 2)],
                                happened: "Jesus is born and laid in a manger; shepherds come to see him, and later wise men from the east.",
                                lookedLike: "A manger, because there was no room for them in the inn.", reference: "Luke 2:1–20; Matthew 2:1–12"),
                JourneyStopData(id: "mary-egypt", title: "The flight to Egypt", place: "Egypt", placeType: "A country",
                                spans: [ChapterSpan("matthew", 2)],
                                happened: "Warned in a dream, Joseph takes the young child and his mother by night into Egypt.", reference: "Matthew 2:13–15"),
                JourneyStopData(id: "mary-cana", title: "The wedding at Cana", place: "Cana of Galilee", placeType: "A village",
                                spans: [ChapterSpan("john", 2)],
                                happened: "At a marriage, Mary says to the servants, \u{201C}Whatsoever he saith unto you, do it.\u{201D}",
                                lookedLike: "Six waterpots of stone, set there after the Jews' manner of purifying.", reference: "John 2:1–11"),
                JourneyStopData(id: "mary-cross", title: "At the cross", place: "Golgotha", placeType: "A place outside the city",
                                spans: [ChapterSpan("john", 19)],
                                happened: "Mary stands by the cross; Jesus gives her into the care of the disciple whom he loved.", reference: "John 19:25–27"),
                JourneyStopData(id: "mary-prayer", title: "Praying with the disciples", place: "Jerusalem", placeType: "An upper chamber",
                                spans: [ChapterSpan("acts", 1)],
                                happened: "After the ascension, Mary is with the apostles in the upper chamber, continuing in prayer.", reference: "Acts 1:12–14"),
            ],
            unlockLine: "Behold, the handmaid of the Lord; be it unto me according to thy word.", unlockReference: "Luke 1:38",
            reference: "Luke 1–2; Matthew 1–2; John 2, 19; Acts 1", source: "ASV"),
        CharacterJourney(
            id: "abraham", characterId: "abraham", title: "Abraham's journey", subtitle: "The father of many nations", rarity: .rare,
            required: [ChapterSpan("genesis", 11...25)],
            stops: [
                JourneyStopData(id: "abraham-ur", title: "Ur and Haran", place: "Ur of the Chaldees", placeType: "A city",
                                spans: [ChapterSpan("genesis", 11...12)],
                                happened: "Jehovah says, \u{201C}Get thee out of thy country,\u{201D} and Abram goes, as Jehovah had spoken.", reference: "Genesis 11:31–12:4"),
                JourneyStopData(id: "abraham-canaan", title: "Canaan", place: "The land of Canaan", placeType: "The promised land",
                                spans: [ChapterSpan("genesis", 12...13)],
                                happened: "Abram builds altars in the land; he and Lot part ways, and God promises him all the land he can see.", reference: "Genesis 12:6–13:18"),
                JourneyStopData(id: "abraham-covenant", title: "The covenant", place: "Canaan", placeType: "Under the night sky",
                                spans: [ChapterSpan("genesis", 15...17)],
                                happened: "God promises descendants as many as the stars and makes a covenant; Abram is renamed Abraham.",
                                lookedLike: "Abram brought outside to look toward heaven and number the stars.", reference: "Genesis 15:1–21; 17:1–8"),
                JourneyStopData(id: "abraham-mamre", title: "The visitors at Mamre", place: "The oaks of Mamre", placeType: "A camp by the oaks",
                                spans: [ChapterSpan("genesis", 18)],
                                happened: "Three men come to Abraham's tent, and he hurries to welcome them.",
                                lookedLike: "Abraham sitting in the tent door in the heat of the day.", reference: "Genesis 18:1–15"),
                JourneyStopData(id: "abraham-isaac", title: "Isaac is born", place: "Gerar", placeType: "Where they were sojourning",
                                spans: [ChapterSpan("genesis", 21)],
                                happened: "Isaac is born to Abraham and Sarah in their old age, at the set time God had spoken.", reference: "Genesis 21:1–7"),
                JourneyStopData(id: "abraham-moriah", title: "Mount Moriah", place: "The land of Moriah", placeType: "A mountain",
                                spans: [ChapterSpan("genesis", 22)],
                                happened: "God tests Abraham, and provides a ram caught in a thicket by its horns.", reference: "Genesis 22:1–19"),
                JourneyStopData(id: "abraham-death", title: "His death", place: "Machpelah", placeType: "A family tomb",
                                spans: [ChapterSpan("genesis", 25)],
                                happened: "Abraham dies in a good old age, and Isaac and Ishmael bury him in the cave of Machpelah.", reference: "Genesis 25:7–10"),
            ],
            unlockLine: "And he believed in Jehovah; and he reckoned it to him for righteousness.", unlockReference: "Genesis 15:6",
            reference: "Genesis 11–25", source: "Genesis (ASV)"),
        CharacterJourney(
            id: "solomon", characterId: "solomon", title: "Solomon's journey", subtitle: "Wisdom and the temple", rarity: .rare,
            required: [ChapterSpan("1kings", 1...11), ChapterSpan("2chronicles", 1...9)],
            stops: [
                JourneyStopData(id: "solomon-king", title: "Becoming king", place: "Jerusalem", placeType: "The city of David",
                                spans: [ChapterSpan("1kings", 1...2)],
                                happened: "Solomon is anointed king at Gihon, and David charges him to walk in God's ways.", reference: "1 Kings 1:32–2:4"),
                JourneyStopData(id: "solomon-wisdom", title: "The request for wisdom", place: "Gibeon", placeType: "A high place",
                                spans: [ChapterSpan("1kings", 3)],
                                happened: "In a dream God says, \u{201C}Ask what I shall give thee,\u{201D} and Solomon asks for an understanding heart.", reference: "1 Kings 3:4–15"),
                JourneyStopData(id: "solomon-temple", title: "Building the temple", place: "Jerusalem", placeType: "The house of Jehovah",
                                spans: [ChapterSpan("1kings", 5...8)],
                                happened: "Solomon builds the house of Jehovah and dedicates it with a long prayer.",
                                lookedLike: "Cedar from Lebanon, walls overlaid with gold, and two cherubim of olive-wood.", reference: "1 Kings 5–8"),
                JourneyStopData(id: "solomon-sheba", title: "The queen of Sheba", place: "Jerusalem", placeType: "The king's court",
                                spans: [ChapterSpan("1kings", 10)],
                                happened: "The queen of Sheba comes to prove him with hard questions, and is amazed at his wisdom.", reference: "1 Kings 10:1–13"),
                JourneyStopData(id: "solomon-decline", title: "His decline", place: "Jerusalem", placeType: "The king's court",
                                spans: [ChapterSpan("1kings", 11)],
                                happened: "In his old age Solomon's heart is turned away after other gods.", reference: "1 Kings 11:1–13"),
            ],
            unlockLine: "Give thy servant therefore an understanding heart.", unlockReference: "1 Kings 3:9",
            reference: "1 Kings 1–11; 2 Chronicles 1–9", source: "ASV"),
        CharacterJourney(
            id: "david", characterId: "david", title: "David's journey", subtitle: "Shepherd and king", rarity: .rare,
            required: [ChapterSpan("1samuel", 16...31), book("2samuel"), ChapterSpan("1kings", 1...2)],
            stops: [
                JourneyStopData(id: "david-anointed", title: "Anointed in Bethlehem", place: "Bethlehem", placeType: "A town in Judah",
                                spans: [ChapterSpan("1samuel", 16)],
                                happened: "Samuel anoints David, the youngest of Jesse's sons, who was keeping the sheep.", reference: "1 Samuel 16:1–13"),
                JourneyStopData(id: "david-elah", title: "The valley of Elah", place: "The vale of Elah", placeType: "A valley",
                                spans: [ChapterSpan("1samuel", 17)],
                                happened: "David goes out against Goliath with his sling and five smooth stones, in the name of Jehovah of hosts.", reference: "1 Samuel 17:1–54"),
                JourneyStopData(id: "david-run", title: "On the run from Saul", place: "The wilderness", placeType: "Hills and caves",
                                spans: [ChapterSpan("1samuel", 18...31)],
                                happened: "Saul turns against David, who flees, and twice spares Saul's life.", reference: "1 Samuel 18–31"),
                JourneyStopData(id: "david-hebron", title: "King in Hebron", place: "Hebron", placeType: "A city of Judah",
                                spans: [ChapterSpan("2samuel", 2)],
                                happened: "The men of Judah anoint David king over the house of Judah in Hebron.", reference: "2 Samuel 2:1–4"),
                JourneyStopData(id: "david-zion", title: "The City of David", place: "Jerusalem", placeType: "The stronghold of Zion",
                                spans: [ChapterSpan("2samuel", 5)],
                                happened: "David takes the stronghold of Zion and dwells there; it is called the city of David.", reference: "2 Samuel 5:6–10"),
                JourneyStopData(id: "david-reign", title: "His later reign", place: "Jerusalem", placeType: "The king's city",
                                spans: [ChapterSpan("2samuel", 6...24)],
                                happened: "David brings up the ark, receives God's promise of a lasting house, sins and repents, and faces Absalom's rebellion.",
                                reference: "2 Samuel 6–24"),
                JourneyStopData(id: "david-death", title: "His death", place: "Jerusalem", placeType: "The city of David",
                                spans: [ChapterSpan("1kings", 2)],
                                happened: "David charges Solomon to keep God's ways, and sleeps with his fathers.", reference: "1 Kings 2:1–10"),
            ],
            unlockLine: "I come to thee in the name of Jehovah of hosts.", unlockReference: "1 Samuel 17:45",
            reference: "1 Samuel 16–31; 2 Samuel; 1 Kings 1–2", source: "ASV"),
        CharacterJourney(
            id: "john", characterId: "john", title: "John's journey", subtitle: "The disciple whom Jesus loved", rarity: .rare,
            required: [book("john"), book("1john"), book("2john"), book("3john"), book("revelation")],
            stops: [
                JourneyStopData(id: "john-follow", title: "Following Jesus", place: "Beyond the Jordan", placeType: "Where John was baptizing",
                                spans: [ChapterSpan("john", 1)],
                                happened: "Two disciples hear John the Baptist say \u{201C}Behold, the Lamb of God,\u{201D} and follow Jesus.", reference: "John 1:35–39"),
                JourneyStopData(id: "john-upper", title: "The upper room", place: "Jerusalem", placeType: "A room for supper",
                                spans: [ChapterSpan("john", 13...17)],
                                happened: "Jesus washes the disciples' feet and speaks with them at supper.",
                                lookedLike: "One of the disciples, whom Jesus loved, reclining in Jesus' bosom.", reference: "John 13–17"),
                JourneyStopData(id: "john-cross", title: "At the cross", place: "Golgotha", placeType: "A place outside the city",
                                spans: [ChapterSpan("john", 19)],
                                happened: "The disciple whom Jesus loved stands by the cross, and takes Mary into his home.", reference: "John 19:25–27"),
                JourneyStopData(id: "john-tomb", title: "The empty tomb", place: "A garden tomb", placeType: "A tomb in a garden",
                                spans: [ChapterSpan("john", 20)],
                                happened: "Peter and the other disciple run to the tomb and find the linen cloths lying.", reference: "John 20:1–10"),
                JourneyStopData(id: "john-letters", title: "His letters", place: "To the churches", placeType: "Letters",
                                spans: [book("1john"), book("2john"), book("3john")],
                                happened: "Letters urging believers to love one another, for God is love.", reference: "1 John 4:7–21"),
                JourneyStopData(id: "john-patmos", title: "Patmos", place: "The isle called Patmos", placeType: "An island",
                                spans: [ChapterSpan("revelation", 1)],
                                happened: "On Patmos, John sees one like unto a son of man and is told to write what he sees.", reference: "Revelation 1:9–20"),
                JourneyStopData(id: "john-jerusalem", title: "The New Jerusalem", place: "The holy city", placeType: "A vision",
                                spans: [ChapterSpan("revelation", 21...22)],
                                happened: "John sees a new heaven and a new earth, and the holy city coming down out of heaven from God.",
                                lookedLike: "A city with the glory of God, and a river of water of life, bright as crystal.", reference: "Revelation 21–22"),
            ],
            unlockLine: "Beloved, let us love one another: for love is of God.", unlockReference: "1 John 4:7",
            reference: "John; 1–3 John; Revelation", source: "ASV",
            note: "That the disciple whom Jesus loved, and the writer of the letters and Revelation, are John is church tradition, not stated in these texts. TODO(review): wording."),
        CharacterJourney(
            id: "paul", characterId: "paul", title: "Paul's journey", subtitle: "Apostle to the nations", rarity: .legendary,
            required: [ChapterSpan("acts", 7...28)] + pauline.map { book(BibleCatalog.books[$0].id) },
            stops: [
                JourneyStopData(id: "paul-stephen", title: "Stephen's stoning", place: "Jerusalem", placeType: "Outside the city",
                                spans: [ChapterSpan("acts", 7)],
                                happened: "The witnesses lay down their garments at the feet of a young man named Saul.", reference: "Acts 7:54–8:1"),
                JourneyStopData(id: "paul-damascus", title: "The road to Damascus", place: "Near Damascus", placeType: "A road",
                                spans: [ChapterSpan("acts", 9)],
                                happened: "A light from heaven shines round about Saul, and he hears the voice of Jesus.", reference: "Acts 9:1–19"),
                JourneyStopData(id: "paul-first", title: "First journey", place: "Cyprus and Galatia", placeType: "Islands and cities",
                                spans: [ChapterSpan("acts", 13...14)],
                                happened: "Sent out from Antioch with Barnabas, Paul preaches in Cyprus, Antioch of Pisidia, Iconium, Lystra and Derbe.",
                                reference: "Acts 13–14"),
                JourneyStopData(id: "paul-second", title: "Second journey", place: "Macedonia and Greece", placeType: "Cities",
                                spans: [ChapterSpan("acts", 15...18)],
                                happened: "With Silas, Paul crosses into Macedonia, speaks at Athens and stays a year and six months in Corinth.",
                                reference: "Acts 15:36–18:22"),
                JourneyStopData(id: "paul-third", title: "Third journey", place: "Ephesus", placeType: "A city",
                                spans: [ChapterSpan("acts", 18...21)],
                                happened: "Paul teaches at Ephesus for two years, then sets his face to go to Jerusalem.", reference: "Acts 18:23–21:16"),
                JourneyStopData(id: "paul-trials", title: "Arrest and trials", place: "Jerusalem and Caesarea", placeType: "Courts",
                                spans: [ChapterSpan("acts", 21...26)],
                                happened: "Seized in the temple, Paul speaks before the council, Felix, Festus and King Agrippa.", reference: "Acts 21–26"),
                JourneyStopData(id: "paul-malta", title: "The storm and shipwreck", place: "Melita", placeType: "An island",
                                spans: [ChapterSpan("acts", 27...28)],
                                happened: "After many days of storm the ship is wrecked, and all escape safe to land on Melita.",
                                lookedLike: "The islanders kindling a fire because of the rain and the cold.", reference: "Acts 27:1–28:10"),
                JourneyStopData(id: "paul-rome", title: "Rome", place: "Rome", placeType: "The capital",
                                spans: [ChapterSpan("acts", 28)],
                                happened: "Paul lives two whole years in his own hired dwelling, preaching the kingdom of God.", reference: "Acts 28:16–31"),
                JourneyStopData(id: "paul-letters", title: "His letters", place: "To the churches", placeType: "Letters",
                                spans: pauline.map { book(BibleCatalog.books[$0].id) },
                                happened: "Letters to the churches and to friends, from Romans to Philemon.", reference: "Romans–Philemon"),
            ],
            unlockLine: "I have fought the good fight, I have finished the course, I have kept the faith.", unlockReference: "2 Timothy 4:7",
            reference: "Acts 7–28; Romans–Philemon", source: "ASV"),
        CharacterJourney(
            id: "moses", characterId: "moses", title: "Moses's journey", subtitle: "Out of Egypt", rarity: .legendary,
            required: [book("exodus"), book("leviticus"), book("numbers"), book("deuteronomy")],
            stops: [
                JourneyStopData(id: "moses-nile", title: "The basket on the Nile", place: "Egypt", placeType: "By the river",
                                spans: [ChapterSpan("exodus", 2)],
                                happened: "Hidden in an ark of bulrushes among the flags by the river, the child is found by Pharaoh's daughter.", reference: "Exodus 2:1–10"),
                JourneyStopData(id: "moses-bush", title: "The burning bush", place: "Horeb, the mountain of God", placeType: "A mountain",
                                spans: [ChapterSpan("exodus", 3)],
                                happened: "Out of a bush that burns but is not consumed, God calls Moses to bring his people out of Egypt.",
                                lookedLike: "A bush burning with fire, and the bush was not consumed.", reference: "Exodus 3:1–12"),
                JourneyStopData(id: "moses-plagues", title: "The plagues", place: "Egypt", placeType: "A country",
                                spans: [ChapterSpan("exodus", 7...12)],
                                happened: "Plague after plague falls on Egypt, until the passover night.", reference: "Exodus 7–12"),
                JourneyStopData(id: "moses-sea", title: "Crossing the Red Sea", place: "The Red Sea", placeType: "The sea",
                                spans: [ChapterSpan("exodus", 14)],
                                happened: "The waters are divided, and the children of Israel go through the sea on dry ground.",
                                lookedLike: "The waters a wall on their right hand and on their left.", reference: "Exodus 14:21–31"),
                JourneyStopData(id: "moses-sinai", title: "Mount Sinai", place: "Mount Sinai", placeType: "A mountain",
                                spans: [ChapterSpan("exodus", 19...20)],
                                happened: "God comes down on the mount and speaks the ten commandments.",
                                lookedLike: "The mountain altogether on smoke, and the whole mount quaking greatly.", reference: "Exodus 19–20"),
                JourneyStopData(id: "moses-tabernacle", title: "The tabernacle", place: "The camp", placeType: "A tent of meeting",
                                spans: [ChapterSpan("exodus", 25...40), book("leviticus")],
                                happened: "The tabernacle is made and raised up, and the glory of Jehovah fills it.", reference: "Exodus 25–40; Leviticus"),
                JourneyStopData(id: "moses-wilderness", title: "The wilderness years", place: "The wilderness", placeType: "The desert",
                                spans: [book("numbers")],
                                happened: "Forty years of journeying, from Sinai to the plains of Moab.", reference: "Numbers"),
                JourneyStopData(id: "moses-words", title: "His final words", place: "The plains of Moab", placeType: "Plains by the Jordan",
                                spans: [ChapterSpan("deuteronomy", 1...33)],
                                happened: "Moses speaks to all Israel beyond the Jordan before they go in to the land.", reference: "Deuteronomy 1–33"),
                JourneyStopData(id: "moses-nebo", title: "Mount Nebo", place: "Mount Nebo", placeType: "A mountain",
                                spans: [ChapterSpan("deuteronomy", 34)],
                                happened: "From the top of Pisgah, Jehovah shows Moses all the land; Moses dies there.", reference: "Deuteronomy 34:1–7"),
            ],
            unlockLine: "Fear ye not, stand still, and see the salvation of Jehovah.", unlockReference: "Exodus 14:13",
            reference: "Exodus–Deuteronomy", source: "ASV"),
        CharacterJourney(
            id: "jesus", characterId: "jesus", title: "Jesus's journey", subtitle: "The whole New Testament", rarity: .legendary,
            required: books(39...65),
            stops: [
                JourneyStopData(id: "jesus-birth", title: "Birth in Bethlehem", place: "Bethlehem", placeType: "The city of David",
                                spans: [ChapterSpan("matthew", 1...2), ChapterSpan("luke", 1...2)],
                                happened: "Jesus is born in Bethlehem of Judaea.", reference: "Matthew 1–2; Luke 1–2"),
                JourneyStopData(id: "jesus-baptism", title: "Baptism in the Jordan", place: "The Jordan", placeType: "A river",
                                spans: [ChapterSpan("matthew", 3), ChapterSpan("mark", 1), ChapterSpan("luke", 3)],
                                happened: "John baptizes Jesus, and a voice from heaven says, \u{201C}This is my beloved Son.\u{201D}", reference: "Matthew 3:13–17"),
                JourneyStopData(id: "jesus-mount", title: "The Sermon on the Mount", place: "A mountain in Galilee", placeType: "A hillside",
                                spans: [ChapterSpan("matthew", 5...7)],
                                happened: "Jesus teaches the multitudes: \u{201C}Blessed are the poor in spirit.\u{201D}", reference: "Matthew 5–7"),
                JourneyStopData(id: "jesus-galilee", title: "The Sea of Galilee", place: "The sea of Galilee", placeType: "A lake",
                                spans: [ChapterSpan("mark", 4...6)],
                                happened: "Jesus stills the storm, and comes to his disciples walking on the sea.", reference: "Mark 4:35–41; 6:45–52"),
                JourneyStopData(id: "jesus-cross", title: "The cross", place: "Golgotha", placeType: "A place outside the city",
                                spans: [ChapterSpan("matthew", 27), ChapterSpan("mark", 15), ChapterSpan("luke", 23), ChapterSpan("john", 19)],
                                happened: "Jesus is crucified, and gives up his spirit.", reference: "Matthew 27; Mark 15; Luke 23; John 19"),
                JourneyStopData(id: "jesus-tomb", title: "The empty tomb", place: "A garden tomb", placeType: "A tomb",
                                spans: [ChapterSpan("matthew", 28), ChapterSpan("mark", 16), ChapterSpan("luke", 24), ChapterSpan("john", 20...21)],
                                happened: "\u{201C}He is not here; for he is risen.\u{201D}", reference: "Matthew 28:6"),
                JourneyStopData(id: "jesus-church", title: "The early church", place: "Jerusalem and beyond", placeType: "Cities",
                                spans: [book("acts")],
                                happened: "The Spirit comes at Pentecost, and the word spreads from Jerusalem to Rome.", reference: "Acts"),
                JourneyStopData(id: "jesus-letters", title: "The letters", place: "To the churches", placeType: "Letters",
                                spans: books(44...64),
                                happened: "Letters to the churches, from Romans to Jude.", reference: "Romans–Jude"),
                JourneyStopData(id: "jesus-revelation", title: "Revelation", place: "Patmos and the holy city", placeType: "A vision",
                                spans: [book("revelation")],
                                happened: "\u{201C}Behold, I make all things new.\u{201D}", reference: "Revelation 21:5"),
            ],
            unlockLine: "I am the good shepherd.", unlockReference: "John 10:11",
            reference: "Matthew–Revelation", source: "ASV"),
    ]
}

// MARK: - Progress

/// How far along a journey is, worked out from every read ever recorded.
struct JourneyProgress: Equatable {
    let read: Int
    let required: Int
    /// Stops whose every chapter is read.
    let completedStops: Set<String>
    /// The first stop not yet complete.
    let nextStop: JourneyStopData?
    /// The first unread required chapter.
    let nextChapter: ChapterRef?

    var isComplete: Bool { read >= required }
    var fraction: Double { required == 0 ? 0 : Double(read) / Double(required) }

    static func make(_ journey: CharacterJourney, isRead: (String, Int) -> Bool) -> JourneyProgress {
        let chapters = journey.requiredChapters
        let read = chapters.filter { isRead($0.book, $0.chapter) }.count
        var done: Set<String> = []
        for stop in journey.stops where stop.spans.allSatisfy({ s in s.chapters.allSatisfy { isRead(s.bookID, $0) } }) {
            done.insert(stop.id)
        }
        let next = journey.stops.first { !done.contains($0.id) }
        let firstUnread = (next.map { stop in stop.spans.flatMap { s in s.chapters.map { (s.bookID, $0) } } } ?? [])
            .first { !isRead($0.0, $0.1) } ?? chapters.first { !isRead($0.book, $0.chapter) }.map { ($0.book, $0.chapter) }
        return JourneyProgress(read: read, required: chapters.count, completedStops: done, nextStop: next,
                               nextChapter: firstUnread.map { ChapterRef(bookID: $0.0, chapter: $0.1) })
    }
}

extension GameProgress {
    func journeyProgress(_ journey: CharacterJourney) -> JourneyProgress {
        JourneyProgress.make(journey) { isRead($0, chapter: $1) }
    }

    /// Characters whose journeys are complete.
    var unlockedJourneys: [CharacterJourney] {
        CharacterJourneys.all.filter { journeyProgress($0).isComplete }
    }
}
