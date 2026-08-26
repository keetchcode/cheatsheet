# App Store Screenshots

Marketing screenshots for App Store Connect, generated from the real app.

```text
raw/<device-class>/    Native-resolution simulator captures (no chrome)
final/<device-class>/  Upload these — background, device frame, caption
contact-sheet.png      Every export at search-result thumbnail width
```

Only `final/` is kept in version control. Raw captures and the contact sheet are
reproducible working files ignored by Git, which keeps the public repository
small while preserving the exact upload-ready exports.

Everything inside the device frame is a genuine capture of the running app. The
only thing the capture run changes is note content, seeded from
`CheatSheetApp/Sources/CheatSheetDemoContent.swift` via the Debug-only
`-cheatsheet-demo-content` launch argument.

## Captions

Apple began OCR-indexing screenshot text in June 2025, so captions are now a
ranking surface, not just decoration. Each slide therefore carries one short,
high-contrast, keyword-bearing line rather than a clever one:

| # | Slide | Headline | Keywords it adds |
|---|---|---|---|
| 1 | Editor | Save The Commands You Forget | commands, code snippets |
| 2 | Widget | Pin Notes To Your Home Screen | home screen, widget, notes |
| 3 | Notes list | A Cheat Sheet For Every Tool | cheat sheet, git, docker, vim, xcode |
| 4 | Checklist | Turn Notes Into Checklists | checklists, release |
| 5 | Styling | Ten Colors, Four Code Fonts | colors, code fonts, monospace |
| 6 | Search | Search Every Note Instantly | search, light mode, dark mode |
| 7 | Onboarding | Free, Offline, Open Source | free, offline, open source, no ads |

Rules the set follows: 3–7 words per headline, one idea per slide, the strongest
three first (search results show only those), white on the darkest part of the
background for OCR contrast, and identical composition across both device
classes. `verify-app-store-screenshots.py` enforces the word counts.

## Regenerate

```sh
Scripts/capture-app-store-screenshots.sh
Scripts/capture-widget-screenshot.sh
Scripts/compose-app-store-screenshots.py
Scripts/verify-app-store-screenshots.py
```

1. **capture-app-store-screenshots.sh** runs `AppStoreScreenshotUITests` on the
   iPhone 17 Pro Max (1320×2868) and iPad Pro 13-inch (2064×2752) simulators,
   whose native screen sizes already equal what App Store Connect requires.
   It shoots two passes per device — the dark set, then one light-appearance
   shot — flipping the simulator with `simctl ui appearance`. Pass a device
   class (`iphone-6.9`, `ipad-13`) to shoot just one.
2. **capture-widget-screenshot.sh** creates a disposable simulator, seeds its
   shared App Group with a signed build, then drives SpringBoard to add the widget and shoot the Home Screen.
   This one needs a signed build — the widget cannot read the note without the
   App Group entitlement. It writes into the same `raw/` directory, which is why
   the other script overwrites by name instead of clearing the folder.
3. **compose-app-store-screenshots.py** first requires the complete raw set,
   then draws each capture into a temporary device-frame set and atomically
   replaces the previous finals only after every image succeeds.
4. **verify-app-store-screenshots.py** re-checks pixel sizes, PNG/RGB/no-alpha,
   the 10 MB and 1–10-per-class limits, and caption length, then rebuilds the
   contact sheet.

## Uploading

Upload `final/iphone-6.9/` to the 6.9" iPhone slot and `final/ipad-13/` to the
13" iPad slot, in filename order. App Store Connect scales the 6.9" set down for
every smaller iPhone, so no other iPhone size is required.
