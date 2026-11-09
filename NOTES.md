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
22. **VersionedSchema added.** `AppSchema.swift`: `SchemaV1` is exactly the 8 models stored before
    this round (unchanged, so the same classes serve both versions), `SchemaV2` adds
    `ProduceCollection`, `ProduceGift`, `PlacedExtra` and `ReadingPhoto`, and the plan has one
    lightweight stage. Tested by writing a store the old way (no version) and opening it through
    the plan: every record is kept. This replaces note 3.
23. **Villagers** are drawn with shapes each frame rather than cached sprites: each is four small
    fills, cheaper than looking up and drawing a scaled image. Everything else that's code-drawn
    is cached (see 25).
24. **Produce.** One per reading day since the Place was completed (or last collected), capped at
    3 a Place. "Save for a friend" only records the gift on this device (no networking). The
    plaza crowd (tap it, or Profile → Your basket) receives gifts; bread and fish together play
    the "feeding the crowd" moment (John 6:9 quote, unreviewed).
25. **Performance.** The island stays on SwiftUI `Canvas`; `IslandRenderCache` renders the ground
    into 512-pt chunks and each Place into one picture (keyed by its contents, so a moved Place
    reuses it), per zoom bucket and turn, in a memory-capped `NSCache`. Only on-screen chunks,
    Places, villagers (max 40) and travellers (max 6) are drawn; life pauses in edit mode. In the
    Simulator a fully built 66-Place island pans at ~56 fps (was 3 fps before caching). **Not
    yet measured on a real iPhone 11 / SE**: please check with Settings → Developer → FPS overlay.
    DEBUG `-autoPan` circles the camera for measuring.
26. **Edit mode extras.** Earned by reading (RewardData.extrasEarned: paths and trees by reading
    days, fences/benches/lamps by longest streak), placed from the Extras tray onto the open
    land nearest the plaza, then dragged (whole tiles) like Places. They can't go in the sea or
    inside a Place (red). Undo keeps the last 50 changes while editing; Cancel discards all.
27. **Reading that counts.** A chapter now counts only through the gate: reach the last page,
    spend the minimum time (≈200 words/min Standard, 160 Strict; floor 45/90 s, cap 8/10 min;
    paused while the app is in the background), then answer one question. The old one-tap
    "Mark as read" and its optional check are gone; reads saved before still count, and an old
    unchecked read can be counted by answering its question. Chapters without bundled text use
    a typical length (650 words). Relaxed skips the timer. Kids (Under 13) default to Strict;
    changing it on a Kids profile asks a grown-up a simple sum.
28. **Questions** exist for every bundled chapter and some well-known ones (QuestionData,
    unreviewed); other chapters get a reflection prompt (anything written counts, saved to the
    journal).
29. **Use my Bible** uses the Vision `RecognizeTextRequest` on device; the camera when there is
    one, otherwise a photo from the library (the Simulator has no camera). With the photo read,
    Strict also times the reading; picking the chapter by hand goes straight to the question.
    Photos are kept only if asked, as `ReadingPhoto` linked to a journal entry.
30. **Preview full Bible (DEBUG).** Settings → Developer → Preview full Bible (or launch with
    `-fullBiblePreview`). It builds an in-memory `ModelContainer` with a `ChapterRead` for every
    chapter and shows the complete island; richness, replay, jump-to-book, FPS and edit mode
    changes live only while it's open. Tested not to write to the real store.

31. **The world map is deleted** (by request). The SpriteKit map (`WorldView`, `WorldScene` and its
    layers) is gone, along with what only it showed: the dotted route journeys (`JourneyData`,
    Jonah / Paul to Rome / Galilee, and their Profile badges), the story objects
    (`ChapterLandmarks`, now unused since the island has Places), fog and connections, the
    "Reset map view" setting and the map's camera keys. Character journeys, the throne room and
    crowns live on the island and are unchanged. Kept from `World/`: `IsoMath.swift` (noise and
    iso maths), `LandmarkPainter.swift` (the Library and the small landmark pictures in the
    reading lists). Notes 6 and 9 above describe the map as it was. `WorldData` stays for book
    and landmark names.

## Round: Collect All, zoom and level of detail, the growing Library (Nov 2026)

