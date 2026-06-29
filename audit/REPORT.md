# CheatSheet Audit Report

Date: 2026-06-29
Scope: `CheatSheetApp`, `Shared`, `CheatSheetWidgets`, `project.yml`, app plist/entitlement configuration.

Compiler ground truth: macOS and iOS Debug build warning sweeps completed with no Swift compiler warnings surfaced by `rg "warning:"`.

## Findings

### High

#### 1. Missing privacy manifest for required-reason UserDefaults APIs
- **Lane:** Privacy/Security
- **Location:** `Shared/Sources/CheatSheetNoteRepository.swift:13`, `CheatSheetApp/Sources/ContentView.swift:9`, `project.yml:108`
- **Finding:** The iOS target includes app sources that use `UserDefaults` and `@AppStorage`, but no `PrivacyInfo.xcprivacy` is present in app resources.
- **One-line fix:** Add privacy manifests to shipped targets and declare `NSPrivacyAccessedAPICategoryUserDefaults` with the appropriate app-functionality reason.

#### 2. Main-actor persistence can block editing and navigation
- **Lane:** Concurrency, Architecture, Performance
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:202`
- **Finding:** `NoteStore` is `@MainActor`, and `persist()` performs repository saves synchronously through SwiftData/UserDefaults while the UI actor is responsible for typing, navigation, menu bar actions, and scene changes.
- **One-line fix:** Move repository load/save work behind an async persistence actor or background context and publish only state changes back on `MainActor`.

#### 3. iOS color swatches are below minimum hit target size
- **Lane:** Accessibility
- **Location:** `CheatSheetApp/Sources/GlassPaletteSwatchButton.swift:23`
- **Finding:** Palette buttons use a fixed `26x26` frame, below the 44pt touch target expected on iPhone and iPad.
- **One-line fix:** Keep the 16pt visual swatch but give the `Button` a platform-gated minimum hit frame of at least `44x44` on iOS/iPadOS.

### Medium

#### 4. Note bodies are mirrored into legacy UserDefaults after every SwiftData save
- **Lane:** Privacy/Security, Architecture
- **Location:** `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:76`, `Shared/Sources/CheatSheetNoteRepository.swift:35`, `Shared/Sources/CheatSheetNote.swift:12`
- **Finding:** Full user-authored note titles and bodies are saved to SwiftData and then mirrored to app-group `UserDefaults` on each successful save.
- **One-line fix:** After migration, stop mirroring the full note corpus to `UserDefaults` or persist only the minimal widget snapshot needed by WidgetKit.

#### 5. App-group UserDefaults silently falls back to standard defaults
- **Lane:** Privacy/Security, Architecture
- **Location:** `Shared/Sources/CheatSheetNoteRepository.swift:13`, `Shared/Sources/CheatSheetStorage.swift:5`
- **Finding:** If the app group suite is unavailable, storage falls back to `.standard`, hiding entitlement/configuration failures and writing note data to a different container.
- **One-line fix:** Fail closed or surface a storage error when the app-group suite cannot be opened.

#### 6. Widget provider bypasses the live repository boundary
- **Lane:** Architecture, Performance
- **Location:** `CheatSheetWidgets/Sources/CheatSheetProvider.swift:23`
- **Finding:** Widget timeline loading hard-codes `UserDefaultsCheatSheetNoteRepository`, so the widget depends on SwiftData-to-UserDefaults mirroring rather than an injected snapshot/repository boundary.
- **One-line fix:** Inject a widget repository or dedicated widget snapshot provider into `CheatSheetProvider`.

#### 7. Search and list access repeatedly rebuild sorted note collections
- **Lane:** Performance
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:61`
- **Finding:** `filteredNotes` and `filteredArchivedNotes` call `activeNotes`/`archivedNotes`, which filter and sort on every view update and search change.
- **One-line fix:** Cache sorted active/archive collections when `notes` changes, then filter those stable arrays for search.

#### 8. Trash sidebar computes the filtered archive list twice per body pass
- **Lane:** Performance
- **Location:** `CheatSheetApp/Sources/SidebarView.swift:12`
- **Finding:** The trash view checks `store.filteredArchivedNotes.isEmpty` and then iterates `store.filteredArchivedNotes`, repeating filtering/sorting work.
- **One-line fix:** Derive the filtered archive list once for the body pass and reuse it for empty state and rows.

