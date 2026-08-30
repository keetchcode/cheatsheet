# CheatSheet — Message Map

Narrative arc: **hook → core workflow → differentiator → depth/personalization →
retained value / companion surface**, plus one trust beat. No screen leads with
Settings, an empty state, or a permission prompt — none of those are the
product's value anyway (the app has none of the latter two beyond a plain
first-run empty state).

| # | Story role | Screen / state | Headline direction (3–7 words) | Search theme | Benefit | Source evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Hook | iPhone Home Screen, pinned widget visible | "The command you always forget" | quick notes widget | Glanceable, zero app-launch | `CheatSheetWidget.swift`, `widgetDisplayNote` |
| 2 | Core workflow | Note editor, heading + checklist mix | "Type it like you already do" | code snippet notes app | Markdown-ish syntax → real formatting, no learning curve | `DisplayLine.swift` parser |
| 3 | Differentiator | Editor header, palette + font picker | "Color-code by project" | customizable notes app | Visual organization without folders | `CheatSheetPalette` (10), `CheatSheetFontStyle` (4) |
| 4 | Depth / personalization | Trash detail, restore + countdown | "Deleted isn't gone for 30 days" | notes app with trash recovery | Forgiving, low-anxiety deletion | `NoteTrashPolicy.retentionInterval` |
| 5 | Retained value / companion surface | Split composition: Mac window + iPhone + iPad | "Native on Mac, iPhone, and iPad" | developer cheat sheet app mac iphone ipad | Same tool, no compromise, on every device you code on | `ContentView.swift` adaptive layout |
| 6 | Trust | Text-forward claim slide, app icon | "Nothing you write leaves your device" | private notes app no account | Verified: zero network calls, no account, empty privacy-collected-data declaration | `PrivacyInfo.xcprivacy`, prior audit's network-call grep |
| 7 | Bonus / Mac-set only | macOS menu bar quick capture | "Capture without breaking flow" | menu bar notes mac | Zero-friction capture mid-work | `MenuBarQuickAccessView.swift` |

## Rules applied

- No phrase repeats verbatim across headlines — each screen owns one distinct
  search theme; no keyword stuffing.
- Headlines 4–6 words, benefit-first, no feature-name jargon a non-technical
  reader would trip on ("pinned widget note" → "the command you always forget").
- Slide 6 (privacy) is a *verifiable* claim, not a generic "your privacy
  matters" platitude — cited against the actual manifest and audit findings.
- Slide 5 says **"native on"**, never "synced across" or "same notes
  everywhere" — per the no-cross-device-sync constraint in
  `feature-evidence.md`.
- Row order above is the default narrative order for the **iPhone** set. iPad
  and Mac sets reorder to lead with whichever row is strongest on that device
  (e.g. Mac set opens with row 5 or 7, not row 1, since there's no Home Screen
  widget on Mac in the same sense — Mac uses the menu bar + widget gallery).
