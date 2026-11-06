# Promised Land

An iOS app where reading the Bible grows an island. Everything (reading progress, the island,
journeys, the journal) stays on the device and works offline. The one exception is **Bible text**,
which loads from [API.Bible](https://docs.api.bible) one chapter at a time.

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

**Without a key** the app still builds and runs: the reader shows the small bundled American
Standard Version sample, and other chapters offer "Use my Bible".

Note: a key built into an app can be extracted from the app bundle by a determined person.
API.Bible's docs advise against putting keys in client-side code. For a public release, consider
a small server that holds the key and forwards chapter requests.

## Bible text

- **Translations**: NIV, NLT and CSB. On first run the app calls `GET /bibles?language=eng` and
  finds each by abbreviation (Bible ids are never hard-coded). A translation that isn't on your
  API plan is hidden, and Settings → Bible text says so. Pick one in Settings or in the reader's
  toolbar; the choice is remembered.
- **Fetching**: one chapter at a time, only when opened
  (`GET /bibles/{id}/chapters/{BOOK.N}?content-type=text&include-notes=false…`). The
  translation's copyright notice from the response is shown at the end of every chapter.
- **Cache**: each opened chapter is saved on the device per translation, with its fetch date
  (`Application Support/BibleText/<NIV|NLT|CSB>/<book>.<chapter>.json`). It's used for 30 days,
  then refreshed when online; offline the saved copy is always shown. Whole Bibles are never
  downloaded. Reading-time word counts and quick questions use the saved text, never the network.
- **Offline, nothing saved**: "Connect to the internet to load this chapter" with Retry (or the
  bundled sample for the few chapters that have one). Marking as read, the island and journeys
  keep working.
- **Errors**: rate limits (429) and a rejected key (401, or 403 "Invalid API key") get clear messages.
- **Usage**: DEBUG builds show API calls this month against the Starter plan's 5,000 in the reader
  and in Settings → Developer (which can also clear the cache).

## Tests

```sh
xcodebuild test -scheme "Promised Land" -destination 'platform=iOS Simulator,name=iPhone 17'
```
Bible text is tested with a mock `BibleService` and a mock HTTP transport. Tests never call the API.
