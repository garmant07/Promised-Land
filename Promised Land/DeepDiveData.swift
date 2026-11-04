import Foundation
import SwiftUI

/// A verse deep dive: context, genre, key words, themes and cross-references.
/// Gated like all biblical content: only reviewed entries show in Release builds.
struct DeepDive: Identifiable, ReviewableContent {
    let bookID: String
    let chapter: Int
    let verse: Int
    let context: String
    let genre: String
    let keyWords: [String]
    let themes: [String]
    let crossReferences: [String]
    let reference: String
    let source: String
    var reviewed = false

    var id: String { "\(bookID) \(chapter):\(verse)" }
}

enum DeepDiveData {
    static func entry(bookID: String, chapter: Int, verse: Int) -> DeepDive? {
        ContentGate.visible(all).first { $0.bookID == bookID && $0.chapter == chapter && $0.verse == verse }
    }

    // CONTENT RULE: examples only, all unreviewed. Key words are English (ASV) words;
    // original-language notes are deliberately left out until reviewed sources are chosen.
    // TODO(review): add original-language word studies with cited sources.
    static let all: [DeepDive] = [
        DeepDive(bookID: "genesis", chapter: 1, verse: 1,
                 context: "The first verse of the Bible, opening the account of creation (Genesis 1:1–2:3).",
                 genre: "Narrative, at the start of the Pentateuch",
                 keyWords: ["beginning", "created", "heavens and the earth"],
                 themes: ["Creation", "God as Creator"],
                 crossReferences: ["John 1:1–3", "Hebrews 11:3", "Psalm 33:6"],
                 reference: "Genesis 1:1", source: "Genesis 1 (ASV)"),
        DeepDive(bookID: "ruth", chapter: 1, verse: 16,
                 context: "Ruth, a Moabite widow, refuses to leave her mother-in-law Naomi as Naomi returns to Bethlehem.",
                 genre: "Narrative",
                 keyWords: ["whither thou goest", "thy people", "thy God"],
                 themes: ["Loyal love", "Belonging"],
                 crossReferences: ["Ruth 2:11–12", "Matthew 1:5"],
                 reference: "Ruth 1:16", source: "Ruth 1–2 (ASV); Matthew 1 (ASV)"),
        DeepDive(bookID: "psalms", chapter: 23, verse: 1,
                 context: "A psalm headed \"A Psalm of David\", picturing God as a shepherd caring for his sheep.",
                 genre: "Poetry (psalm)",
                 keyWords: ["Jehovah", "shepherd", "want"],
                 themes: ["Trust", "Provision", "Guidance"],
                 crossReferences: ["John 10:11", "Ezekiel 34:11–15", "Isaiah 40:11"],
                 reference: "Psalm 23:1", source: "Psalm 23 (ASV)"),
        DeepDive(bookID: "john", chapter: 1, verse: 1,
                 context: "The opening (prologue) of John's Gospel, John 1:1–18, echoing the first words of Genesis.",
                 genre: "Gospel",
                 keyWords: ["beginning", "Word", "with God"],
                 themes: ["Who Jesus is", "Creation"],
                 crossReferences: ["Genesis 1:1", "John 1:14", "1 John 1:1"],
                 reference: "John 1:1", source: "John 1 (ASV)"),
        DeepDive(bookID: "john", chapter: 3, verse: 16,
                 context: "Part of Jesus' conversation with Nicodemus, a Pharisee who came to him by night (John 3:1–21).",
                 genre: "Gospel",
                 keyWords: ["loved", "only begotten Son", "eternal life"],
                 themes: ["God's love", "Salvation"],
                 crossReferences: ["Romans 5:8", "1 John 4:9–10"],
                 reference: "John 3:16", source: "John 3 (ASV)"),
    ]
}


/// The deep dive for one verse.
struct DeepDiveSheet: View {
    let dive: DeepDive
    let verseText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Text(dive.reference)
                            .font(.serifTitle(.title2))
                            .foregroundStyle(Color.bodyText)
                        DraftBadge(item: dive)
                    }
                    Text("\u{201C}\(verseText)\u{201D}")
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(Color.secondaryText)
                    section("Context") { Text(dive.context) }
                    section("Genre") { Text(dive.genre) }
                    section("Key words") { chips(dive.keyWords) }
                    section("Themes") { chips(dive.themes) }
                    section("Cross-references") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(dive.crossReferences, id: \.self) { Label($0, systemImage: "arrow.turn.down.right") }
                        }
                    }
                    Text("Source: \(dive.source)")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Deep dive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.serifTitle(.title3)).foregroundStyle(Color.bodyText)
            content().foregroundStyle(Color.bodyText)
        }
        .cardStyle()
    }

    private func chips(_ items: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primaryBrown)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.sand, in: Capsule())
            }
        }
    }
}
