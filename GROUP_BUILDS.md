# Group builds — design note

*Status: idea only. No code yet. Written for Promised Land's next stage, once there is a backend.*

## The goal

A youth group (or church, or family) reads together and builds **one shared world**. It should
feel good for a group of 4, and still feel good for 60+ readers, without the world filling up or
running out of things to build.

## Principles

1. **Every read still counts.** Each member's reading changes the shared world, however small.
2. **Add to what exists, don't multiply objects.** With 60 readers, a new object per read would
   bury the map within days. Instead, reads add *depth* to a fixed set of shared structures.
3. **Personal and shared stay separate.** Each person keeps their own island and world. The group
   world is a second, shared place, so nobody's personal progress depends on others.
4. **Encourage, don't rank.** Show what the group built together, not leaderboards.

## Shared structures with tiers

The group world uses the same 66 landmarks and the story objects (ChapterLandmarks.swift), but
each has many more growth tiers, driven by the **group's total reads**, scaled by group size:

| Tier | Group reads of that book (per member, averaged) | Visual |
|------|------------------------------------------------|--------|
| 1    | first read by anyone                            | foundations |
| 2–5  | 0.25 → 1.0                                      | building rises |
| 6–10 | 1.0 → 3.0                                       | decorations, gardens, lanterns |
| 11+  | beyond 3.0                                      | banners, crowds, glow — slowly, with no cap |

Normalising by group size means a group of 60 doesn't max out a landmark on day one, and a group
of 4 still sees steady growth.

## Per-read contributions (so 60 readers never run out)

- **Bricks and lanterns**: every read lays a "brick" in the book's shared landmark (counted, not
  drawn individually). Brick counts drive the tiers above.
- **Story objects deepen**: rereads by anyone add depth (as today, but up to many more levels,
  shown as small additions, e.g. more boats, more vine rows, more lanterns along a road).
- **Roads wear in**: connections between books get wider and more travelled as more members read
  both books.
- **Daily group goal**: e.g. "40 chapters today". Reaching it lights the evening sky over the group
  world (stars, then a festival of lanterns). Resets daily, so there's always something to do.

## Seeing each other

- Members' avatars appear in the group world, walking to whatever they last built.
- A gentle feed ("Ana added to the Vineyard · John 15") instead of rankings.
- Tapping an object shows *who* helped build it (names only, if they've opted in).

## Scale and data

- Store **counts per (group, book, chapter)** and a small recent-activity log. Not every read row.
  60 members × 1,189 chapters is still tiny as counters.
- Clients fetch aggregated counts and render locally with the same painters used today.
- Abuse limits: cap counted reads per member per day (e.g. 20), so the shared world reflects
  reading, not tapping.

## Privacy

- Journal entries are never shared.
- Group membership, names and avatars are opt-in; leaving a group removes your name from the feed.

## Fit with the current code

- `FriendsService` (Friends.swift) is the seam for a backend; a `GroupService` would follow the
  same protocol pattern.
- `GameProgress` already derives everything from reads; a `GroupProgress` would derive the same
  stages and depths from aggregated counts instead.
