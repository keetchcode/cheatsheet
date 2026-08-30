# CheatSheet — Feature Evidence Table

Source repo: `/Users/wesleykeetch/Documents/Developer/CheatSheet`, branch
`feature/app-store-screenshots` off `develop`. Every row below is verified
against actual source, not assumed.

## Inputs (Phase 0)

| Input | Value | Basis |
| --- | --- | --- |
| `{APP_NAME}` | CheatSheet | `project.yml` `CFBundleDisplayName` |
| `{REPO_PATH}` | `/Users/wesleykeetch/Documents/Developer/CheatSheet` | — |
| `{OUTPUT_DIR}` | `./AppStoreScreenshots` | this directory |
| `{TARGET_USER}` | A developer mid-task — terminal or editor open — who needs a command or snippet they always forget | README: "keeping short coding notes, checklists, and command reminders close by"; starter notes are `git status` / `git switch -c` / `xcodebuild` style commands, not generic to-dos; onboarding copy: "Keep the coding commands you reach for every day close at hand." |
| `{PRIMARY_SEARCH_INTENT}` | "developer cheat sheet app" | App is a named-genre utility (cheat sheet), scoped explicitly to coding use per README/onboarding/starter content, category `public.app-category.productivity` |
| `{SECONDARY_SEARCH_INTENTS}` | "quick notes widget for iPhone" · "git commands cheat sheet" · "code snippet notes app" · "sticky notes for developers" · "command line reference widget" | Widget feature, Git Flow starter note, checklist/command formatting, menu bar quick capture |
| `{TOP_FEATURES}` | see Selected Features below | — |
| `{DEVICE_SUPPORT}` | iPhone + iPad + Mac | `project.yml`: `CheatSheetiOS` has `TARGETED_DEVICE_FAMILY: "1,2"`; a separate full `CheatSheet` macOS target also exists — brief's iPhone/iPhone+iPad enum doesn't cover this app; extended to include Mac |
| `{BRAND_SOURCE}` | App's own `AccentColor` + `CheatSheetPalette` (10 swatches) + Liquid Glass material system with material fallback | `Shared/Sources/CheatSheetNote.swift`, `CheatSheetApp/Sources/ViewModifiers.swift`, `AppDesign.swift`, `AppTheme.swift` |
| `{TONE}` | Calm, precise, native — a quiet utility, not a flashy consumer app | README Product Principles: "deliberately narrow," "local-first," "No sync, collaboration, rich-document, or account system without a separate product decision"; in-app empty states use plain `ContentUnavailableView`, no marketing chrome |
| `{LOCALIZATION}` | Primary: English (`en`, `sourceLanguage` in both `.xcstrings` catalogs). Follow-on: Spanish (`es`, "neutral international Spanish" per README), verified complete by `Scripts/verify-localization.sh` and covered by `CheatSheetiOSSpanishLocaleUITests` in CI | `CheatSheetApp/Resources/Localizable.xcstrings`, `CheatSheetWidgets/Resources/Localizable.xcstrings`, `.github/workflows/ci.yml` |

## Product constraint list (honest, per Phase 1.5)

- **No accounts, no login screen, no auth flow of any kind** — nothing to capture there; also means "no account needed" is a safe, true claim.
- **No network access at all** — zero `http(s)://` calls in source (verified previously by full-repo grep). No server-dependent screens exist to capture or avoid.
- **No cross-device sync** — App Group sharing is scoped to *one platform's* app ↔ its own widget, not device-to-device. **Do not claim "same notes everywhere"** — that would be false. Safe claim: "native on Mac, iPhone, and iPad," not "synced across."
- **No paid tier / IAP / subscription** — nothing to gate or disclaim.
- **No push notifications, no deep links, no Sign in with Apple** — none exist; not a capture gap, just absent by design.
- **Starter/demo content exists and is safe to show**: `CheatSheetNote.starterNotes` ("Widget Formatting Demo," pinned, indigo; "Git Flow," cyan) are real, shipped, privacy-safe seed content — ideal for deterministic, reproducible captures instead of inventing fake note text.
- **Existing marketing screenshots** (`Docs/Images/*.png`) are mostly good reference material — `cheatsheet-iphone.png`, `cheatsheet-ipad.png`, `cheatsheet-iphone-widget.png`, `cheatsheet-widget-gallery.png` are accurate and on-brand (verified during the earlier release audit). `cheatsheet-desktop-overview.png` is broken (shows an unrelated system widget, not the app) — do not reuse it as a reference; the Mac shot must be recaptured clean.

