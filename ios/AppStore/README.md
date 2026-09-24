# Publishing Podrida Score on the App Store

Everything App Store Connect asks for is in this folder, apart from the parts only you can do in App Store Connect.

```
metadata/                  Listing text (fastlane `deliver` layout)
  en-US/name.txt             App name (30 max)
  en-US/subtitle.txt         Subtitle (30 max)
  en-US/promotional_text.txt Promotional text (170 max, editable any time)
  en-US/description.txt      Description
  en-US/keywords.txt         Keywords (100 max, comma-separated)
  en-US/release_notes.txt    What's New (App Store Connect doesn't ask for it on 1.0; kept for 1.1)
  en-US/support_url.txt      Support page URL
  en-US/privacy_url.txt      Privacy policy URL
  copyright.txt, primary_category.txt, secondary_category.txt
screenshots/
  iphone-6.9/                1320 × 2868, iPhone 6.9" (App Store Connect scales these down for smaller iPhones)
  ipad-13/                   2064 × 2752, iPad 13" (required because the app runs on iPad)
privacy-policy.md          Text for the privacy policy page
ExportOptions.plist        For uploading from the command line
tools/                     Regenerates the screenshots (see the end of this file)
```

The app icon (light, dark and tinted) is already in `Podrida/Assets.xcassets`. The privacy manifest, `Podrida/PrivacyInfo.xcprivacy`, declares that the app collects no data and gives Apple's approved reason (CA92.1) for its UserDefaults use.

## Support and privacy pages

Both URLs point at the public repo [vilapuigvila/podrida-score](https://github.com/vilapuigvila/podrida-score), served by GitHub Pages. This repo is private, so it can't host them.

- Support: https://vilapuigvila.github.io/podrida-score/
- Privacy policy: https://vilapuigvila.github.io/podrida-score/privacy/

`privacy-policy.md` is the same policy text. If you change it, update `privacy/index.html` in that repo to match; pushing publishes it.

## 1. Create the app record

In [App Store Connect](https://appstoreconnect.apple.com) → Apps → **+** → New App:

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | Podrida Score (must be unique on the store; if taken, try "Podrida Scorekeeper") |
| Primary language | English (U.S.) |
| Bundle ID | `com.pskmoons.podrida` (register it under Certificates, Identifiers & Profiles → Identifiers first, or it won't be in the list) |
| SKU | `podrida-score` |
| User access | Full access |

## 2. Upload a build

In Xcode, choose **Any iOS Device** as the destination, then **Product → Archive**, and **Distribute App → App Store Connect → Upload**.

Or from the terminal, in `ios/`:

```bash
xcodebuild archive -project Podrida.xcodeproj -scheme Podrida -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Podrida.xcarchive
```

```bash
xcodebuild -exportArchive -archivePath build/Podrida.xcarchive \
  -exportOptionsPlist AppStore/ExportOptions.plist -exportPath build/export
```

Each upload needs a new build number: raise `CURRENT_PROJECT_VERSION` in `project.yml` (and `MARKETING_VERSION` for a new version), then run `xcodegen generate`. Export compliance is already answered: `ITSAppUsesNonExemptEncryption` is `false`, so App Store Connect won't ask.

## 3. Fill in the listing

Paste from `metadata/en-US/` into the version page, and upload `screenshots/iphone-6.9` and `screenshots/ipad-13`, in file order. Then:

- **Category:** Utilities (primary), Entertainment (secondary). It's a scorekeeper, not a game, so Games would risk a review rejection.
- **Copyright:** `2026 Albert Vila`
- **Price:** Free (Pricing and Availability)

## 4. App Privacy

App Privacy → Get Started → **"No, we do not collect data from this app."** That matches the privacy manifest: the game is saved only on the device and nothing is sent anywhere.

## 5. Age rating

Answer **None / No** to every question: no violence, mature themes, gambling, user-generated content, web access, messaging or ads. The result is **4+**. The app keeps score and doesn't involve betting, so "Simulated gambling" is also No.

## 6. App Review information

- **Sign-in required:** No
- **Notes:**

  > Podrida Score is a scorekeeper for Podrida, a trick-taking card game. It works offline with no account. To try it: tap "Open the Ledger", then for turn 1 enter each player's "Hands" (their call) and "Won". The score and total update as you type. If the calls in a turn add up to the turn number, the app shows a warning and won't move on until one is changed; that's a rule of the game.

- **Contact:** your name, phone and email

Then **Add for Review → Submit**.

## Regenerating the screenshots

After a UI change:

```bash
ios/AppStore/tools/capture.sh
```

The script builds the app and seeds demo games (`tools/states.py`) into an iPhone 17 Pro Max and an iPad Pro 13" simulator; it creates the iPad simulator if needed. It captures four screens on each, then adds the captions (`tools/frame.py`) into `screenshots/`. The captions are in `frame.py`. It needs Xcode and Pillow (`pip install pillow`).
