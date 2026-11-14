import Foundation

/// One easy multiple-choice question about a chapter, asked after reading it. A right answer
/// counts the chapter; a wrong one just says "Have another look". Content: unreviewed (see
/// REVIEW.md). Chapters without a question get a gentle reflection prompt instead.
nonisolated enum QuestionDifficulty: String, Equatable {
    case easy
    case medium
    case hard
}

nonisolated enum QuestionFormat: String, Equatable {
    case multipleChoice
    case fillInBlank
    case trueFalse
}

struct ChapterQuestion: ReviewableContent, Equatable {
    let bookID: String
    let chapter: Int
    let prompt: String
    let options: [String]
    let answer: Int
    /// The verse the answer comes from.
    let reference: String
    /// The translation the question was written from (hand-written ones: ASV).
    var translation = "ASV"
    var source: String { "\(reference) (\(translation))" }
    var reviewed = false
    var lesson: String? = nil
    var difficulty: QuestionDifficulty? = nil
    var format: QuestionFormat = .multipleChoice
}

enum QuestionData {
    /// The question for a chapter (only reviewed ones in Release builds).
    static func question(bookID: String, chapter: Int) -> ChapterQuestion? {
        all.first { $0.bookID == bookID && $0.chapter == chapter }.flatMap { ContentGate.isVisible($0) ? $0 : nil }
    }

    /// Questions for a chapter. A bundled set takes priority; otherwise this returns
    /// the existing hand-written or generated question as a one-item array.
    static func questions(bookID: String, chapter: Int) -> [ChapterQuestion] {
        let set = bundledSets.first { $0.first?.bookID == bookID && $0.first?.chapter == chapter } ?? []
        if !set.isEmpty {
            return ContentGate.visible(set)
        }
        return question(bookID: bookID, chapter: chapter).map { [$0] } ?? []
    }

    /// The hand-written question set, or one made from the chapter's text on the device
    /// (cached or bundled; never fetched just for this), or an empty array for reflections.
    static func questions(bookID: String, chapter: Int, service: any BibleService, translation: BibleTranslation?) -> [ChapterQuestion] {
        let set = questions(bookID: bookID, chapter: chapter)
        if !set.isEmpty { return set }
        guard let text = service.cachedChapter(bookID: bookID, chapter: chapter, translation: translation),
              let book = BibleCatalog.book(id: bookID),
              let generated = TextQuestion.make(from: text, bookName: book.name) else { return [] }
        return [generated]
    }

    /// The hand-written question, or one made from the chapter's text on the device (cached or
    /// bundled; never fetched just for this), or nil (then a reflection prompt is used).
    static func question(bookID: String, chapter: Int, service: any BibleService, translation: BibleTranslation?) -> ChapterQuestion? {
        questions(bookID: bookID, chapter: chapter, service: service, translation: translation).first
    }

