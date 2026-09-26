# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Podrida Score: a scorekeeper for the Podrida card game, built twice with no shared code. `podrida-score.html` is the web version: one file, no dependencies. `ios/` is a native SwiftUI app. A rules change has to be made in both.

## Commands

```bash
# Web: open the file directly, nothing to build
open podrida-score.html

# iOS: regenerate the Xcode project after editing ios/project.yml
cd ios && xcodegen generate

# iOS: build, run all tests (unit + UI), run one test
xcodebuild -project ios/Podrida.xcodeproj -scheme Podrida \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild test -project ios/Podrida.xcodeproj -scheme Podrida \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -project ios/Podrida.xcodeproj -scheme Podrida \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  '-only-testing:PodridaTests/TurnFlowTests/addingAPlayerReopensFinishedTurns()'

# iOS: run the Maestro flows in ios/.maestro/ against a booted simulator
maestro test ios/.maestro/
```

`.github/workflows/ios-tests.yml` runs the unit and UI tests on a `macos-15` runner, on any iPhone simulator it has, whenever a push touches `ios/`.

The unit tests use Swift Testing, so a single test's `-only-testing` name needs the trailing `()`. Without it, the command matches nothing and still reports success.

`ios/project.yml` (XcodeGen) is the source of truth for the Xcode project. Edit it rather than `project.pbxproj`, then regenerate. The generated project is committed so a fresh clone opens without XcodeGen. The one dependency is Lottie (`airbnb/lottie-spm`, Swift Package Manager, declared under `packages:` in `project.yml`). The web version has no tests.

## Game rules (both versions)

- Each Score cell shows the points the player scored that turn, and the Total row adds them up. An exact call scores 5 + 3 per hand won; a miss scores −5 − 3 per hand off.
- Turn n deals n hands, so no one can call more than n, its hands won can't add up to more than n, and once everyone's result is in they must add up to exactly n.
- The active turn is the first incomplete one, and later turns are locked. A turn is complete when every cell is filled, no call is over the turn number, the calls don't add up to it, and the hands won do. Adding a player adds empty cells to earlier turns, so they reopen.

## Web app (`podrida-score.html`)

It's a single IIFE with one mutable `state` object: `numPlayers`, `numTurns`, `playerNames[]`, `hands[turn][player]`, `won[turn][player]` and `started`. An empty cell is `null`.

- `renderSetup()` and `renderLedger()` rebuild `#app` with `innerHTML` and re-bind every listener. Typing in a cell doesn't re-render; it patches the DOM through `refreshCellScore`, `updateTotalsRow`, `updateRowLocks` and `updateHandsWarning`.
- The rules are in `computeCellScore`, `getActiveTurnIndex`, `findCallOverTurn`, `checkHandsSumViolation` and `checkWonSumViolation`. All rule warnings share the one banner, `updateHandsWarning`.
- It saves through a host-provided async `window.storage.get/set/delete(key, shared)` under the key `scorekeeper:state`. In a plain browser that API is missing and saving silently does nothing.

## iOS app (`ios/Podrida`)

Swift 6 language mode (strict concurrency), iOS 18+. `onScrollGeometryChange` and `TextField(text:selection:)` require iOS 18.

