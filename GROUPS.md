# Groups: reading together

*Status: groundwork. The data types, a `GroupsService` protocol and a `MockGroupsService` exist
(`Groups.swift`), with one read-only sample group labelled **Preview** in Friends. There is no
backend, no accounts and nothing leaves the device. This note describes where it should go;
`GROUP_BUILDS.md` has the detailed growth rules for large groups.*

## What a group is

A youth group, church small group or family reading the Bible together. Each person keeps
**their own island**, which nobody else's reading changes. A group also has **one shared
island**, built by everyone's reading together.

## The shared island

- The same 66 plots, buildings, artifacts and story objects as a personal island.
- Every member's checked read counts. When several people read the same chapter, its artifact
  grows (levels 1–5, then the gentler group tiers in `GROUP_BUILDS.md`) instead of adding
  more objects, so a group of 60 doesn't bury the island.
- A book's building rises when the group, between them, has read every chapter. Floors are
  added as the group reads the book through again, scaled by group size.
- Characters arrive when the group finishes their books or journeys, with one shared
  celebration.
- The group island is read-only from each member's phone. A leader can rearrange it in edit
  mode (see Roles).

## Who read what

- Each plot can show who helped build it ("Hannah 50 ch · Joy 20 ch"), as the preview does.
  It's shown as encouragement, never as a ranking or leaderboard.
- Members can switch off showing their name, appearing as "a group member".
- Streaks stay personal. The group sees days when *someone* read, not who missed a day.

## Public and private

| Stays private, always | Shared only if you choose | Shared with the group by joining |
|---|---|---|
| Journal entries and reflections | A single journal entry or reflection, posted as a shared note | That you read a chapter (and when) |
| Quiz answers | Your quiz result for a book | Your character and name (or "a group member") |
| Your personal island layout | Your personal island (to friends) | |

Nothing private is uploaded. Shared notes are copies; deleting yours removes the shared copy.

## Viewing friends' islands

- Friends can look at each other's personal islands, read-only, as in the Friends preview.
- Mutual consent: both people accept before islands are visible.
- Tapping a building on a friend's island shows what they've built and which chapters they
  read, not their journal.

## Shared notes

- From any chapter, a member can post a short note or a reflection to the group.
- Notes appear on the group island beside the chapter's artifact, as a small lantern you can tap.
- Leaders can hide a note. Members can report one. Notes are text only, with no images or links,
  to keep moderation simple for young groups.

## Roles

- **Leader:** creates the group, invites by code, can arrange the group island, hide notes,
  and remove members.
- **Member:** reads, optionally posts notes, and sees the shared island.
- For under-13s, joining needs a parent or guardian's approval, and names default to hidden.

## What a backend needs to provide

`GroupsService` is the boundary the views use:

```swift
protocol GroupsService {
    func groups() async throws -> [GroupSummary]
}
```

A real service would add `join(code:)`, `leave(group:)`, `shareRead(_:)`, `postNote(_:)`
and live updates, implemented over the network (for example, CloudKit shared databases).
The island is drawn from `GroupSummary.combinedReads`, so the drawing code doesn't change.

## Open questions

- How are reads verified? (Today the quick check is honour-based.)
- Should the group island have its own plots arranged by a leader, or follow the default layout?
- Do groups have reading plans with a shared "this week" target?