    private static let bundledSets: [[ChapterQuestion]] = [
        [
            ChapterQuestion(bookID: "genesis", chapter: 1,
                            prompt: "“In the beginning God ____ the heavens and the earth.” (1:1)",
                            options: ["named", "created", "blessed", "visited"],
                            answer: 1, reference: "Genesis 1:1", reviewed: true,
                            lesson: "God is the Creator and everything else is created. That line between Creator and creature runs through the whole Bible.",
                            difficulty: .easy, format: .fillInBlank),
            ChapterQuestion(bookID: "genesis", chapter: 1,
                            prompt: "God created both male and female in His image. (1:27)",
                            options: ["True", "False"],
                            answer: 0, reference: "Genesis 1:27", reviewed: true,
                            lesson: "Men and women carry God’s image equally, and that gives every person dignity and worth.",
                            difficulty: .easy, format: .trueFalse),
            ChapterQuestion(bookID: "genesis", chapter: 1,
                            prompt: "How did God make light? (1:3)",
                            options: ["He gathered it from the stars", "He took it from the sun", "Angels made it for Him", "He spoke, and it was"],
                            answer: 3, reference: "Genesis 1:3", reviewed: true,
                            lesson: "God's word has power. When He speaks, it happens, so His words to us can be trusted.",
                            difficulty: .easy, format: .multipleChoice),
            ChapterQuestion(bookID: "genesis", chapter: 1,
                            prompt: "God made light on Day 1 but did not make the sun until Day 4. What can we learn from that?",
                            options: ["Day 1 was really nighttime", "The sun is not important", "God is the source of light, and the sun is just something He made", "The writer made a mistake"],
                            answer: 2, reference: "Genesis 1:3–16", reviewed: true,
                            lesson: "The nations around Israel worshiped the sun. Genesis shows it is a created thing God uses, not a god.",
                            difficulty: .medium, format: .multipleChoice),
            ChapterQuestion(bookID: "genesis", chapter: 1,
                            prompt: "After describing the completed creation, what verdict does Genesis 1 give? (1:31)",
                            options: ["Creation was evil", "God regretted creating", "Everything God had made was very good", "Only people were good"],
                            answer: 2, reference: "Genesis 1:31", reviewed: true,
                            lesson: "The verdict concerns the whole creation, including humanity, and affirms the goodness of God's completed work.",
                            difficulty: .hard, format: .multipleChoice)
        ],
        [
            ChapterQuestion(bookID: "genesis", chapter: 2,
                            prompt: "“It is not good for the man to be ____.” (2:18)",
                            options: ["hungry", "quiet", "alone", "tired"],
                            answer: 2, reference: "Genesis 2:18", reviewed: true,
                            lesson: "Loneliness is the first thing God calls “not good.” We were made for relationship with God and with each other.",
                            difficulty: .easy, format: .fillInBlank),
            ChapterQuestion(bookID: "genesis", chapter: 2,
                            prompt: "God gave Adam the job of working the garden and taking care of it. (2:15)",
                            options: ["True", "False"],
                            answer: 0, reference: "Genesis 2:15", reviewed: true,
                            lesson: "Work was part of God’s good design before sin ever entered the world.",
                            difficulty: .easy, format: .trueFalse),
            ChapterQuestion(bookID: "genesis", chapter: 2,
                            prompt: "What did God form the man from? (2:7)",
                            options: ["A tree", "Stone", "The dust of the ground", "Water"],
                            answer: 2, reference: "Genesis 2:7", reviewed: true,
                            lesson: "God formed the man from dust and breathed life into him.",
                            difficulty: .easy, format: .multipleChoice),
            ChapterQuestion(bookID: "genesis", chapter: 2,
                            prompt: "God calls the woman a “helper” (ezer) for the man (2:18). Where else does the Old Testament use that same word?",
                            options: ["For slaves", "For farm animals", "For servants", "For God helping Israel"],
                            answer: 3, reference: "Genesis 2:18", reviewed: true,
                            lesson: "Ezer is often used of God Himself, so “helper” does not mean lesser. Man and woman were made as partners.",
                            difficulty: .medium, format: .multipleChoice),
            ChapterQuestion(bookID: "genesis", chapter: 2,
                            prompt: "God rested on the seventh day and made it holy (2:2–3). Why did He rest?",
                            options: ["He ran out of ideas", "His work was finished, and He set a pattern of rest for His people", "He was tired", "He was waiting for Adam"],
                            answer: 1, reference: "Genesis 2:2–3", reviewed: true,
                            lesson: "God doesn’t get tired. The Sabbath is a sign of trust: we stop working and remember that God provides.",
                            difficulty: .hard, format: .multipleChoice)
        ],
        [
            ChapterQuestion(bookID: "genesis", chapter: 3,
                            prompt: "After Adam and Eve sinned, God called to the man, “Where are ____?” (3:9)",
                            options: ["they", "we", "she", "you"],
                            answer: 3, reference: "Genesis 3:9", reviewed: true,
                            lesson: "God already knew the answer. He asked to draw Adam back into relationship. God pursues us even after we fail.",
                            difficulty: .easy, format: .fillInBlank),
            ChapterQuestion(bookID: "genesis", chapter: 3,
                            prompt: "Genesis 3:6 explicitly says Adam was absent when Eve gave him the fruit. (3:6)",
                            options: ["True", "False"],
                            answer: 1, reference: "Genesis 3:6", reviewed: true,
                            lesson: "It describes her husband as with her when she gave him the fruit. The verse does not specify every detail of his location throughout the earlier conversation.",
                            difficulty: .medium, format: .trueFalse),
            ChapterQuestion(bookID: "genesis", chapter: 3,
                            prompt: "God told Adam not to eat from the tree. What did Eve say God had commanded? (3:3)",
                            options: ["Only Adam can’t eat it", "You may eat it on the seventh day", "Exactly what God said", "Don’t eat it, and don’t even touch it"],
                            answer: 3, reference: "Genesis 3:3", reviewed: true,
                            lesson: "Eve added “don’t touch it” to God’s words. It matters to know what God actually said.",
                            difficulty: .medium, format: .multipleChoice),
            ChapterQuestion(bookID: "genesis", chapter: 3,
                            prompt: "What three things did Eve do with the fruit, in order? (3:6)",
                            options: ["Heard, ran, hid", "Asked, waited, ate", "Saw, took, ate", "Smelled, touched, threw"],
                            answer: 2, reference: "Genesis 3:6", reviewed: true,
                            lesson: "The same pattern shows up again with Achan and with David. Sin often starts with what we let ourselves look at.",
                            difficulty: .medium, format: .multipleChoice),
            ChapterQuestion(bookID: "genesis", chapter: 3,
                            prompt: "God told the serpent that the woman’s offspring would crush its head (3:15). How have Christians understood this promise?",
                            options: ["The first promise of a rescuer who would defeat evil, pointing to Jesus", "A rule for farming", "A warning about snakes", "A curse on Eve"],
                            answer: 0, reference: "Genesis 3:15", reviewed: true,
                            lesson: "In the same moment He judges sin, God promises a way back. The hope of the whole Bible starts here.",
                            difficulty: .hard, format: .multipleChoice)
        ]
    ]