#### 9. Full note parsing happens before callers apply prefixes
- **Lane:** Performance
- **Location:** `Shared/Sources/DisplayLine.swift:12`
- **Finding:** `displayLines` parses every non-empty line, even when widgets and previews immediately use only a small prefix.
- **One-line fix:** Add a bounded parser such as `displayLines(limit:)` for widgets, previews, and compact summaries.

#### 10. Preview-line parsing maps the full body before taking the first result
- **Lane:** Performance
- **Location:** `Shared/Sources/DisplayLine.swift:31`
- **Finding:** `notePreviewLine` eagerly maps all lines through `String.init` and `parsedChecklistLine` before selecting the first non-empty preview.
- **One-line fix:** Use a lazy sequence or early-exit loop that stops after the first usable preview line.

#### 11. Widget completed text may be low contrast in non-full-color rendering
- **Lane:** Accessibility
- **Location:** `CheatSheetWidgets/Sources/WidgetLineView.swift:35`
- **Finding:** Completed widget lines render as `.white.opacity(0.72)` outside full-color mode, which can underperform on tinted/accessory widget backgrounds.
- **One-line fix:** Use semantic widget foreground styles or a higher-contrast completed-state treatment.

### Low

#### 12. Header icon is exposed before the menu bar title
- **Lane:** Accessibility
- **Location:** `CheatSheetApp/Sources/MenuBarQuickAccessView.swift:83`
- **Finding:** The decorative `note.text` icon in the menu bar popover header is not hidden from VoiceOver.
- **One-line fix:** Add `.accessibilityHidden(true)` to the decorative header image.

#### 13. AppKit window activation is embedded in SwiftUI view composition
- **Lane:** Architecture
- **Location:** `CheatSheetApp/Sources/MenuBarQuickAccessView.swift:168`
- **Finding:** `MenuBarQuickAccessView` directly calls `NSApp.activate(ignoringOtherApps:)`, coupling reusable view code to AppKit process activation.
- **One-line fix:** Inject an `openMainWindow` action from the macOS app shell.

#### 14. Root content view is carrying too many responsibilities
- **Lane:** Architecture
- **Location:** `CheatSheetApp/Sources/ContentView.swift:4`
- **Finding:** `ContentView` owns root navigation, toolbar commands, onboarding, trash routing, compact iOS routing, widget hints, and note creation.
- **One-line fix:** Extract root navigation/actions and detail rendering into focused platform/root/detail components.

#### 15. Static storage facade appears unused and bypasses DI
- **Lane:** Dead Code, Architecture
- **Location:** `Shared/Sources/CheatSheetStorage.swift:3`
- **Finding:** `CheatSheetStorage` is not referenced by production or test code and constructs a live repository per static call.
- **One-line fix:** Delete the facade or route callers through injected repository ownership consistently.

#### 16. Unused sidebar theme helper
- **Lane:** Dead Code
- **Location:** `CheatSheetApp/Sources/AppTheme.swift:30`
- **Finding:** `sidebarBackground(for:)` has no current references.
- **One-line fix:** Remove the method or wire it into `SidebarView`.

#### 17. Release readiness guidance is stale for the new iOS target
- **Lane:** Privacy/Security, Dead Code/Docs
- **Location:** `Docs/AppStoreReadiness.md:62`
- **Finding:** The doc says to add a privacy manifest only if validation asks for one, but the iOS target now uses required-reason `UserDefaults` APIs.
- **One-line fix:** Update release guidance after adding the privacy manifest.

#### 18. iOS target references files that are still untracked locally
- **Lane:** Dead Code, Architecture
- **Location:** `project.yml:98`, `project.yml:114`
- **Finding:** `CheatSheetiOS` depends on `CheatSheetApp/iOSInfo.plist` and `CheatSheetApp/CheatSheet-iOS.entitlements`, which are currently untracked in `git status`.
- **One-line fix:** Stage/commit those target files with the iOS work or remove the target wiring before sharing the branch.

## Lane Summary

