import Foundation

// MARK: - Models

struct QuizQuestion: Identifiable, Hashable {
    let id = UUID()
    let prompt: String
    let options: [String]
    let answerIndex: Int
}

struct MemoryVerse: Hashable {
    let reference: String
    let text: String

    /// Words in order, used by the "rebuild the verse" exercise.
    var words: [String] { text.split(separator: " ").map(String.init) }
}

/// A book's quiz and memory verse. Only books with sample text have one so far;
/// every other book shows "Quiz coming soon".
struct BookLearning {
    let quiz: [QuizQuestion]
    let memoryVerse: MemoryVerse

    /// Number of correct answers needed to pass the quiz.
    var passMark: Int { max(1, quiz.count - 1) }
}

enum LearningData {
    static func forBook(_ bookID: String) -> BookLearning? { content[bookID] }

    private static let content: [String: BookLearning] = [
        "genesis": BookLearning(
            quiz: [
                QuizQuestion(prompt: "What did God create in the beginning?",
                             options: ["The heavens and the earth", "The garden of Eden", "The sea and the stars"],
                             answerIndex: 0),
                QuizQuestion(prompt: "What did God call the light?",
                             options: ["Morning", "Day", "Glory"],
                             answerIndex: 1),
                QuizQuestion(prompt: "Which day did God bless and hallow?",
                             options: ["The first day", "The third day", "The seventh day"],
                             answerIndex: 2),
            ],
            memoryVerse: MemoryVerse(reference: "Genesis 1:1",
                                text: "In the beginning God created the heavens and the earth.")
        ),
        "exodus": BookLearning(
            quiz: [
                QuizQuestion(prompt: "Whose flock was Moses keeping?",
                             options: ["Pharaoh's", "Jethro's", "Aaron's"],
                             answerIndex: 1),
                QuizQuestion(prompt: "What was strange about the burning bush?",
                             options: ["It was not consumed", "It spoke in a whisper", "It burned blue"],
                             answerIndex: 0),
                QuizQuestion(prompt: "Where did God bring his people out of?",
                             options: ["Babylon", "Moab", "The land of Egypt"],
                             answerIndex: 2),
            ],
            memoryVerse: MemoryVerse(reference: "Exodus 20:3",
                                text: "Thou shalt have no other gods before me.")
        ),
        "ruth": BookLearning(
            quiz: [
                QuizQuestion(prompt: "Why did the family leave Beth-lehem-judah?",
                             options: ["A war", "A famine", "A flood"],
                             answerIndex: 1),
                QuizQuestion(prompt: "Who was the mighty man of wealth?",
                             options: ["Boaz", "Elimelech", "Jethro"],
                             answerIndex: 0),
                QuizQuestion(prompt: "Where did Ruth go to glean?",
                             options: ["The vineyard", "The temple", "The field"],
                             answerIndex: 2),
            ],
            memoryVerse: MemoryVerse(reference: "Ruth 1:16",
                                text: "whither thou goest, I will go; and where thou lodgest, I will lodge;")
        ),
        "psalms": BookLearning(
            quiz: [
                QuizQuestion(prompt: "In Psalm 1, the blessed man is like a…",
                             options: ["Lion in the hills", "Tree planted by streams of water", "Star in the sky"],
                             answerIndex: 1),
                QuizQuestion(prompt: "Complete: \"Jehovah is my…\"",
                             options: ["Shepherd", "King", "Fortress"],
                             answerIndex: 0),
                QuizQuestion(prompt: "How should we serve Jehovah, says Psalm 100?",
                             options: ["With fear", "With silence", "With gladness"],
                             answerIndex: 2),
            ],
            memoryVerse: MemoryVerse(reference: "Psalm 23:1",
                                text: "Jehovah is my shepherd; I shall not want.")
        ),
        "daniel": BookLearning(
            quiz: [
                QuizQuestion(prompt: "Which king came to Jerusalem and besieged it?",
                             options: ["Nebuchadnezzar", "Darius", "Pharaoh"],
                             answerIndex: 0),
                QuizQuestion(prompt: "How many times a day did Daniel pray?",
                             options: ["Once", "Three times", "Seven times"],
                             answerIndex: 1),
                QuizQuestion(prompt: "What did God's angel shut?",
                             options: ["The city gates", "The windows", "The lions' mouths"],
                             answerIndex: 2),
            ],
            memoryVerse: MemoryVerse(reference: "Daniel 6:22",
                                text: "My God hath sent his angel, and hath shut the lions' mouths,")
        ),
        "john": BookLearning(
            quiz: [
                QuizQuestion(prompt: "In the beginning was the…",
                             options: ["Light", "Word", "Spirit"],
                             answerIndex: 1),
                QuizQuestion(prompt: "In him was life, and the life was…",
                             options: ["The light of men", "The bread of heaven", "The way home"],
                             answerIndex: 0),
                QuizQuestion(prompt: "Why did God send his Son, says John 3:17?",
                             options: ["To judge the world", "To build a temple", "That the world should be saved"],
                             answerIndex: 2),
            ],
            memoryVerse: MemoryVerse(reference: "John 3:16",
                                text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth on him should not perish, but have eternal life.")
        ),
    ]
}