    private static func q(_ book: String, _ chapter: Int, _ prompt: String, _ options: [String], _ answer: Int, _ ref: String) -> ChapterQuestion {
        ChapterQuestion(bookID: book, chapter: chapter, prompt: prompt, options: options, answer: answer, reference: ref)
    }

    static let all: [ChapterQuestion] = [
        // Chapters with bundled text
        q("genesis", 1, "What did God create in the beginning?", ["The heavens and the earth", "The garden of Eden", "The sea and the stars"], 0, "Genesis 1:1"),
        q("genesis", 2, "What did God do on the seventh day?", ["He rested", "He made the animals", "He planted a garden"], 0, "Genesis 2:2"),
        q("genesis", 3, "Who spoke to the woman in the garden?", ["An angel", "The serpent", "Adam"], 1, "Genesis 3:1"),
        q("exodus", 3, "What was strange about the bush Moses saw?", ["It burned but was not consumed", "It was made of gold", "It sang"], 0, "Exodus 3:2"),
        q("exodus", 20, "How many days are given for labour before the sabbath?", ["Six", "Three", "Ten"], 0, "Exodus 20:9"),
        q("ruth", 1, "Who said, \u{201C}Whither thou goest, I will go\u{201D}?", ["Naomi", "Ruth", "Orpah"], 1, "Ruth 1:16"),
        q("ruth", 2, "Whose field did Ruth glean in?", ["Boaz's", "Elimelech's", "Jesse's"], 0, "Ruth 2:3"),
        q("ruth", 3, "Where did Ruth go to find Boaz at night?", ["The threshing-floor", "The city gate", "The well"], 0, "Ruth 3:3"),
        q("ruth", 4, "What was the name of Ruth and Boaz's son?", ["Obed", "Jesse", "David"], 0, "Ruth 4:17"),
        q("psalms", 1, "The blessed man is like a tree planted by what?", ["The streams of water", "The temple", "The mountains"], 0, "Psalm 1:3"),
        q("psalms", 23, "Who is called \u{201C}my shepherd\u{201D}?", ["David", "Jehovah", "Moses"], 1, "Psalm 23:1"),
        q("psalms", 100, "How are we told to come before his presence?", ["With singing", "In silence", "With gold"], 0, "Psalm 100:2"),
        q("daniel", 1, "What did Daniel ask to eat instead of the king's food?", ["Pulse (vegetables)", "Bread and honey", "Fish"], 0, "Daniel 1:12"),
        q("daniel", 6, "Where was Daniel put?", ["In the den of lions", "In a fiery furnace", "In a dungeon by the river"], 0, "Daniel 6:16"),
        q("john", 1, "\u{201C}In the beginning was the ___.\u{201D}", ["Light", "Word", "Law"], 1, "John 1:1"),
        q("john", 3, "Who came to Jesus by night?", ["Nicodemus", "Peter", "Zacchaeus"], 0, "John 3:1–2"),
        q("john", 15, "\u{201C}I am the true ___.\u{201D}", ["vine", "shepherd", "door"], 0, "John 15:1"),
        // Well-known chapters (read in your own Bible)
        q("genesis", 6, "What was Noah told to build?", ["An ark", "A tower", "An altar of gold"], 0, "Genesis 6:14"),
        q("genesis", 12, "Who was told to leave his country for a land God would show him?", ["Abram", "Noah", "Jacob"], 0, "Genesis 12:1"),
        q("exodus", 14, "What did the waters of the sea do for Israel?", ["They were divided", "They turned to blood", "They froze"], 0, "Exodus 14:21"),
        q("1samuel", 17, "How many smooth stones did David choose?", ["Five", "Three", "Seven"], 0, "1 Samuel 17:40"),
        q("daniel", 3, "Into what were the three men cast?", ["A burning fiery furnace", "A den of lions", "The sea"], 0, "Daniel 3:20"),
        q("jonah", 1, "What swallowed Jonah?", ["A great fish", "A lion", "The earth"], 0, "Jonah 1:17"),
        q("jonah", 3, "To which city did Jonah go to preach?", ["Nineveh", "Tarshish", "Joppa"], 0, "Jonah 3:3"),
        q("matthew", 2, "What led the wise men?", ["A star", "An angel", "A cloud"], 0, "Matthew 2:9"),
        q("mark", 4, "What did Jesus calm?", ["The wind and the sea", "A crowd", "A fire"], 0, "Mark 4:39"),
        q("luke", 2, "Where was the baby laid?", ["In a manger", "In a boat", "In the temple"], 0, "Luke 2:7"),
        q("luke", 15, "How many sheep did the man have before one was lost?", ["A hundred", "Ten", "Twelve"], 0, "Luke 15:4"),
        q("john", 2, "At the wedding in Cana, water was made into what?", ["Wine", "Milk", "Oil"], 0, "John 2:9"),
        q("john", 11, "Whom did Jesus raise from the dead in this chapter?", ["Lazarus", "Jairus's daughter", "Dorcas"], 0, "John 11:43–44"),
        q("acts", 2, "What day had come when they were all together?", ["The day of Pentecost", "The sabbath", "The Passover"], 0, "Acts 2:1"),
        q("acts", 9, "On the road to which city did Saul see a light from heaven?", ["Damascus", "Rome", "Jericho"], 0, "Acts 9:3"),
        q("1corinthians", 13, "Which is called the greatest of faith, hope and love?", ["Love", "Faith", "Hope"], 0, "1 Corinthians 13:13"),
        q("revelation", 21, "What did John see coming down out of heaven?", ["The holy city, new Jerusalem", "A ladder", "A great ship"], 0, "Revelation 21:2"),
    ]
}
