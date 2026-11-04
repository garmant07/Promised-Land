# Art assets

Everything on the island is drawn in code, in the "warm earthy, soft isometric" style from the
Promised Land art direction (the *Promised Land Art Styles* canvas). Any piece can be replaced
with hand-made art: add a PNG to `Assets.xcassets` with the right name and the app draws it
instead. No code changes are needed, and if an image is missing the code-drawn art is used.

## Names

| What | Name | Levels |
|---|---|---|
| A book's building | `bld_<bookID>_<level>` | `0` foundations (book opened, not finished) · `1` built · `2`–`4` built plus 1–3 extra floors from full rereads |
| A chapter artifact | `art_<kind>_<level>` | `1`–`5`, one per read of that chapter |
| A Bible character | `char_<id>` | one image (ids in `CharacterUnlocks.swift`: `moses`, `jonah`, `ruth`, `david`, `daniel`, `paul`, `disciples`, `jesus`) |

- `bookID` is the id in `BibleCatalog.swift`, e.g. `genesis`, `1samuel`, `songofsongs`.
- `kind` is an `ArtifactKind` raw value from `BuildingData.swift`: `olive`, `palm`, `cypress`,
  `bush`, `flowers`, `sheep`, `tent`, `well`, `scroll`, `jar`, `stele`, `altar`, `boat`,
  `fishBasket`, `wheat`, `vine`, `oilLamp`, `harp`, `domedHouse`.
- Examples: `bld_ruth_0`, `bld_ruth_1`, `bld_ruth_2`, `art_olive_3`, `char_moses`.

### Rotations

Once the island can turn (Phase 3), each name can also come in four views: append `_r0`,
`_r1`, `_r2` or `_r3` (0°, 90°, 180°, 270°), e.g. `bld_ruth_1_r1`. The plain name is used for
any rotation that has no image of its own.

## Format

- **Projection:** isometric 2:1, so a tile's diamond is twice as wide as it is tall, viewed
  from the front-left corner (the island's left faces are lit, right faces in shade).
- **File:** transparent PNG, sRGB.
- **Scale:** one island tile is **64 pt** wide. Supply @2x (128 px a tile) and @3x (192 px a
  tile). A building stands on one tile; it can be taller and a little wider than its tile.
- **Anchor:** bottom-centre. The middle of the image's bottom edge is placed on the centre of
  the object's ground tile, so leave no empty space under the object's base.
- **Style:** match the art direction: soft shapes with no outlines; sandstone walls
  (`#F4D6AA` left, `#E8C192` right, `#F9E4C0` tops); dark arched windows (`#9C6E4E`);
  terracotta roofs (`#E39A7E` / `#C97A60`); lavender domes (`#BFA9DA`) or golden domes
  (`#F0C88C`) with gold finials (`#E1B067`); olive trees (`#A9B47C`, trunks `#8E6A4C`); soft
  shadows (`#DCC193`) rather than hard ones.

## Included art

The characters drawn for the art direction (the *Character style* board) are in the asset
catalogue as `char_moses`, `char_ruth`, `char_david`, `char_daniel`, `char_paul`,
`char_jesus` and `char_disciples` (John's picture). Their cream backgrounds were cut out
and the stray pebbles removed. Jonah has no drawing yet, so he uses the code-drawn chibi
figure. Characters are drawn bottom-centre at their feet and scaled to the character's
height, so any size works; keep the figure standing on the bottom edge.

## What's drawn in code today

- **Buildings:** 66 specs in `BuildingData.swift`, one per book, each with a unique silhouette
  (family × roof × crest × width × storeys × wings), drawn by `BuildingArt` in `IslandArt.swift`.
- **Artifacts:** `ArtifactArt` in `IslandArt.swift`.
- **Story objects** (e.g. Noah's Ark for Genesis 6–9): `StoryArt` in `IslandArt.swift`, one
  drawing per `ChapterObjectKind`. To replace one, use the story's id from
  `ChapterLandmarks.swift` as the artifact id: `art_<storyID>_<level>`, level 1–5.
- **Rewards:** quiz banners, lanterns and fruit trees: `RewardArt` in `IslandArt.swift`
  (rules in `RewardData.swift`).