32. **Still no CLAUDE.md**; this round follows NOTES.md, AUDIT.md and the existing code.
33. **Collect All.** A basket button floats above the bottom bar (bottom-left; the turn and Find me
    buttons stay bottom-right) only while something is waiting, with the total as a badge. One tap
    writes every Place's basket at once (`ModelContext.collectAllProduce`, one save); the baskets on
    screen fly into the button (at most 12 sprites, extras grouped as one "+N" bundle), off-screen
    ones are simply collected, then "+3 fish, +2 bread…" fades in. Hidden in edit mode, during a
    reveal and while any sheet, interior or visit is open. Reduce Motion skips the flight. The whoosh is
    synthesised on device (filtered noise through AVAudioEngine, "ambient" session, so the silent
    switch mutes it). `ProduceRules.baskets` is now shared by the island, tests and the preview; the
    reading-day rule and cap are unchanged. In Preview full Bible the button works on the preview's
    own baskets and in-memory store only.
34. **"Node count" = draw calls.** The island is a SwiftUI `Canvas`, not SpriteKit (note 13), so the
    DEBUG overlay shows draws per frame (images, items and figures; `RenderStats`) beside the fps.
35. **Zoom.** The zoom-in limit is now per island: at least 4×, and on big islands until a tile is
    about a quarter of the free width (`IslandLayout.maxZoom`), so a single Place fills the screen.
    Pinch zooms about the fingers, rubber-bands a little past either limit and eases back. Render
    buckets go up to 80×. Ground chunks draw only their own tiles.
36. **Level of detail** (IslandLOD.swift), by absolute size `u`: far (< 0.55/0.62) shows no figures,
    only up to 2 boats, birds, waves and one puff of smoke per chimney. Middle shows up to 15 near the
    middle of the screen. Close shows up to 30 on screen. The thresholds differ going in and out, and
    figures fade over 0.3 s. Each figure has its own clock that runs only while its home is on screen,
    so off screen nothing is worked out and it resumes where it left off. Bible characters count
    towards the caps. Far out, Places and items are baked into the ground chunks (a handful of
    images), except while editing or mid-reveal.
37. **Measured in the Simulator only** (iPhone 17, full Bible preview): about 56 fps far out
    (87 draws) and 58 fps close in (41 draws). **Not measured on a real iPhone 11 / SE**: please check
    with Settings → Developer → FPS overlay (and `-autoPan`).
38. **The Library grows** (LibraryData.swift). Volumes are distinct checked chapters, notes are
    journal entries, and points = volumes + 2 × notes. The stages unlock at 0 / 12 / 50 / 150 / 400 /
    900 points: hut 2×2, room 3×3, wings 4×4, second floor 5×5, reading tower 6×6, grand 7×7, each
    taller. Small touches come between stages (by volumes or notes). It's drawn in code
    (LibraryArt.swift), with art swap `bld_library_<stage>`.
