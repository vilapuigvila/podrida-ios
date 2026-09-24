# Podrida Score

A scorekeeper for **Podrida**, the trick-taking card game where everyone calls how many hands they'll win each turn. It's a ledger: every player gets a column, every turn gets a line, and the running total stays pinned at the bottom.

It exists as a single self-contained web page and as an iOS app that wraps that page.

## Scoring

| Result | Points |
|---|---|
| Exact call | +5, plus 3 per hand won |
| Miss | −5, minus 3 per hand off |

In each turn, the hands called by all players can't add up to the turn number. The ledger warns you and won't move to the next turn until someone changes their call. Turns unlock one at a time, and the leader's total gets a "high score" stamp.

## Layout

```
podrida-score.html   The whole app: markup, styles and logic in one file
ios/                 SwiftUI app that hosts the page
  project.yml        XcodeGen spec (source of truth for the Xcode project)
  Podrida.xcodeproj  Generated project, committed so a fresh clone opens directly
  Podrida/           Swift sources, assets, Info.plist
```

The iOS target bundles `../podrida-score.html` by reference rather than keeping a copy, so changes to the web page ship in the next app build.

## Running

**Web:** open `podrida-score.html` in a browser. Nothing to build.

**iOS** (Xcode 26, iOS 17+):

```bash
open ios/Podrida.xcodeproj
```

Choose a simulator and run. To run on a device, set your team under *Signing & Capabilities*. The bundle ID is `com.albertvila.podrida`.

If you edit `ios/project.yml`, regenerate the project:

```bash
cd ios && xcodegen generate
```

## How the iOS app works

`ScoreWebView` loads the bundled page in a `WKWebView` and supplies what a plain browser doesn't:

- **Saving.** The page saves through an async `window.storage` API. The app injects that API and stores the data in `UserDefaults`, so a game in progress survives the app being closed. Opened in a plain browser, the page still works but doesn't save between reloads.
- **Screen fit.** The page is laid out edge to edge but stays clear of the notch and home indicator. The ledger fills the screen, so only the table scrolls and the buttons stay at the bottom.
- **Status bar.** Its text is light over the dark setup screen and dark over the paper-colored ledger.
- **No zoom when tapping a field.** Pinch-to-zoom is off as a result.
- **Screen stays on** during a game.

## Notes

- The fonts (Special Elite and IBM Plex Mono) load from Google Fonts. Without a connection the app falls back to Courier.
- Only iPhone portrait has been tested. Landscape and iPad are enabled.
