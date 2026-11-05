# Content to review before launch

Everything below is marked `reviewed: false`. DEBUG builds show it with a **Draft** badge;
Release builds hide the unreviewed text (the game still works with plain wording such as "Read
these chapters to light this stop"). Set `reviewed: true` on each entry once it's checked.

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

## 2. Story objects — `ChapterLandmarks.swift`
- **New:** "Altar of Burnt-Offering" (Leviticus 1–7, ref. Leviticus 1:1–9), and its world-map
  position beside the Tabernacle (check it doesn't overlap).
- The 25 existing entries (names, one-line summaries, references) are still unreviewed.

## 3. Bible text and deep dives
- **New sample text:** John 15:12–14 (ASV) in `BibleData.swift`. Check against the ASV.
- **Deep dives** — `DeepDiveData.swift`: John 15:13 (new), Genesis 1:1, Ruth 1:16, Psalm 23:1,
  John 1:1, John 3:16. Context lines, key words, themes and cross-references.

## 4. World-map journeys — `JourneyData.swift`
Jonah, Paul's voyage (Sidon, Myra, Fair Havens, the storm, Melita, Rome) and Galilee. These
are now map decoration only, but their stop cards (place, what happened, looked like) still
show from the world map. Myra and the storm are placed approximately; "Melita (Malta)".

## 5. Buildings and themes — `BuildingData.swift`, `RewardData.swift`
Design choices, not claims, but check they feel right: which family, roof and crest each book
gets (e.g. a cross on 1 John, a harp on Psalms), and each book's three chapter artifacts.

## 6. Other existing content (unchanged this round, still unreviewed)
- `ReflectionData.swift`: chapter-specific reflection prompts.
- `LearningData.swift`: quiz questions (also used by the reading check) and memory verses.
- `WorldData.swift`: landmark names, regions and connections.
- `Crowns.swift`: the Revelation 4:10 casting verse.

## 7. Not content, but worth a look
- **Sample friends** (`Friends.swift`): names, reading plans and "Sample note" text are
  placeholders, clearly labelled.
- **Character art:** the 12 designs were cut out of their backgrounds automatically; check edges.
  `char_jonah` was drawn to match (source `Art/char_jonah.svg`).
- **Avatar presets** (`AvatarParts.swift`): each character's look approximates their design.