39. **Where it grows.** The hut keeps its spot beside the plaza. Bigger stages spread away from the
    plaza (−x, −y, so back on screen), anchored at the hut's corner nearest the plaza, so it never
    covers the start square. Its edit-mode placement is still the hut's corner. Places you moved
    yourself are never touched: the Library shifts, or as a last resort stays a size smaller, to
    avoid them. Auto-placed Places are first laid out around the hut (exactly today's layout). Only
    those in the grown Library's way are nudged to the nearest free spot outward, so nothing else
    reshuffles. While editing, the Library keeps its saved size, so dropping a Place on it is a red
    conflict. Roads now start at the Library (the plaza joins it), so every road leads there.
40. **Library reveal.** When it reaches a new stage, the "see it built" moment plays last: the old
    building fades as the new one rises with a big dust burst and sparkles ("Your library added a
    reading tower"). The first look after updating is quiet (`library.stageSeen`).
41. **Inside the Library**: a stage card (volumes, notes, progress to the next stage), a Volumes shelf
    with a thin spine for every chapter read, and handwritten note slips tucked into each book that
    has journal entries.

42. **Layering.** People are never drawn on top of a building that stands in front of them. Villagers
    and travellers are drawn back to front together with the tall things (buildings, trees) that
    overlap them, so someone behind a house is hidden by it. Your avatar and Bible characters (drawn
    above the island) get the tall things in front of them drawn over them again, unless another
    figure there is in front of the thing. Those buildings come from cached pictures
    (`IslandRenderCache.drawItem`), so this costs about nothing per frame.
43. **Full screen.** The island now runs under the status bar too (it used to stop at the safe area).
    The status pill and banners still sit below the status bar, and fitting the island still keeps
    clear of them.
44. **Fixed:** near full zoom, the cached ground and Place pictures were a few percent too big (the
    zoom bucket was past the island's limit and got clamped). Pinching now visibly rubber-bands up to
    30% past either limit, then eases back.

## Round: performance pass (Nov 2026)

45. **No SpriteKit.** The brief was written for a SpriteKit scene; the island is a SwiftUI `Canvas`
    (notes 13, 34), so each step was mapped onto that instead of rewriting the renderer:
    - *Bake ground into chunks* and *cache code-drawn textures by key*: already done (`IslandRenderCache`,
      512-pt chunks, Place and item pictures). Added: the ground's extent and the wave spots are now
      remembered per island instead of walking every tile each frame.
    - *Only keep nodes for what's on screen*: there are no nodes; chunks, Places, items and figures were
      already culled to the screen. The still layers now don't even re-plan while panning (below).
    - *Pause off screen / cap figures*: clocks already paused off screen and caps were already 15/30
      figures and 6 travellers. Added: far out, once everyone has faded, villagers aren't listed at all;
      and the whole island (waves, life, characters) holds still while a full-screen view (an interior,
      the Library) covers it. It used to keep animating behind it at 60 fps.
    - *Re-sort depth only when something changes*: `IslandDepthOrder` sorts when the island, turn or a
      reveal changes, never per pan/zoom frame (depth order doesn't depend on them).
    - *No SwiftData per frame*: confirmed: nothing in the render path fetches; `HomeView.body` (the only
      place the `@Query`s are read) runs 0 times a second while panning.
    - *SpriteView not recreated*: `PlatformScene` keeps its identity, and its still layers are
      `Equatable`, so streak pill / sheet / bar changes don't redraw them.
    - *ignoresSiblingOrder / zPosition / shouldRasterize / atlases*: SpriteKit and CALayer settings with
      no Canvas equivalent. Draw order is explicit back-to-front, and the cached chunk and Place
      pictures play the part of rasterised layers and atlases.
46. **Panning slides layers instead of redrawing them** (`IslandLayers.swift`). The profile showed most
    of the main thread going to Core Animation redrawing up to seven full-screen canvases every frame.
    The ground and waves are drawn at the pan rounded to 96 pt onto canvases 96 pt bigger than the
    screen, and slid by the remainder; they redraw about twice a second while panning instead of every
    frame. The life, build, bounce, in-front, basket and Collect All canvases are merged into two, and
    a canvas with nothing to draw is left out.
47. **Measured** (simulator, iPhone 17, store seeded with every chapter, `-autoPan`, 600 nodes):

    | zoom | fps before → after | island main-thread ms/frame before → after |
    |---|---|---|
    | far (1×) | 25 (min 11) → 57 (min 52) | 12.7 → 0.7 |
    | middle (3×) | 45 → 58 | 7.8 → 0.7 |
    | close (8×) | 51 → 58 | 8.0 → 2.2 |
    | idle | 60 → 60 | 2.1 → 1.4 |
    | behind the Library | 59 → 60 | 1.9 → 0.0 |

    **Still not measured on a real iPhone 11** (none was attached). The CPU work per frame is now far
    under budget. What's left in the simulator is mostly waiting on its emulated GPU. Check on a device
    with Settings → Developer → FPS overlay (now `fps · nodes · draws · ms`). DEBUG `-perfLog` prints fps,
    nodes, draws and the time in each part of the island once a second.

## Round: live Bible text from API.Bible (Nov 2026)

48. **Bible text is the one thing that goes online.** It replaces the "fully offline" rule for
    Bible TEXT only; progress, island, journeys and journal are unchanged and work offline. Setup,
    caching and error handling are in README.md. Views only use `BibleService` (`\.bibleService`).
    `APIBibleService` is the live one; `BundledBibleService` (the ASV sample) is its fallback.
49. **Docs checked** (docs.api.bible, Nov 2026): base `https://rest.api.bible/v1`, header `api-key`.
    The docs don't document 429 or the error body. Checked against the live API: a wrong key answers
    **403** `{"statusCode":403,"error":"Forbidden","message":"Invalid API key"}`, not 401. So a 403
    whose message mentions the key is "bad key", and any other 403 is "not on your plan" (that
    translation is then hidden). 429 honours `Retry-After` when present.
50. **Text format.** `content-type=text` with verse numbers and no notes, titles or chapter
    numbers; verses are split on the `[n]` markers. Not yet seen with a real NIV/NLT/CSB response
    (no key here): if a translation formats differently, `ChapterParser` is the place to adjust.
51. **Questions from text.** Chapters without a hand-written question get one made from their saved
    text: a verse with its longest distinctive word blanked, and two other words from the chapter
    as choices (the same each time). It's mechanical, taken from Scripture itself, so it's marked
    reviewed. Chapters with no saved text still get a reflection prompt.
52. **Offline with nothing cached** shows the bundled ASV sample where one exists (with a note),
    otherwise the "Connect to the internet" message with Retry.
53. **Not done:** FUMS reporting. The docs require it for web apps, and say an app used only on
    mobile with no user-facing web part can skip it. Also not done: any server proxy for the key
    (see README).

## Round: connected roads (Nov 2026)

54. **Roads are one network.** Each road used to run from a Place to its nearest neighbour's edge
    and stop a tile inside it. Roads arriving at the same Place came in on different sides, so the
    full island had 63 separate pieces of road. Now the plaza–Library road is laid first. Each
    Place's road then runs from its nearest side to the nearest tile of the roads already there,
    and records where it joins (`IslandRoads.Link.join`). The full island is now one piece.
55. **The glitchy walking was the same bug.** A walk to the Library (Library readers, and some
    travellers) glued roads end to end. Where one ended inside a Place and the next began on
    another side, walkers slid straight through the building (63 of 66 routes, jumps of up to 8
    tiles). Walks now follow the road they join from the junction onward, so every step is to a
    neighbouring tile. Tested in `PlaceGrowthTests.roadsConnect`.

## Round: iOS 26 (Nov 2026)

56. **Runs on iOS 26.** The deployment target was 27.0; it's now 26.0. The only iOS 27-only calls were
    in the Collect All whoosh (`AVAudioEngine.connectNode`, `AVAudioPlayerNode.playAudio`). They use
    `connect(_:to:format:)` and `play()` instead, which do the same and exist on iOS 26. Compiled
    for iOS 26 with no warnings. Not yet run on an iOS 26 device or simulator (only iOS 27
    simulators are installed here).

## Round: smooth turning and panning (Nov 2026)

57. **Measured first** (simulator, full Bible seeded, 600 nodes; `-perfLog` now also logs the
    longest frame each second, and DEBUG `-autoTurn [seconds]` turns the island on a timer). Panning
    was ~59 fps. Turning was 22–38 fps, with a 0.4–0.75 s freeze on every quarter turn.
58. **Causes, from the profiler.** (1) The turn redrew the whole island from scratch at every
    in-between angle (nothing is cached between quarters). (2) Landing on a quarter rendered its
    ground chunks and Place pictures on the spot. Close in, the 160 MB picture cache had evicted
    them (NSCache evicts before its limit). (3) Every camera save (each turn, and the end of each
    pan or pinch) wrote UserDefaults, which made the whole home screen recompute (`@AppStorage`)
    with a full Bible. (4) Produce baskets were drawn from shapes and text every frame: 15% of
    the main thread at middle zoom.
59. **Fixes.** A turn switches quarter at once (only cached pictures, never in-between angles),
    while a picture of the old quarter turns away and fades out over 0.3 s (`TurnSnapshotView`).
    Only layer opacity and rotation animate. Turn taps during the animation queue at most one
    (`TurnQueue`). While the camera is still, the neighbouring quarters' pictures are rendered ahead,
    one per frame gap (`IslandRenderCache.prewarm`). The cache limit is 512 MB; the whole app
    measured ~150 MB with every quarter warm. The camera is saved only when the app leaves the
    foreground or the island goes away. Baskets are cached pictures. Depth order is still sorted
    once per turn.
60. **Tried and dropped:** stepping camera glides on the display link (`FrameTicker`) instead of a
    16 ms sleep. It added a second SwiftUI update each frame and measured slower (52 vs 58 fps), so
    glides keep the sleep. `FrameTicker` is used only for one-off "after the next frame" waits.
61. **After** (same runs): pan 58–60 fps at all zooms; turn 57–58 fps far and middle, 56–57 close
    in. Turns that used to freeze for 0.4–0.75 s now drop at most a few frames (worst 50 ms far
    and middle, up to 100 ms close in). Node count unchanged (600). Still not measured on a real
    iPhone 11.
62. **No SpriteKit.** The brief's SKCameraNode / SKShapeNode / zPosition items don't apply: the
    island is a SwiftUI `Canvas` (notes 13, 45). Panning already only slides two cached layers
    (note 46); the camera isn't written anywhere during a drag.

## Round: edit mode without gaps (Nov 2026)

63. **What went wrong.** Land is each Place plus a one-tile border, and only one-tile gaps between
    neighbours were filled. Moving a Place a little away from its neighbours left a 2–3 tile
    channel or inlet of sea cutting into the island, and dragging it further left a separate islet.
    Saved spots also had to keep a full tile from every neighbour, so dropping a Place close to
    another was refused (red). And when you dropped a Place onto one later in the list, only the
    other Place was flagged: yours stayed overlapping, and Done stayed disabled.
64. **Now.** Places you place yourself may sit right beside each other; only an actual overlap (or
    a bay on land) is refused, and it flags both Places, so the one you dropped always springs
    back. The land fills any straight gap of up to three tiles and any notch. A Place dragged out
    on its own is joined to the island by a three-tile strip, so the island is always one piece and
    every road still reaches the Library. Bays stay water, and tiles beside a bay are left as sea
    so it keeps its mouth onto open water. Tested in `EditGapTests`.
65. **Upgrade step.** `IslandMigration` still lets the first of two overlapping saved spots keep its
    place: it adds them in reading order and lets go of the one that causes an overlap.
66. **Bays have land along both sides.** A waterside Place's bay used to stick out two tiles past
    its one-tile land border, so its water merged into the open sea. The Place's land now runs down
    both sides of the bay to the end of the water, so the bay reads as its own small harbour, open
    to the sea only at its far end (`IslandPlacer.bays`). Tested in `BayBorderTests`. Changing the
    land's shape moved a close-in LOD test's camera slightly. That test now allows a figure that
    has just walked off screen to finish its 0.3 s fade-out (as designed); everyone fully shown is
    still on screen.
67. **Reading timer: 220 words a minute, nothing else.** The time needed before Finish unlocks is
    the chapter's words ÷ 220 × 60 seconds: no minimum or maximum, and the same pace for Standard
    and Strict. Strict still also times reading in your own Bible. Words come from the chapter's
    text on the device (live text once loaded, cached or bundled), or a typical 650 when there's
    none (about 3 minutes). This replaces note 27's 200/160 words a minute, 45/90 s floor and
    8/10 min cap.
68. **The reading button counts down.** While the reading time runs, the button says
    "Keep reading · 2:41" (time left, counting down every second; VoiceOver reads "2 minutes 41
    seconds left"). Once you've reached the last page and the time is up, it says "Mark complete",
    or "Mark complete again" for a chapter already read. At 220 words a minute a real chapter takes
    3–4 minutes, so without the countdown the button looked stuck. DEBUG `-readerLastPage` opens the
    reader on its last page (as a swipe would), for checking this.
69. **The reading timer runs only while you're reading.** It used to start when the reader was
    created and keep going while the text loaded, behind the question or a deep dive, and after
    moving on to the next chapter (the earlier reader stays in the navigation stack). It now counts
    only while the chapter's text is on screen with nothing covering it and the app open
    (`ReadingClock`).
70. **"Reached the end" can't be missed.** It was set only when the page index changed to the last
    page (or the chapter fit on one page when the reader first appeared). If the page count settled
    after the reader appeared, the last page could be showing without the index changing, so the
    button stayed on "Keep reading" at 0:00. It's now set whenever the last page is showing,
    including on first appearance and when the page count changes. DEBUG builds log
    "READER page x of y" and the timer's running/paused state to the Xcode console.

## Bug-fix round (Nov 2026)

### Bug-fix progress
- [x] Section 1: Reader timer
- [x] Section 2: Leftover text when flipping pages
- [x] Section 3: Lag opening sheets, buildings and the Library
- [x] Section 4: Island camera and rendering
- [x] Section 5: Friends and group islands
- [x] Section 4b: Island follow-up (buildings on their land, no flicker, birds on top)
- [x] Section 4c: Camera feel (zoom, pan shake, stepping up to a building)

71. **Still no CLAUDE.md.** As note 12: this round follows NOTES.md, AUDIT.md and the existing code.
72. **The reading timer is a per-chapter `ReadingSession`** (`ReadingGate.swift`), kept in
    `ReadingSessions.shared` for the life of the app rather than in the reader's view state, so
    page turns, re-renders, sheets and the reader being rebuilt never reset it. Leaving a chapter
    and coming back carries on where it was; a counted read starts the next session from zero.
    The causes it replaces: a 30 fps `TimelineView` on the last page that re-counted every verse's
    words each frame (the stutter), and "Mark complete" being worked out only inside that
    TimelineView, which can stop ticking when the paged TabView recycles the page (the freeze
    at "15 seconds left"). Now a single ticker wakes about once a second, the gate latches
    "time's up" on every tick, pause and page reached, and only the button redraws.
73. **Pace: 200 words a minute, 30 s floor, 12 min cap.** This round asks for ~200 wpm with a floor
    and cap, replacing note 67's 220 with none. The words are counted once from the loaded text
    (again only if the translation changes), so the required time no longer jumps from the
    typical-650 guess to the real count as the text loads. DEBUG builds show
    "DEBUG: n words → s required" under the button. Relaxed still has no timer. The own-Bible
    scan flow keeps its existing timer (same pace rules).

74. **The reader's pages are no longer a paged `TabView`.** Its implicit `.animation(value: sheet)`
    animated the page contents on top of the TabView's own paging, and rapid taps started new turns
    mid-slide; the TabView's reused page cells could then keep another page's text on screen. The
    reader now holds only the current sheet in the view tree (`.id(index)`); a turn slides the old
    one out and removes it. `PageTurner` ignores taps and swipes while a turn animates (the lock
    lapses after 0.6 s at most, so it can't stick). Swipes are a horizontal drag (the page follows
    the finger a little, then slides); taps on verses still open deep dives; VoiceOver turns pages
    with a three-finger scroll.

75. **Why the Library took 5–10 seconds: `GameProgress` was rebuilt on every read of `progress`.**
    `ProgressQuery.wrappedValue` walked every stored `ChapterRead` (through SwiftData's slow
    property getters) each time a view touched `progress`, and the Library hub touches it once per
    book, the book page three times per chapter cell, and the home screen several times. Time
    Profiler (heavy history: every chapter read twice, 2,378 reads) showed 8.6 s of 12.4 s of
    main-thread time in it while the Library opened. Now every view shares one snapshot
    (`GameProgressCache`), rebuilt only when the records change: a SwiftData save, a record added
    or removed, a new day, or a different store.
76. **Smaller fixes in the same round.** The building interior counted its book's reads once per
    chapter cell, and the Library hub grouped the journal once per book; both now do it once.
    Book thumbnails in lists are drawn off the main thread and fade in, and their cache holds 240
    (it held 60, fewer than the 66 books, so scrolling back up redrew them all). The island holds
    still behind a sheet pulled to full height (as it already did behind an interior) and drops to
    30 fps behind a half-height sheet.
77. **Measuring.** The island is a SwiftUI `Canvas`, not SpriteKit (note 13), so there is no
    SpriteKit FPS instrument to use; frame rate comes from the app's display-link meter
    (`-perfLog`). The SwiftUI instrument records no data on the simulator (the full SwiftUI template
    fails: "Hitches is not supported on this platform"), so its numbers need a real device. DEBUG
    launch options added for timing: `-openDelay <s>` (open things a few seconds after launch),
    `-openPlace <bookID>`, `-openBook <bookID>`, `-autoScroll`; each screen prints
    "OPEN <name>: n ms" from being asked for to its first frame.

### Section 3 performance (iPhone 17 simulator, iOS 27, Debug, 2,378 reads)

| | Before | After |
|---|---|---|
| Open the Library (island building) | 7,490 ms | 357 ms |
| Tap a book in the Library (Psalms) | 9,280 ms | 205 ms |
| Open Read | 533 ms | 239 ms |
| Tap a book in Read (Psalms) | 3,462 ms | 158 ms |
| Open a building (Psalms) | 443 ms | 267 ms |
| Scroll the Read book list | 12–60 fps, one 2.9 s freeze | 52–59 fps, worst frame 50 ms |
| Main thread busy, launch + open Library (Time Profiler) | 12.4 s | 3.3 s (mostly launch) |
| `ProgressQuery.wrappedValue` during that | 8,622 ms | 58 ms |

Scrolling is measured with a programmatic animated scroll (`-autoScroll`), which is harsher than a
finger fling. App code is about 200 ms of the main thread's work across the whole scroll; the rest
is SwiftUI's own list layout.

78. **Tapping a building centres it.** Tapping a Place or the Library set both the selection and
    the visit, and each started its own camera glide (`centre(on:)` nudged 60% of the way to a point
    a third of the way down; the visit zoomed to the door at 55%), so whichever ran second cut the
    other off mid-zoom. Now a building you step into is moved only by the visit, and the camera puts
    the middle of its Place (`IslandCamera.focus`) at the middle of the free area, at the current turn.
    Find me and the after-reading reveal use the same maths. Other things you tap (trees, lanterns)
    open a card over the lower half, so they're centred a third of the way down, fully rather than
    60%. The pan limit now always allows centring any Place at any turn.
79. **People behind buildings.** "Behind" was "feet higher on screen than the building's anchor"
    (its middle), so someone walking behind its front half was drawn on top. It's now the
    footprint's front-most corner, on the turned grid: behind = not past its front edge on either
    axis (`IslandCamera.isBehind`), the same at all four turns, for you, Bible characters, villagers
    and travellers. Villagers sort against that corner too.
80. **Birds fly in the island's space** (a line across its grid, high above the ground), so they
    pan, zoom and turn with it. There are no cloud shadows in the app to move; none were added
    (fixes only).
81. **Edges and fast panning.** Villagers, travellers and characters were only looked at within
    30 pt of the screen, then faded in over 0.3 s, so they appeared late at the edges and flickered
    in and out on a shaky pan. They're now picked up 140 pt out (`PlatformScene.lifeMargin`), so the
    fade happens off screen; everyone on screen ranks ahead of the margin for the 30-figure cap, and
    figures already showing keep their place longer, so a wiggle doesn't swap them. Each time the pan
    crosses a step, the Place pictures and ground three steps ahead in that direction are rendered
    between frames. Positions were already worked out from the camera every frame. Auto-pan at zoom 4
    on the simulator: 18–33 fps before, 26–44 fps after (simulator numbers; relative only).


82. **Friend and group islands open full screen** (`VisitedIslandView`), drawn by the same
    `PlatformScene` as your own island with their data: pan, zoom, turn, Find me (their avatar),
    villagers. They used to be a fixed-height box inside a page pushed in the Friends sheet (the
    group's with touches turned off). A title bar shows whose it is ("Hannah's Island",
    "Sample Youth Group Island", with "Preview" for sample data), a Back button, and an info button
    for what the old pages showed (a friend's stats and shared notes; a group's "who read what").
    Tapping a Place works like yours: the camera centres it while the avatar walks over, then a
    read-only inside page opens (its art, which of the book's chapters they've read, and notes they
    shared). Anything else shows the small card as before. Nothing can be edited. Your own island
    holds still while theirs is open. Sample names drop "(sample)" in the title; the Preview tag
    says it instead. DEBUG: `-openFriends -visitIsland group|sample-hannah [-visitInside ruth]`.


83. **Section 4b: why buildings seemed to leave their land and blink while panning.** Someone
    standing behind a building had that building drawn again over them, whole, from its own
    picture. The still layer draws each Place as one picture with its pieces overlapping their
    neighbours; the copy was pasted on top of those neighbours (a pixel test found 8–32% of a copy
    differing from the island beneath it, mostly where pieces in front of it were covered), and it
    appeared and vanished as villagers walked in and out behind buildings. Section 4 made this far
    more frequent by looking after villagers 140 pt off screen. Now nothing is pasted: anyone
    standing behind a building gets the island in front of them redrawn **clipped to their own
    rect only**, in the island's own back-to-front order (`IslandWorld.itemsOver`), so the picture
    elsewhere is untouched and the overlap is exactly what the island shows.
84. **What 4b asked for, and how it maps onto this renderer.** The island is a SwiftUI `Canvas`
    (note 13), not SpriteKit, so there are no nodes; the same rules apply to what's drawn:
    - *Ground baked into chunks*: it already was (512-point chunks per zoom bucket and turn, 2× scale,
      1024 px textures: sharp up close and within device limits). Plain ground chunks are now keyed
      by the land alone (tiles, roads, plots), so a building growing no longer re-bakes them; adding
      land or turning does. Far out, still things are baked into the chunks too (as before), so
      those follow the whole island. Waves stay their own light layer on the sea.
    - *Everything from its grid point, one camera*: ground, Places, items and people are all placed
      from grid coordinates through the same layout and pan; nothing is moved by a gesture callback
      or culling code. A test pans hard at every turn and zoom and checks every picture moves by
      exactly the pan.
    - *One visible rect with a margin*: things are drawn when their picture reaches into it, not
      when their anchor does (loose trees, banners and lanterns at the edges used to be skipped
      until their anchor came on screen, so they appeared late). Some items' tap shapes ignore
      their position; their picture rects are now worked out the way their pictures are placed.
    - *Birds*: their own layer (`IslandLayer.birds`), above everything on the island and never
      depth-sorted; only baskets and speech bubbles are above them. There are no cloud shadows (note 80).
    - *One depth-sorted layer for buildings and people* was tried first: every building drawn each
      frame in one Canvas. With a full Bible that ran at 1–4 fps (about 440 pictures redrawn per
      frame on the CPU, and around 30 s to render them all after a zoom), so the clipped redraw
      above was used instead: same result on screen, at the cost of only what's behind each person.
    Simulator, full Bible, auto-pan: zoom 1: 18–22 fps before, 48–58 after; zoom 3: 23–31 before,
    60 after; zoom 6: 20–26 before, 54–59 after (simulator numbers; relative only).


85. **Section 4c: why zooming lagged.** Every step of a pinch changed the still layers' key, so the
    ground and Place pictures were planned and redrawn each frame, and each time the zoom crossed
    one of the ×1.25 picture buckets every chunk and Place picture on screen was rendered on the
    spot. Detail level also switched mid-pinch. Now, while a pinch or zoom glide is in progress, the
    still layers keep their drawing and are only scaled and moved as a picture about the free area's
    centre (`still`, `stillAnchor`; a test checks the scaled drawing lines up exactly with the camera
    at every turn). Once the zoom settles, or the picture is stretched past 1.6× either way, the
    pictures for the new zoom are rendered one per frame while the old drawing stays up, then
    swapped in. Detail level, the redraws over people and warming ahead all wait for the zoom to
    settle.
86. **Why pinching jittered, and zoom felt weak.** After a pinch, the finger left on the screen
    carried on panning with a translation measured from before the pinch, so the island jumped; it
    now pans only after it lifts. During a pinch the pan was clamped, which stopped the spot
    between the fingers staying put; it's now kept exactly, and clamped only once the fingers lift
    (as before). A finger's wobble is absorbed by a 2% dead band (`PinchSmoothing`), so the island
    no longer twitches in and out. You can zoom further in: fully in, a tile is over a third of the
    screen across (was a quarter).
87. **Why the island shook when panning.** The glide after every flick (and every camera move) was
    stepped by a fixed 16 ms sleep, which drifts against the display, so some frames didn't move
    and others moved double, worst on 120 Hz screens. Glides are now a pure function of time
    (`CameraGlide`) applied once per screen refresh; only one thing moves the camera at a time (a
    touch cancels a glide; a pinch takes over from a drag).
88. **Stepping up to a building** zooms until its Place fills three quarters of the screen's width
    (`IslandCamera.visitZoom`, worked out for the current turn, as the island's fit depends on it),
    centred, while your character walks to its door; then its page opens, and Back returns the
    camera to where it was.

### Section 4c measurements (iPhone 17 simulator, full Bible, `-autoZoom` pinching 1→3× and 1→⅓×)

| | Before (4b) | After |
|---|---|---|
| Pinch zoom, average fps | 48 | 51 |
| Pinch zoom, slowest second | 2 fps | 27 fps |
| Pinch zoom, worst single frame | 500 ms | 378 ms |
| Pan (`-autoPan`, zoom 3) | 60 fps, worst 44 ms | 60 fps, worst 50 ms |
| Time Profiler: busiest quarter second of main-thread work while pinching | 187 ms | 82 ms |
| Still layers planned (`scene.plan`) per second while pinching | 37–59 | 1–3 |

The worst single frames left are first-time renders of a far-out chunk with the island's
buildings baked in (one picture takes up to ~120 ms on the simulator); they now come one per
frame rather than all in one. Instruments' SwiftUI and frame-rate instruments don't record on the
simulator (note 77); frame rate comes from the app's own meter. `-autoZoom` (DEBUG) pinches in and
out through the same code as a real pinch.


## Remove before release

- **`Promised Land/Debug/FullBiblePreview/`** (the whole folder) — the temporary full-Bible preview.
- In `SettingsExtras.swift`, the "Preview full Bible" button and its `fullScreenCover` (inside
  `#if DEBUG`), and in `HomeView.swift` the `-fullBiblePreview` launch option and
  `debugBiblePreview` state (also DEBUG only).
- `Promised Land Tests/FullBiblePreviewTests.swift`.
Everything above is compiled only in DEBUG builds, so Release is unaffected even if it stays.
