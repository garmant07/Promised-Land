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

## Round: growing Places, living island (Nov 2026)

12. **No CLAUDE.md.** The prompt says to read CLAUDE.md first; the repo has none, so this round
    follows the conventions in NOTES.md, AUDIT.md and the existing code.
13. **The island is drawn with SwiftUI `Canvas`, not SpriteKit.** SpriteKit is only used for the
    world map. The island keeps its Canvas renderer, with caching added for performance
    (Section 4), rather than a rewrite.
14. **Growth counts chapters, not which chapter.** A Place's pieces appear by the share of its
    book's chapters read (distinct, checked reads), whatever order they're read in, so no one
    ever stares at a bare plot after skipping ahead. The caption uses the chapter actually read
    ("Ruth 2: the barn is built"). Short books share steps (bigger increments); long books
    grow one piece a step. When every piece is full, a step adds flowers ("flourish") instead.
15. **Opening a book no longer lays foundations.** A Place is founded by its first read chapter,
    as the brief says. `BookStarted` is still recorded (other screens use it).
16. **Chapter artifacts and story objects are gone from the island.** They're replaced by the one
    growing Place per book. The world map still uses `ChapterLandmarks`, and `BuildingData` is
    kept for the world map; the island no longer draws `BuildingArt`/`ArtifactArt`/`StoryArt`.
17. **Richness** = checked reads of the book ÷ its chapters (1–5), so a reread counts as it goes.
18. **The forest is its own Place.** Tree chapters (ForestData, unreviewed) found a forest that
    is placed like a Place (so it never shifts as the coast changes) and fills with trees.
    It can be moved in edit mode like any Place.
19. **Sections 1 and 2 were committed together**: the new Place builder needs the new placer.
20. **Layout migration.** `IslandMigration` (version 2, run once at launch) drops the old
    auto-pinned plot positions, keeps positions the reader chose if they still fit, and resets
    the "seen" markers so the first look is quiet. Reading history is never touched.
21. **"See it built".** After reading, HomeView compares each Place's chapter count with what was
    last seen and plays the beats (RevealPlan.swift). Up to three chapters play one after another,
    more play as one combined reveal. The rest of the island is held at its old growth until each
    beat plays. Rewards (banners, lanterns) and forest trees simply appear; the unlock banner's
    "See it" still points at them. With Reduce Motion the camera stays still and only the caption shows.