- **`Model/Game.swift`** is the whole rule set as a value type: scoring, totals, leaders, trailers, turn completion, and add/reset. Views never compute rules themselves. `Game`'s coding keys (`playerNames`, `hands`, `won`) match the web state on purpose; see saving below. `leaders`/`trailers` are the top/bottom total, each empty until any score is in, and `trailers` is also empty when every total is tied; `LedgerGrid`'s totals row colors the leader `Palette.green` (keeping the brass "high score" stamp) and the trailer `Palette.rule`. iOS only — the web version doesn't do this.
- **`Model/GameStore.swift`** holds `game: Game?` (`nil` shows setup) and saves it to `UserDefaults` in a `didSet`. On first launch it moves a game saved by the old web-view version of the app (key `webstorage.scorekeeper:state`, the web state JSON) into the native key.
- **`RootView`** hands the ledger a hand-built `Binding<Game>`, not `Binding($store.game)`. After New Game sets the game to `nil`, SwiftUI still reads the old ledger's binding once, and the force-unwrapping binding crashes. The custom one falls back to the last game and drops late writes.
- **`LedgerGrid`** pins the player names, the turn numbers and the totals row by keeping them outside the one two-axis `ScrollView` and offsetting them by its scroll position (`ScrollOffset`, read only by `Synced`). A pinned piece must use `.frame(minWidth: 0, …)` or `.frame(minHeight: 0, …)` before `.clipped()`. Without the zero minimum, the frame grows to its content's full size and pushes the totals off screen. Row height is a fixed constant shared by the turn column and the cells, so the two stay aligned.
- **Onboarding** (`Views/Onboarding/`): four pages shown on first launch and again from "How it works" on the setup screen, gated by the `hasSeenOnboarding` UserDefaults key. It takes the setup screen's place only, never the ledger's, so it can't interrupt a game in progress. Each page plays a Lottie animation from `Resources/Animations/` and names its music track. `OnboardingMusic` loops the tracks in `Resources/` and crossfades when the page's track changes: jazz for the first three pages, chiptune for the last. It uses the ambient audio category, so the silent switch mutes it. The animations and the music are generated by `ios/tools/make_animations.py` and `ios/tools/make_music.py`. Edit the scripts and rerun them rather than hand-editing the JSON. `make_music.py` has four styles (guitar, musicbox, jazz, chiptune); `APP_TRACKS` maps each file the app ships to its style, and `--style` writes any one of them for listening. Every file is normalized to -1 dBTP true peak, and the in-app volumes (`OnboardingMusic.Track.volume`, `ScoreSounds`) set the loudness. Keep the music's energy above ~500 Hz and cut the low end: below that, a phone speaker strains and distorts even when the Mac sounds fine.
- **Broken rules (iOS)** block the ledger instead of just warning. `Game.brokenRule` is the active turn's broken rule: a call over the turn number, calls adding up to it, or too many or too few hands won. While there is one, `LedgerGrid` leaves only the numbers it's about editable (that turn's calls, or its results); names, New Game and the actions are disabled. `LedgerView` shows the rule alert whenever the keyboard leaves those numbers, including with Done, or after a one-second pause in typing, so a two-digit number isn't interrupted. The alert's button sends the keyboard back to the number entered last, selected. Score sounds don't play while a rule is broken. `PodridaUITests/RuleAlertUITests` drives the rules end to end. It seeds a game through launch arguments (`-game <hex>`, `-hasSeenOnboarding YES`), which land in UserDefaults' argument domain. The web version still shows a banner.
- **`BlockingAlert.swift`** replaces every system `.alert`: the rule alert above and the New Game /
  Reset Scores confirmations. It's an in-app card (`Theme.swift` styling, a warning emoji and
  `Palette.rule` accent on the rule alert) shown through `.overlay`, not `.alert`, so it never takes
  first responder — the keyboard stays up under it. It dims and hides the rest of the screen from
  accessibility (`.accessibilityAddTraits(.isModal)`) and carries the `blockingAlert` accessibility
  identifier, which the UI tests and Maestro flows use to find it instead of `app.alerts`.
  `LedgerGrid`/`TurnCell` take an `isInputBlocked` flag that freezes a cell's value while the
  overlay shows, and a `reselectCount` the alert's button bumps to reselect a number when the field
  it's returning to already has focus (the keyboard never left, so refocusing the same field
  wouldn't otherwise trigger a reselect). `ios/.maestro/` drives all of this against a real
  keyboard and simulator (`maestro test ios/.maestro/`).
- **Score sounds:** `ScoreSounds` plays `Resources/score-gain.caf` when an edit gives a cell positive points and `score-loss.caf` when negative (`Game.newlyScoredPoints(since:)`), after a 0.6 s pause so a two-digit entry plays once. Ambient audio, so the silent switch mutes them. Generated by `make_music.py` with the music.
- **Editing:** only the active turn's row, plus a turn the keyboard is still in, gets `TextField`s; every other cell is plain `Text`. `LedgerField.next/previous` defines the keyboard order: all calls, then all results, then on to the next turn only if this one is complete.

## App Store (`ios/AppStore`)

Listing text (fastlane `deliver` layout under `metadata/`), captioned screenshots, the privacy policy text, `ExportOptions.plist`, and `README.md`, the submission checklist. After a UI change, regenerate the screenshots with `ios/AppStore/tools/capture.sh`. It seeds the demo games from `tools/states.py` into the app's saved state on an iPhone 17 Pro Max and an iPad Pro 13" simulator, captures four screens, and captions them with `tools/frame.py`. It sets `hasSeenOnboarding` first so the introduction doesn't cover the captures. To reset the app's saved state on a simulator, uninstall the app: `defaults delete` on its preferences file doesn't stick, because the simulator's `cfprefsd` keeps the old values cached. The support and privacy pages live in the separate public repo `vilapuigvila/podrida-score` (GitHub Pages), because this repo is private. `privacy-policy.md` must match its `privacy/index.html`. `Podrida/PrivacyInfo.xcprivacy` must keep declaring UserDefaults (reason CA92.1) while the app uses it. The signing team is set in `project.yml`, so regenerating keeps it.

`.github/workflows/testflight.yml` is a manual (`workflow_dispatch`) release: it bumps `MARKETING_VERSION`'s patch number with `ios/tools/bump_marketing_version.py` (1.0.0 → 1.0.1 → …), regenerates the Xcode project, commits and tags that bump on `main`, then archives and uploads to TestFlight. `ExportOptions.plist` has `manageAppVersionAndBuildNumber` set, so the build number itself (`CURRENT_PROJECT_VERSION`) isn't touched here — Xcode asks App Store Connect for the next one during export. It needs three repository secrets (Settings → Secrets and variables → Actions, not Xcode Cloud's own environment): `APP_STORE_CONNECT_KEY_P8` (the `.p8` file, base64-encoded), `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`. If Xcode Cloud also has a workflow that archives and uploads on every push to `main`, the commit this workflow pushes will trigger that one too — fine for a solo project, but worth knowing before running both.

## Published artifact

A private claude.ai artifact, https://claude.ai/code/artifact/8b82c550-d0af-4a1c-bd01-39dad39e2de7, runs an adapted copy of the web page that isn't in this repo. That copy saves to `localStorage` instead of `window.storage`, and it has no document skeleton because the artifact host adds one. Editing `podrida-score.html` doesn't update the artifact. In artifacts, load Google Fonts with a `<link>` tag: the host's URL rewriting breaks a CSS `@import`.
