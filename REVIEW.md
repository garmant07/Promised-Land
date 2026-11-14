# Content to review before launch

Everything below is marked `reviewed: false`. DEBUG builds show it with a **Draft** badge;
Release builds hide the unreviewed text (the game still works with plain wording such as "Read
these chapters to light this stop"). Set `reviewed: true` on each entry once it's checked.

Imported question set: owner-approved, all volumes.

## 0. Places (new this round) — `PlaceData.swift`
66 Places (one per book), each with a name, a style and its growth pieces' captions. Most
captions describe the illustration ("the barn is built") rather than make a claim, but check
those that point at the text, e.g.:
- Genesis: "a river runs through the garden" (Gen 2:10); tents and wells at the garden's edge.
- Exodus/Numbers: the tabernacle at the camp's centre; Leviticus: altar, basin, lampstand.
- Ruth: threshing floor (Ruth 3), the town gate (Ruth 4). Jonah: "a harbour house stands at Joppa" (Jonah 1:3).
- 1 Samuel "a house of prayer stands at Shiloh"; 2 Samuel / 1 Chronicles "a tent is pitched for the ark";
  Jeremiah "a field is bought and sown" (Jer 32); Amos "a plumb line is held against a wall" (Amos 7:7);
  Daniel "lamps burn in an open window" (Dan 6:10); Ezekiel's river and trees (Ezek 47);
  Revelation's gate of pearl, river of water of life and trees of life (Rev 21–22);
  2 Timothy "books and parchments are kept safe" (2 Tim 4:13); 2 Peter "a lamp shines in a dark place" (2 Pet 1:19).
- Place names such as "The Lakeside Village" (Matthew) are design choices.
- **The forest** — `ForestData` in `PlaceData.swift`: 22 tree chapters with a quoted phrase and
  reference each (Gen 2:9, 18:1; Judg 9:8; 1 Kgs 19:4; Ps 1:3, 52:8, 92:12; Isa 55:12, 61:3;
  Jer 17:8; Ezek 31:3, 47:12; Dan 4:10; Hos 14:6; Zech 4:3; Matt 7:17, 13:31–32; Mark 11:13;
  Luke 13:6, 19:4; Rom 11:17; Rev 22:2). Check the ASV wording.

- **Feeding the crowd** — `FeedingTheCrowd` in `Produce.swift`: the ASV quote of John 6:9
  ("There is a lad here, who hath five barley loaves, and two fishes: but what are these among
  so many?") and the cross-references (Matt 14:13–21, Mark 6:30–44, Luke 9:10–17, John 6:1–14).
- **Villager routines** (`VillagerData.swift`) are illustrations (a fisherman, a harvester),
  not claims, but check they feel right for each style.

- **Legacy chapter questions** — `QuestionData.swift`: 34 questions (every bundled chapter, plus
  Gen 6, 12; Exod 14; 1 Sam 17; Dan 3; Jonah 1, 3; Matt 2; Mark 4; Luke 2, 15; John 2, 11;
  Acts 2, 9; 1 Cor 13; Rev 21). Check each answer against the ASV and its reference, and that
  the wrong options are clearly wrong.

## 1. Character journeys — `CharacterJourneys.swift`
13 journeys (the 12, plus Jonah as a bonus), 84 stops.
- **Every stop's "what happened"** paraphrases or quotes the ASV, with a verse reference.
  Check wording and references.
- **"What it may have looked like"** is filled only where the text itself describes the scene
  (e.g. "Ten elders of the city sitting down at the gate", Ruth 4:2). Empty elsewhere:
  TODO, add from a reviewed source if wanted.
- **"Why it matters"** is empty for every stop: TODO, write or leave out.
- **Unlock lines** are ASV quotations: Ruth 1:16, Jonah 2:2, Judges 16:28, Daniel 6:22,
  Genesis 21:6, Luke 1:38, Genesis 15:6, 1 Kings 3:9, 1 Samuel 17:45, 1 John 4:7, 2 Timothy 4:7,
  Exodus 14:13, John 10:11. Check the exact ASV wording.
- **Required chapters** follow the brief. Choices to confirm: Paul = Acts 7–28 + Romans–Philemon
  (Hebrews excluded); Jesus = every New Testament book; Mary includes Matthew 1–2.
- **Flagged:** Sarah and Abraham's "Isaac is born" stop is placed at Gerar (Genesis 20–21;
  confirm). John's journey: that the beloved disciple and the author of the letters and
  Revelation are John is church tradition, not stated in the texts (see the journey's note).
- Map positions are not used (journeys are a level map, not geography).

## 3. Bible text and deep dives
- **New sample text:** John 15:12–14 (ASV) in `BibleData.swift`. Check against the ASV.
- **Deep dives** — `DeepDiveData.swift`: John 15:13 (new), Genesis 1:1, Ruth 1:16, Psalm 23:1,
  John 1:1, John 3:16. Context lines, key words, themes and cross-references.

## 5. Buildings and themes — `BuildingData.swift`, `RewardData.swift`
Design choices, not claims, but check they feel right: which family, roof and crest each book
gets (e.g. a cross on 1 John, a harp on Psalms), and each book's three chapter artifacts.

## 6. Other existing content (unchanged this round, still unreviewed)
- `ReflectionData.swift`: chapter-specific reflection prompts.
- `LearningData.swift`: quiz questions (also used by the reading check) and memory verses.
- `WorldData.swift`: landmark and region names (used in the reading lists).
- `Crowns.swift`: the Revelation 4:10 casting verse.

## 7. Not content, but worth a look
- **Sample friends** (`Friends.swift`): names, reading plans and "Sample note" text are
  placeholders, clearly labelled.
- **Character art:** the 12 designs were cut out of their backgrounds automatically; check edges.
  `char_jonah` was drawn to match (source `Art/char_jonah.svg`).
- **Avatar presets** (`AvatarParts.swift`): each character's look approximates their design.
