import Foundation

/// A chapter-specific reflection. Gated: only reviewed entries show in Release builds.
struct ChapterReflection: ReviewableContent {
    let bookID: String
    let chapter: Int
    /// One or two questions.
    let prompts: [String]
    let reference: String
    let source: String
    var reviewed = false
}

enum ReflectionData {
    /// General prompts (not claims about the text), used when no chapter-specific prompt exists.
    static let general = [
        "What stood out to you?",
        "How could you live this out today?",
    ]

    /// Prompts for a chapter: chapter-specific if a visible one exists, otherwise the general pair.
    static func prompts(bookID: String, chapter: Int) -> (prompts: [String], specific: ChapterReflection?) {
        if let entry = ContentGate.visible(chapterSpecific).first(where: { $0.bookID == bookID && $0.chapter == chapter }) {
            return (entry.prompts, entry)
        }
        return (general, nil)
    }

    // CONTENT RULE: each quotation is from the ASV text of that chapter; all unreviewed.
    static let chapterSpecific: [ChapterReflection] = [
        ChapterReflection(bookID: "genesis", chapter: 1,
                          prompts: ["God saw that it was good. Where have you noticed goodness in creation this week?",
                                    "What does it mean to you that people are made in God's image?"],
                          reference: "Genesis 1:27, 31", source: "Genesis 1 (ASV)"),
        ChapterReflection(bookID: "exodus", chapter: 3,
                          prompts: ["Moses turned aside to see the bush. What might you need to slow down and notice?",
                                    "Moses asked, \"Who am I?\" What makes you hesitate when you feel called to something?"],
                          reference: "Exodus 3:3, 11", source: "Exodus 3 (ASV)"),
        ChapterReflection(bookID: "ruth", chapter: 1,
                          prompts: ["Ruth said, \"Whither thou goest, I will go.\" Who could you stand alongside this week?",
                                    "What does loyal love look like in one of your relationships?"],
                          reference: "Ruth 1:16", source: "Ruth 1 (ASV)"),
        ChapterReflection(bookID: "psalms", chapter: 23,
                          prompts: ["Where do you need the Shepherd to lead you right now?",
                                    "What are your \"still waters\": places where your soul is restored?"],
                          reference: "Psalm 23:1–3", source: "Psalm 23 (ASV)"),
        ChapterReflection(bookID: "daniel", chapter: 6,
                          prompts: ["Daniel kept praying as he did aforetime, even when it was forbidden. What habit of faith do you want to keep steady?"],
                          reference: "Daniel 6:10", source: "Daniel 6 (ASV)"),
        ChapterReflection(bookID: "jonah", chapter: 1,
                          prompts: ["Jonah fled from what he was asked to do. Is there something you're avoiding?"],
                          reference: "Jonah 1:3", source: "Jonah 1 (ASV)"),
        ChapterReflection(bookID: "mark", chapter: 4,
                          prompts: ["\"Why are ye fearful?\" What storm in your life could you bring to Jesus?"],
                          reference: "Mark 4:40", source: "Mark 4 (ASV)"),
        ChapterReflection(bookID: "john", chapter: 15,
                          prompts: ["\"Abide in me.\" What helps you stay close to God day to day?",
                                    "What fruit would you love to see grow in your life?"],
                          reference: "John 15:4–5", source: "John 15 (ASV)"),
    ]
}
