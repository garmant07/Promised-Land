import Foundation

/// One easy multiple-choice question about a chapter, asked after reading it. A right answer
/// counts the chapter; a wrong one just says "Have another look". Content: unreviewed (see
/// REVIEW.md). Chapters without a question get a gentle reflection prompt instead.
struct ChapterQuestion: ReviewableContent, Equatable {
    let bookID: String
    let chapter: Int
    let prompt: String
    let options: [String]
    let answer: Int
    /// The verse the answer comes from.
    let reference: String
    var source: String { "\(reference) (ASV)" }
    var reviewed = false
}

enum QuestionData {
    /// The question for a chapter (only reviewed ones in Release builds).
    static func question(bookID: String, chapter: Int) -> ChapterQuestion? {
        all.first { $0.bookID == bookID && $0.chapter == chapter }.flatMap { ContentGate.isVisible($0) ? $0 : nil }
    }

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
