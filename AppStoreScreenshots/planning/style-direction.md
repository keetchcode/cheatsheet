# CheatSheet — Approved Screenshot Style Direction

**Decision:** Brand Gradient backdrop, eyebrow + headline caption, full-bleed
canvas with the device cropped at the bottom edge. Approved 2026-08-30 in two
passes:
1. Backdrop/palette choice — 3-option comp
   (`cheatsheet-screenshot-style-directions.html`).
2. Caption layout — the first pass had the caption overlaid *on top of* the
   device screen, overlapping real UI (correctly flagged as "crowded and not
   readable"). Rebuilt against real reference examples the user supplied
   (Claude, Eight Sleep, Nibble, Arc Search app-store screenshots) as a
   full-bleed canvas with the caption in dedicated space above the device,
   never overlapping — approved as "eyebrow + headline"
   (`cheatsheet-screenshot-style-v2.html`).

Do not re-litigate this choice in later work on this feature — extend it.
The working, reproducible implementation is
`AppStoreScreenshots/templates/compose_screenshot.py` — use it, don't
re-derive the layout by hand.

## System

- **Canvas**: full-bleed, exact required pixel size per device class (no
  rounded corners, no border, no card chrome on the canvas itself — this
  file IS the exported screenshot).
- **Backdrop**: `linear-gradient(165deg, #141923 0%, #1A2130 55%, #0D111C 100%)`
  — the app's own real `AppTheme.windowGradient` dark-mode stops
  (`CheatSheetApp/Sources/AppTheme.swift`), not an invented marketing color.
- **Caption zone**: top ~11% padding, left/right ~8% padding, left-aligned
  (not centered — matches the reference examples).
  - Eyebrow: ~3.2% of canvas width, SF Semibold, uppercase, manual letter
    tracking, color `#7FA6FF`.
  - Headline: ~8.8% of canvas width, SF Bold, line-height ~1.08, white,
    wrapped to fit the available width — one short benefit-first line where
    possible, two at most.
  - No subhead, no floating chip/pill badge over the device — both read as
    clutter against the reference examples; the eyebrow alone carries the
    "search theme" tag role.
- **Device frame**: drawn bezel (metal-gradient edge, rounded per device
  aspect, dynamic-island cutout for iPhone) at ~92% of canvas width,
  positioned so roughly the bottom ~9% of the device extends past the canvas
  edge — matches every one of the reference examples' "cropped, not
  floating" technique. Real captured app screen inside, never re-tinted to
  match the backdrop.
- **Type**: system San Francisco (`/System/Library/Fonts/SFNS.ttf`, variable
  font, Bold/Semibold instances) — matches the app's own actual UI
  typography exactly, not an imported web font.

## Applies to

The full 16-concept shortlist in `shortlist.md`, across iPhone, iPad, and
Mac. iPad reuses the same phone-style bezel proportions adjusted for its own
aspect ratio; Mac needs a different frame treatment entirely (no phone
bezel — a window-chrome or bezel-free full-bleed treatment, since Mac
screenshots aren't phone-shaped) and hasn't been designed yet.

## Localization

Once the English final set is approved end-to-end, produce a Spanish-
captioned twin: same backdrop/device/screen captures,
eyebrow + headline text translated, per
`Docs/app-store-localization-es.md`'s recommendation to target Spanish
(Mexico) only.