## Selected top features (used for ASO / message map)

| # | Feature | File(s) | Real user benefit | Capture state | Screenshot-safe? |
| --- | --- | --- | --- | --- | --- |
| 1 | Pin one note to the Home Screen / menu bar widget | `EditorHeader.swift` (pin button), `CheatSheetWidget.swift` (`.systemSmall/.systemMedium/.systemLarge`), `CheatSheetNote.widgetDisplayNote` | The one command you always forget is one glance away, no app launch | iPhone Home Screen with the "Git Rescue"-style pinned widget visible | Yes — real, shipped feature |
| 2 | Automatic checklist & heading formatting | `DisplayLine.swift` (`parsedChecklistLine`), `ChecklistLineView.swift` | Type `- [ ]` and `#` like you already do; it renders as real checklist rows and headings, no special editor | Note editor/preview with a mix of heading + checked + unchecked lines | Yes |
| 3 | 10 colors × 4 fonts per note | `GlassPalettePicker.swift`, `FontStylePicker.swift`, `CheatSheetPalette` (10 cases), `CheatSheetFontStyle` (4 cases) | Color-code by project/language at a glance | Editor header with the palette row visible/expanded | Yes |
| 4 | 30-day Trash with restore | `TrashNoteView.swift`, `NoteTrashPolicy.retentionInterval` (30 days) | Deleted a note by accident? It's recoverable, not gone | Trash detail view showing "Deletes automatically in N days" + Restore | Yes |
| 5 | 100% private — no account, no tracking, no network | `PrivacyInfo.xcprivacy` (both targets, empty `NSPrivacyCollectedDataTypes`, `NSPrivacyTracking: false`), zero network calls in source | Notes never leave the device | Text-forward claim slide (no login screen exists to show *because there isn't one*) | Yes — verifiable claim |

## Additional real, evidenced flows (not in the top-5 ASO set, available as alternates)

| Feature | File(s) | Capture state |
| --- | --- | --- |
| Mac menu bar quick capture | `MenuBarQuickAccessView.swift` | macOS menu bar dropdown, quick-capture field + recent notes list |
| Native per-platform layout (iPad split view, Mac window, compact iPhone) | `ContentView.swift` (`splitRoot`/`compactRoot`) | Side-by-side device composition — real cross-surface feature, not invented |
| Search notes | `SidebarView.swift`, `CompactNoteListView` (`.searchable`) | Sidebar/list with search field active and a filtered result |
| Light & dark mode | `AppTheme.swift` (branches on `colorScheme`) | Same screen captured twice |
| Spanish localization | `Localizable.xcstrings` × 2, `CheatSheetiOSSpanishLocaleUITests` | Same shortlisted screens, es locale, for the Spanish storefront set only |

## Localization cross-reference (found mid-task, folded in)

`Docs/app-store-localization-es.md` (prepared by prior work on this same
release branch) already covers Spanish App Store Connect metadata and
explicitly anticipates this exact screenshot question: *"App Store Connect
lets a Spanish (Mexico) localization reuse the same screenshot images as
English if you don't want to caption them separately... Only recapture if
you later add Spanish caption overlays via the `app-store-screenshots`
skill."* Since Phase 4 of this brief burns headline/subhead text into the
final composites, that condition is now true — the final set needs a
Spanish-captioned variant once the English set is approved. Plan:
1. Ship the English final set first (Phase 6/7 of the brief, gated on the
   human style-choice checkpoint below).
2. Re-run only the caption/compositing step (not a full recapture — same
   underlying app screenshots, since none of the shortlisted concepts need
   Spanish app UI specifically to make their point) with Spanish headlines
   translated from the approved English set, informed by the tone already
   established in `Docs/app-store-localization-es.md`'s description copy.
3. Note this in App Store Connect guidance: add the Spanish set under the
   **Spanish (Mexico)** locale only, per that doc's own recommendation.

## Explicitly excluded (not supported — do not invent)

- Any onboarding claim implying sync, collaboration, or accounts.
- Ratings/download counts/awards in captions — none exist in the repo to cite.
- Apple Watch, tvOS, visionOS — no such targets in `project.yml`.
