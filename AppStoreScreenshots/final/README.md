# Final App Store screenshots — 1.2

Upload order is the filename order. iPhone files go in the **6.9"** slot, iPad
in the **13"** slot; App Store Connect scales every smaller size down from
these, so no other sizes are needed.

| File | Size | Eyebrow | Headline |
| --- | --- | --- | --- |
| iphone-01 | 1320×2868 | DEVELOPER CHEAT SHEET | Every command, one tap away |
| iphone-02 | 1320×2868 | MONOSPACED BY DEFAULT | Write commands in plain text |
| iphone-03 | 1320×2868 | TEN COLOR TINTS | Color-code notes by project |
| iphone-04 | 1320×2868 | FOUR FONT STYLES | Choose mono, serif, or rounded |
| iphone-05 | 1320×2868 | INSTANT SEARCH | Find any snippet as you type |
| iphone-06 | 1320×2868 | 30-DAY TRASH | Restore deleted notes for 30 days |
| ipad-01 | 2064×2752 | IPAD SPLIT VIEW | Browse and edit side by side |
| ipad-02 | 2064×2752 | FILTER AS YOU TYPE | Search every note instantly |
| ipad-03 | 2064×2752 | MONOSPACE AND SERIF | Choose the font that fits |

## How these were produced

1. **Capture** — `MarketingScreenshotTests` in the UI test target, run on an
   iPhone 17 Pro Max and an iPad Pro 13". It seeds `ScreenshotDemoContent` and
   only ever photographs that curated content.

   ```sh
   xcrun simctl status_bar <udid> override --time "9:41" \
     --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
   xcodebuild test -scheme CheatSheetiOSUI -destination "id=<udid>" \
     -resultBundlePath out.xcresult \
     -only-testing:CheatSheetiOSUITests/MarketingScreenshotTests
   xcrun xcresulttool export attachments --path out.xcresult --output-path raw/
   ```

2. **Compose** — `AppStoreScreenshots/templates/compose_screenshot.py` per the
   approved style in `../planning/style-direction.md`.

**Do not reuse `testQASweep` captures for the store.** That test creates a
throwaway "QA Sweep Note" with placeholder body text, so everything it captures
after its third checkpoint shows test data — which Apple treats as grounds for
rejection. `MarketingScreenshotTests` exists specifically to avoid that.

## Caption strategy

Apple began OCR-indexing screenshot caption text in June 2025, making captions a
Tier 1 ranking signal. Unlike title/subtitle, captions *should* reinforce core
keywords. Each headline is 4-6 words, leads with an action verb where it reads
naturally, and owns one distinct keyword theme (see `captions.tsv`). White on
the dark brand gradient keeps OCR contrast high.
