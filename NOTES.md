# Notes: decisions made during the master build

Where the prompt was ambiguous or conflicted with earlier instructions, the simplest sensible
option was chosen and noted here.

1. **The Library is always on the island and is the reading hub.** The master prompt says it
   appears after the first journal entry and that Read opens a sheet. A later direct request
   made the Library the reading hub ("each book of the Bible is in the library and that is the
   access portal"), so the Library is present from the start and the Read button walks the
   avatar into it. Reading opened from elsewhere (character links, interiors, journeys) still
   opens the chapter directly.
2. **Ground is sand, not grass.** The art direction canvas uses warm sand on two earth layers;
   the "3×3 grass square" start is a 2×2 sand starting square with a one-tile border (4×4 of
   land), which reads as the same small start.
3. **No VersionedSchema.** The store was created without a versioned schema. Every model
   change since has been additive with defaults (lightweight migration), and an upgrade from
   the pre-round build was tested (all progress kept). Introducing a VersionedSchema now would
   mean duplicating every model class; the additive approach is kept and new fields always
   have defaults.
4. **Model names.** The prompt's ReadingEvent / QuizResult / MemorisedVerse are the existing
   `ChapterRead` / `QuizPass` / `VerseMemorised` models (renaming would break saved data).
5. **Jonah stays as a bonus journey.** The 12 character journeys replace the old placeholder
   journeys, but Jonah's art was commissioned separately, so Jonah remains a 13th, short,
   common journey (Jonah 1–4).
6. **World-map routes.** The SpriteKit world map's dotted routes (Jonah, Paul to Rome, Galilee)
   are kept as map decoration only; journeys, progress and unlocks now come from
   CharacterJourneys.swift.
7. **Character art.** The art direction has drawings for all 12 characters; they are cut out
   (background removed) into `char_<id>` assets. "The disciples" became John.
8. **Journey context text.** "What happened" follows the ASV text; "what it may have looked
   like" and "why it matters" are only filled where the text itself describes it, otherwise
   left empty with a TODO (listed in REVIEW.md). Empty fields aren't shown.
9. **Throne room.** It already exists on the world map; it now also appears on the island at
   the far New Testament edge once every book is read in the current cycle.
10. **"Reading unlocks apps"** is a stored preference only; FamilyControls is not used.
11. **Deep dives.** Existing entries are kept (all unreviewed); John 15:13 is added.