- **Concurrency:** No compiler concurrency warnings were found; the main issue is synchronous persistence crossing the `@MainActor` store boundary.
- **Architecture:** The persistence boundary and widget snapshot path need tightening; `ContentView` and the menu bar view also carry platform/process responsibilities that should move outward.
- **Performance:** No evidence of catastrophic hot paths, but list/search parsing and main-actor persistence will scale poorly with larger note counts.
- **Accessibility:** Most controls have labels, but iOS palette hit targets and one widget contrast path need attention.
- **Privacy/Security:** No secrets, network calls, ATS exceptions, or obvious PII logs were found; privacy-manifest coverage and storage fallback behavior are the major issues.
- **Dead code:** Two low-risk cleanup candidates were found: `CheatSheetStorage` and `AppTheme.sidebarBackground(for:)`.

## Top 5 To Fix Now

1. **Missing privacy manifest** — Blast radius: app and widget resource configuration; affects App Store validation and privacy compliance for the iOS/iPadOS target.
2. **Main-actor persistence** — Blast radius: `NoteStore`, repository protocol, SwiftData repository, tests; affects typing latency, scene transitions, and save reliability under larger note sets.
3. **26pt palette hit targets** — Blast radius: `GlassPaletteSwatchButton` and editor header layout; improves iPhone/iPad accessibility without changing persistence.
4. **Full note corpus mirrored to UserDefaults** — Blast radius: SwiftData repository, widget provider, migration tests; reduces duplicated private note storage and clarifies the widget data path.
5. **App-group fallback to `.standard`** — Blast radius: repository initialization and tests; prevents silent data-container drift when entitlements are misconfigured.

## Verification Notes

- Build warning sweep: `xcodebuild build -project CheatSheet.xcodeproj -scheme CheatSheet -destination 'platform=macOS' -derivedDataPath /tmp/CheatSheetAuditMacDerivedData 2>&1 | rg "warning:" || true`
- Build warning sweep: `xcodebuild build -project CheatSheet.xcodeproj -scheme CheatSheetiOS -destination 'platform=iOS Simulator,id=3F825BB9-A313-4307-9C6D-85FE69C2D90B' -derivedDataPath /tmp/CheatSheetAuditiOSDerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | rg "warning:" || true`
- Privacy manifest check: `find . -name 'PrivacyInfo.xcprivacy' -o -name '*.xcprivacy'`
- Secret/ATS sweep: searched Swift, YAML, plist, and entitlement files for API keys, private keys, tokens, `http://`, ATS exceptions, and sensitive logging.

## Implemented

1. **High - Missing privacy manifest for required-reason UserDefaults APIs** — status: fixed; commit: `6ca73c5`.
2. **High - Main-actor persistence can block editing and navigation** — status: fixed; commit: `6ca73c5`.
3. **High - iOS color swatches are below minimum hit target size** — status: fixed; commit: `6ca73c5`.
4. **Medium - Note bodies are mirrored into legacy UserDefaults after every SwiftData save** — status: fixed; commit: `6ca73c5`.
5. **Medium - App-group UserDefaults silently falls back to standard defaults** — status: fixed; commit: `6ca73c5`.
6. **Medium - Widget provider bypasses the live repository boundary** — status: fixed; commit: `6ca73c5`.
7. **Medium - Search and list access repeatedly rebuild sorted note collections** — status: fixed; commit: `6ca73c5`.
8. **Medium - Trash sidebar computes the filtered archive list twice per body pass** — status: fixed; commit: `6ca73c5`.
9. **Medium - Full note parsing happens before callers apply prefixes** — status: fixed; commit: `6ca73c5`.
10. **Medium - Preview-line parsing maps the full body before taking the first result** — status: fixed; commit: `6ca73c5`.
11. **Medium - Widget completed text may be low contrast in non-full-color rendering** — status: fixed; commit: `6ca73c5`.
12. **Low - Header icon is exposed before the menu bar title** — status: fixed; commit: `6ca73c5`.
13. **Low - AppKit window activation is embedded in SwiftUI view composition** — status: fixed; commit: `6ca73c5`.
14. **Low - Root content view is carrying too many responsibilities** — status: fixed; commit: `6ca73c5`.
15. **Low - Static storage facade appears unused and bypasses DI** — status: fixed; commit: `6ca73c5`.
16. **Low - Unused sidebar theme helper** — status: fixed; commit: `6ca73c5`.
17. **Low - Release readiness guidance is stale for the new iOS target** — status: fixed; commit: `6ca73c5`.
18. **Low - iOS target references files that are still untracked locally** — status: fixed; commit: `6ca73c5`.
