# Promised Land

An iOS app where reading the Bible grows an island. Everything (reading progress, the island,
journeys, the journal) stays on the device and works offline. The complete American Standard
Version (ASV) is built into the app. NIV, NLT and CSB load from
[API.Bible](https://docs.api.bible) one chapter at a time.

## Setting up the API.Bible key

The key is never committed. It lives in `Secrets.xcconfig`, which is gitignored.

1. Get a key: sign in at https://api.bible. Your key is in the top right corner of the dashboard.
2. In the project folder (next to `Config.xcconfig`), copy the example:
   ```sh
   cp Secrets.example.xcconfig Secrets.xcconfig
   ```
3. Open `Secrets.xcconfig` and replace the placeholder with your key, with no quotes:
   ```
   API_BIBLE_KEY = 0123456789abcdef0123456789abcdef
   ```
4. Build and run. (If Xcode was open, clean the build folder once: Product → Clean Build Folder.)

How it gets into the app: `Config.xcconfig` (the app target's base configuration) does
`#include? "Secrets.xcconfig"`, and `Info.plist` has `APIBibleKey = $(API_BIBLE_KEY)`.
`APIBibleService.fromBundle()` reads it.

**Without a key** the app still builds and runs with the complete built-in ASV. It is selected by
default and every chapter works offline.

Note: a key built into an app can be extracted from the app bundle by a determined person.
API.Bible's docs advise against putting keys in client-side code. For a public release, consider
a small server that holds the key and forwards chapter requests.

## Bible text

- **Translations**: ASV is built in, public domain and always available offline. NIV, NLT and CSB
  come from API.Bible. On first run with a key the app calls `GET /bibles?language=eng` and finds
  each API translation by abbreviation (Bible ids are never hard-coded). A translation that isn't
  on your API plan is hidden, and Settings → Bible text says so. Pick one in Settings or in the
  reader's toolbar; the choice is remembered.
- **Default**: new installs and installs without an available API translation use ASV. Existing
  saved translation choices are kept when that translation is available.
- **Built-in ASV**: one bundled JSON resource per book is loaded only when a chapter from that book
  opens. It never uses the network or the `Application Support/BibleText/` cache. Every chapter ends
  with “American Standard Version (1901). Public domain.”
- **Fetching**: one chapter at a time, only when opened
  (`GET /bibles/{id}/chapters/{BOOK.N}?content-type=text&include-notes=false…`). The
  translation's copyright notice from the response is shown at the end of every chapter.
- **API cache**: each opened API.Bible chapter is saved on the device per translation, with its fetch date
  (`Application Support/BibleText/<NIV|NLT|CSB>/<book>.<chapter>.json`). It's used for 30 days,
  then refreshed when online; offline the saved copy is always shown. Whole Bibles are never
  downloaded from API.Bible. Reading-time word counts and quick questions use text already on the
  device, never the network.
- **Offline, nothing saved**: an API translation falls back to the built-in ASV. Selecting ASV
  directly is always fully offline.
- **Errors**: rate limits (429) and a rejected key (401, or 403 "Invalid API key") get clear messages.
- **Usage**: DEBUG builds show API calls this month against the Starter plan's 5,000 in the reader
  and in Settings → Developer (which can also clear the cache).

## Tests

```sh
xcodebuild test -scheme "Promised Land" -destination 'platform=iOS Simulator,name=iPhone 17'
```
Bible text is tested with a mock `BibleService` and a mock HTTP transport. Tests never call the API.

## Imported chapter questions

The approved question exports live in `QuestionSource/`. To regenerate all 66 bundled book files
after those documents change, run this from the repository root:

```sh
swift Tools/QuestionImport/main.swift --generate
```

The command performs the Stage 0 dry-run report and then writes the JSON resources to
`Promised Land/Questions/`. The converter is not part of the app target. Questions load lazily
one book at a time when a chapter's reading check opens; the quiz selects three of that chapter's
eight questions and creates fill-in word chips at that point.
