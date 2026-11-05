# Audit: master build prompt

Status per section, checked against the code before this run. **Done** = already built and
working (kept). **Fixed** = built but needed correcting. **Built** = added in this run.
**Skipped** = deliberately not done (reason in NOTES.md). All sections below are complete.

| § | Item | Status |
|---|---|---|
| 1 | Shared hit-test path (footprint + visible bounds, reverse depth, 44pt) for island and world map | Done |
| 1 | Tap vs pan (< 10pt), overlays don't block the map | Done |
| 1 | Bounce + highlight on tap | Done |
| 1 | Tests: small/large/overlapping/adjacent, min/max zoom, pans never select, Library | Done |
| 2 | Island full-screen base, no TabView, no top icons; streak + places pill | Done |
| 2 | Bottom bar Read / Journeys / Friends / Profile as sheets (medium/large) | Done (Read walks into the Library hub; see NOTES) |
| 2 | Settings behind a gear in Profile | Done |
| 2 | Library as an island building | Done (always present as the reading hub; see NOTES) |
| 3 | Island grows from a small start square, deterministic, replays history | Done |
| 3 | OT one way / NT the other | Done |
| 3 | Each region in a consistent direction, related books clustered | Built (per-section directions) |
| 3 | Chapter artifacts, story objects (ChapterLandmarks) | Done; Leviticus tabernacle piece Built |
| 3 | Completed book builds its building; rereads level artifacts and add floors | Done |
| 3 | Rewards (RewardData), 66 unique silhouettes (BuildingData) | Done |
| 3 | Reading check (quiz / reflection / note; skippable) | Done |
| 4 | Water, shoreline, waves, coastal harbours | Done |
| 4 | Pinch / pan with limits, Find me, saved camera | Done |
| 4 | Pan inertia, double-tap to zoom | Built |
| 4 | Default zoom pulls back as the island grows | Built |
| 4 | Rotation 90° (buttons + twist), re-projection, depth sort, `_r0…_r3` | Done |
| 4 | After reading: camera eases to new thing, rise + dust + sparkles, avatar walks over, camera returns, queued | Built |
| 4 | Edit mode (drag, rotate, green/red, Done/Cancel, Tidy up) | Done |
| 5 | Quick insight card for small artifacts | Done |
| 5 | Step inside buildings (walk to door, camera in, InteriorView, back restores camera) | Done |
| 5 | Interior: region in header, journal entries open in the Library, Add a reflection, Share | Built |
| 6 | Read: books with progress, chapter grid with counts, "Text coming soon" | Done (inside the Library) |
| 6 | "What can I build?" incl. journeys a book counts toward | Fixed (journeys added) |
| 6 | Book-like reader, iPad two-page spread, deep dives | Done; John 15:13 deep dive Built |
| 6 | Reflect card after reading | Done (one of the quick-check options) |
| 6 | Library journals shelves; "My notes" for free entries; privacy note | Fixed (renamed, privacy line) |
| 7 | Fully customisable layered avatar (AvatarParts, AvatarRenderer, creator with tabs, Randomise, presets, Undo) | Built |
| 7 | Onboarding: welcome → age group → avatar | Built |
| 7 | AvatarConfig (Codable) with migration of old avatars | Built |
| 8 | 12 character journeys (CharacterJourneys.swift), level-map screen, stop cards | Built |
| 8 | Rarity-scaled unlock celebration, characters on island, "View journey" | Built (celebration existed; scaled) |
| 8 | Characters shelf in Profile, presets in the avatar creator | Built |
| 9 | Profile stats (rereads, most-read books, journeys completed), Characters shelf | Built |
| 9 | Crowns per full reread, throne room, cast crowns, new cycle | Done (world map); throne on the island Built |
| 9 | Share from Profile and InteriorView | Built |
| 9 | Settings: age group, "Reading unlocks apps" placeholder, privacy, DEBUG tools | Built |
| 10 | Friends preview (MockFriendsService), read-only island | Done; made pannable/tappable with shared notes (Fixed) |
| 10 | Groups (GroupsService, mock group, GROUPS.md) | Done |
| 11 | Art swap `bld_`, `art_`, `char_`, `_r0…_r3` | Done |
| 11 | Art swap `av_<layer>_<option>`, `int_<id>` | Built |
| — | VersionedSchema migration plan | Skipped (see NOTES) |
| — | #Preview on every screen | Built for every screen added or changed this run (Interior, Library hub, journeys, creator, Profile, Settings extras) |
| — | Views under ~250 lines | Partly: new views are split (InteriorSections, AvatarPartPicker, SettingsExtras, ProfileView); IslandView and HomeView remain larger (they hold the island's gestures and sheets) |
