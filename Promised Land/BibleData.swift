import Foundation

// MARK: - Text models

struct Verse: Identifiable, Hashable {
    let number: Int
    let text: String
    var id: Int { number }
}

struct Chapter: Identifiable, Hashable {
    let number: Int
    let verses: [Verse]
    var id: Int { number }
}

// MARK: - Sample text
//
// American Standard Version (1901) — public domain.
//
// NOTE: This is a SMALL SAMPLE. Only six books have any text, each with a few
// chapters, and each chapter only a few of its verses. Every other chapter in
// the catalogue (BibleCatalog.swift) shows "Text coming soon" in the reader.
// The full ASV text will be added later (still bundled locally, no network).

enum SampleText {
    /// The bundled verses for a chapter, or nil if that chapter has no text yet.
    static func verses(book bookID: String, chapter: Int) -> [Verse]? {
        chapters[bookID]?.first { $0.number == chapter }?.verses
    }

    static let chapters: [String: [Chapter]] = [
        "genesis": [
            Chapter(number: 1, verses: [
                Verse(number: 1, text: "In the beginning God created the heavens and the earth."),
                Verse(number: 2, text: "And the earth was waste and void; and darkness was upon the face of the deep: and the Spirit of God moved upon the face of the waters."),
                Verse(number: 3, text: "And God said, Let there be light: and there was light."),
                Verse(number: 4, text: "And God saw the light, that it was good: and God divided the light from the darkness."),
                Verse(number: 5, text: "And God called the light Day, and the darkness he called Night. And there was evening and there was morning, one day."),
            ]),
            Chapter(number: 2, verses: [
                Verse(number: 1, text: "And the heavens and the earth were finished, and all the host of them."),
                Verse(number: 2, text: "And on the seventh day God finished his work which he had made; and he rested on the seventh day from all his work which he had made."),
                Verse(number: 3, text: "And God blessed the seventh day, and hallowed it; because that in it he rested from all his work which God had created and made."),
            ]),
        ],

        "exodus": [
            Chapter(number: 3, verses: [
                Verse(number: 1, text: "Now Moses was keeping the flock of Jethro his father-in-law, the priest of Midian: and he led the flock to the back of the wilderness, and came to the mountain of God, unto Horeb."),
                Verse(number: 2, text: "And the angel of Jehovah appeared unto him in a flame of fire out of the midst of a bush: and he looked, and, behold, the bush burned with fire, and the bush was not consumed."),
                Verse(number: 3, text: "And Moses said, I will turn aside now, and see this great sight, why the bush is not burnt."),
            ]),
            Chapter(number: 20, verses: [
                Verse(number: 1, text: "And God spake all these words, saying,"),
                Verse(number: 2, text: "I am Jehovah thy God, who brought thee out of the land of Egypt, out of the house of bondage."),
                Verse(number: 3, text: "Thou shalt have no other gods before me."),
            ]),
        ],

        "ruth": [
            Chapter(number: 1, verses: [
                Verse(number: 1, text: "And it came to pass in the days when the judges judged, that there was a famine in the land. And a certain man of Beth-lehem-judah went to sojourn in the country of Moab, he, and his wife, and his two sons."),
                Verse(number: 16, text: "And Ruth said, Entreat me not to leave thee, and to return from following after thee, for whither thou goest, I will go; and where thou lodgest, I will lodge; thy people shall be my people, and thy God my God;"),
                Verse(number: 17, text: "where thou diest, will I die, and there will I be buried: Jehovah do so to me, and more also, if aught but death part thee and me."),
            ]),
            Chapter(number: 2, verses: [
                Verse(number: 1, text: "And Naomi had a kinsman of her husband's, a mighty man of wealth, of the family of Elimelech; and his name was Boaz."),
                Verse(number: 2, text: "And Ruth the Moabitess said unto Naomi, Let me now go to the field, and glean among the ears of grain after him in whose sight I shall find favor. And she said unto her, Go, my daughter."),
                Verse(number: 3, text: "And she went, and came and gleaned in the field after the reapers: and her hap was to light on the portion of the field belonging unto Boaz, who was of the family of Elimelech."),
            ]),
        ],

        "psalms": [
            Chapter(number: 1, verses: [
                Verse(number: 1, text: "Blessed is the man that walketh not in the counsel of the wicked, Nor standeth in the way of sinners, Nor sitteth in the seat of scoffers:"),
                Verse(number: 2, text: "But his delight is in the law of Jehovah; And on his law doth he meditate day and night."),
                Verse(number: 3, text: "And he shall be like a tree planted by the streams of water, That bringeth forth its fruit in its season, Whose leaf also doth not wither; And whatsoever he doeth shall prosper."),
            ]),
            Chapter(number: 23, verses: [
                Verse(number: 1, text: "Jehovah is my shepherd; I shall not want."),
                Verse(number: 2, text: "He maketh me to lie down in green pastures; He leadeth me beside still waters."),
                Verse(number: 3, text: "He restoreth my soul: He guideth me in the paths of righteousness for his name's sake."),
                Verse(number: 4, text: "Yea, though I walk through the valley of the shadow of death, I will fear no evil; for thou art with me; Thy rod and thy staff, they comfort me."),
            ]),
            Chapter(number: 100, verses: [
                Verse(number: 1, text: "Make a joyful noise unto Jehovah, all ye lands."),
                Verse(number: 2, text: "Serve Jehovah with gladness: Come before his presence with singing."),
                Verse(number: 3, text: "Know ye that Jehovah, he is God: It is he that hath made us, and we are his; We are his people, and the sheep of his pasture."),
            ]),
        ],

        "daniel": [
            Chapter(number: 1, verses: [
                Verse(number: 1, text: "In the third year of the reign of Jehoiakim king of Judah came Nebuchadnezzar king of Babylon unto Jerusalem, and besieged it."),
                Verse(number: 8, text: "But Daniel purposed in his heart that he would not defile himself with the king's dainties, nor with the wine which he drank: therefore he requested of the prince of the eunuchs that he might not defile himself."),
            ]),
            Chapter(number: 6, verses: [
                Verse(number: 10, text: "And when Daniel knew that the writing was signed, he went into his house (now his windows were open in his chamber toward Jerusalem); and he kneeled upon his knees three times a day, and prayed, and gave thanks before his God, as he did aforetime."),
                Verse(number: 22, text: "My God hath sent his angel, and hath shut the lions' mouths, and they have not hurt me; forasmuch as before him innocency was found in me; and also before thee, O king, have I done no hurt."),
            ]),
        ],

        "john": [
            Chapter(number: 1, verses: [
                Verse(number: 1, text: "In the beginning was the Word, and the Word was with God, and the Word was God."),
                Verse(number: 2, text: "The same was in the beginning with God."),
                Verse(number: 3, text: "All things were made through him; and without him was not anything made that hath been made."),
                Verse(number: 4, text: "In him was life; and the life was the light of men."),
                Verse(number: 5, text: "And the light shineth in the darkness; and the darkness apprehended it not."),
            ]),
            Chapter(number: 3, verses: [
                Verse(number: 16, text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth on him should not perish, but have eternal life."),
                Verse(number: 17, text: "For God sent not the Son into the world to judge the world; but that the world should be saved through him."),
            ]),
            Chapter(number: 15, verses: [
                Verse(number: 12, text: "This is my commandment, that ye love one another, even as I have loved you."),
                Verse(number: 13, text: "Greater love hath no man than this, that a man lay down his life for his friends."),
                Verse(number: 14, text: "Ye are my friends, if ye do the things which I command you."),
            ]),
        ],
    ]
}
