# CheatSheet — App Store Release QA Report

Date: 2026-08-27
Baseline commit: `6cc7feb` (main, working tree clean at audit start)
Toolchain used: Xcode 27.0 beta (`27A5252f`), XcodeGen 2.45.4 — **CI pins Xcode 26
stable, which is not installed on this machine; see the Environment Limitations
note in every section below before treating a "pass" here as final.**

## Summary

| Area | Result |
| --- | --- |
| macOS unit tests (arm64) | ✅ 55/55 passed |
| macOS unit tests (x86_64) | ✅ 55/55 passed |
| macOS universal Release build | ✅ succeeded, `arm64 x86_64` fat binary confirmed |
| iOS Simulator unit tests | ✅ 55/55 passed |
| iOS Simulator UI smoke tests | ✅ 7/7 passed individually (one toolchain hang mid-suite, isolated retry confirmed clean) |
| iPad Simulator build | ✅ succeeded |
| Project-config verification script | ✅ passed |
| Static crash-risk review | ✅ no force unwraps/casts/`try!`/`fatalError` found |
| Secret scan | ✅ none found |
| Privacy manifest vs. actual API usage | ✅ accurate |
| macOS Archive (Release, local Development signing) | ✅ succeeded, entitlements verified |
| iOS Archive (Release, local Development signing) | ❌ blocked — stale cached provisioning profile (see §1.4) |
| Marketing screenshot review | ⚠️ 1 broken image found (UI-1) |
| Stale doc URLs | ✅ found and fixed (2 URLs in `PRIVACY.md`) |

## 1. Build and installation testing

### 1.1 macOS

Ran the project's own `Scripts/verify-macos.sh`, which (by design, to avoid an
`NSFileCoordinator` hang building from a File-Provider-managed `~/Documents`
checkout) regenerates the Xcode project under `/private/tmp` and runs:

```sh
Scripts/verify-macos.sh
```

- `xcodebuild test -destination 'platform=macOS,arch=arm64'` → **55/55 tests
  passed** in 5 Swift Testing suites (0.136s)
- `xcodebuild test -destination 'platform=macOS,arch=x86_64'` → **55/55 tests
  passed** (0.367s)
- `xcodebuild build -configuration Release 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO`
  → **BUILD SUCCEEDED**; `lipo -info` on the resulting
  `wesleycheatsheet.app/Contents/MacOS/wesleycheatsheet` confirmed
  `Architectures in the fat file: ... x86_64 arm64`

### 1.2 iOS / iPadOS

The README's documented iOS build/test commands operate directly on the
repo-root generated project, which risks the same File-Provider hang the macOS
script works around. This audit mirrored `verify-macos.sh`'s technique (generate
into `/private/tmp`, symlink sources) for iOS as well:

- `xcodegen generate` + `xcodebuild test -scheme CheatSheetiOS -destination
  "id=<resolved iPhone simulator>"` → **55/55 tests passed**
- `xcodebuild test -scheme CheatSheetiOSUI -only-testing:CheatSheetiOSUITests/CheatSheetiOSUITests`
  → **7/7 UI tests passed**: onboarding dismissal, seeded-notes launch, note
  creation, persistence-banner-absent-on-healthy-launch, edit+search flow,
  style+widget-pin flow, trash/restore/permanent-delete flow.
  - **One caveat, investigated to a conclusive result rather than assumed
    away**: mid-run, `testEditAndSearchFlow` hung for 60+ seconds waiting on
    the simulator's "app event loop idle" signal, the automation session's
    internal timestamp went to `nan`, and `xcodebuild` logged "Restarting
    after unexpected exit, crash, or test timeout." This is an XCTest
    automation-bridge infrastructure hang (a broken IPC signal between
    `xcodebuild` and the simulator), **not an assertion failure in the test or
    a crash in the app** — nothing in the log shows an `XCTAssert` failure or
    an app-side crash/exception. After the automatic restart, every remaining
    test in the suite passed cleanly and quickly (10–124s each, 0 failures).
    Because the overall run's exit code still reflected the interrupted test,
    it was re-run **in isolation** as a targeted follow-up:
    `-only-testing:CheatSheetiOSUITests/CheatSheetiOSUITests/testEditAndSearchFlow`
    → **passed cleanly in 31.6s**. So every one of the 7 UI tests has now been
    individually confirmed passing; the interruption was Xcode 27 beta / iOS 27
    beta Simulator automation flakiness, not a CheatSheet defect.
    **Recommendation**: still worth one confirming run on the pinned Xcode 26
    CI toolchain before submission, simply because that's the toolchain that
    matters for the real release — not because this result is in doubt.
- `xcodebuild build -scheme CheatSheetiOS -destination "id=<resolved iPad
  simulator>"` → **BUILD SUCCEEDED** (built directly against the repo's own
  generated project after the background verification script's own iPad step
  got stuck behind a slow post-test simulator diagnostics collection step;
  same result, faster path)

### 1.3 Project configuration verification

```sh
Scripts/verify-project-config.sh
```
→ **passed**: all `Info.plist`/entitlements files are valid plists, Hardened
Runtime is present on both macOS Release targets, the iOS and macOS App Group
identifiers are consistent across `project.yml`, all four entitlements files,
and `Shared/Sources/CheatSheetNote.swift`, and both `PrivacyInfo.xcprivacy`
manifests declare the required `CA92.1`/`1C8F.1` UserDefaults reasons.

### 1.4 Archive (Release, local Apple Development signing)

An "Apple Development: Wesley Keetch" identity for team `HD39MR492X` (matching
`project.yml`'s `DEVELOPMENT_TEAM`) is present in this environment, so a local
Development-signed Release archive could be attempted for both platforms.
**This is not the same as a Distribution-signed archive ready for App Store
Connect upload** — no Distribution certificate/profile was available or used,
and no export/upload was attempted (out of scope for this session).

- **macOS**: `xcodebuild archive -scheme CheatSheetApp -configuration Release
  -destination 'generic/platform=macOS'` → **ARCHIVE SUCCEEDED**. Verified the
  signed binary directly with `codesign -d --entitlements`: the archived app
  carries exactly `com.apple.security.app-sandbox` and
  `com.apple.security.application-groups: [HD39MR492X.com.wesleykeetch.wesleycheatsheet]`
  — matching `project.yml`/`CheatSheet.entitlements` exactly. This is a real,
  correctly-configured Release archive; only the final Development→Distribution
  certificate swap remains, which is the app owner's own Apple Developer
  account action.
- **iOS**: `xcodebuild archive -scheme CheatSheetiOS -configuration Release
  -destination 'generic/platform=iOS'` → **ARCHIVE FAILED**, with a clear,
  specific cause: `Provisioning profile "iOS Team Provisioning Profile: *"
  doesn't include the App Groups capability` / `doesn't support the
  group.com.wesleykeetch.wesleycheatsheet App Group` /
  `doesn't include the com.apple.security.application-groups entitlement`
  (all three errors on the `CheatSheetiOSWidgets` target). This is **not a
  code or `project.yml` defect** — `Scripts/verify-project-config.sh` already
  confirms the entitlements/App Group configuration is correct, and the exact
  same App Group setup archives cleanly on macOS. The cached iOS wildcard
  team-provisioning profile on this machine is stale and was never refreshed
  with the App Groups capability, which normally happens automatically when
  Xcode is signed into the developer's Apple ID with live Developer Portal
  access — not available in this sandboxed environment. **This is an
  environment/credentials limitation, not something I can fix by editing the
  project**: the app owner opening this project in Xcode with their Apple ID
  signed in (or manually regenerating the iOS App ID's provisioning profile in
  the Developer Portal to include App Groups) will resolve it immediately.

### 1.5 Repeated install / launch, no-network launch, interrupted-setup launch

Not independently re-tested beyond what the automated suites already exercise:
the UI suite already does fresh-install-style launches (new simulator
processes) plus force-quit-equivalent teardown/relaunch between test cases, and
the unit suite explicitly covers "app launches after a failed initial load"
(`failedLoadStartsEmptyAndSuspendsPersistence`,
`retryLoadRecoversNotesAndResumesPersistence`). Because the app makes zero
network calls, "no network" and "slow network" launch scenarios are
equivalent to a normal launch — there is nothing in the code path that
branches on connectivity.

## 2. Functional testing

Coverage below is inherited from the existing 55-test Swift Testing suite plus
this session's source review; nothing here needed new tests written (see §6
for why).

- **Note CRUD**: create (default + quick-capture variants), edit (title/body
  independently), archive, restore, permanent delete — all covered directly (
  `NoteStoreTests`).
- **Search**: case-insensitive title/body filter, verified deterministic over
  a 500-note synthetic collection (`filtersLargeNoteCollectionDeterministically`).
- **Pin/widget selection**: pinning clears other pins, archived notes are never
  eligible as the widget note, widget note falls back to first active note if
  none pinned (`WidgetNoteSelectionTests`).
- **Trash policy**: 30-day countdown text at various offsets, immediate
  deletion once expired, expired-note purge on both load and save
  (`CheatSheetNoteTrashTests`, `expiredArchivedNotesAreRemovedOnStartup`).
- **Persistence failure/recovery**: load failure suspends persistence and
  starts empty rather than risking starter-note masking of real data or a
  save that would overwrite recoverable data; retry re-reads and resumes;
  save failure surfaces a status without touching the widget reload path
  (`failedLoadStartsEmptyAndSuspendsPersistence`,
  `failedLoadDoesNotOverwriteStoredNotesOnEdit`,
  `retryLoadRecoversNotesAndResumesPersistence`,
  `saveFailureUpdatesPersistenceStatusWithoutReloadingWidget`).
- **SwiftData ⇄ legacy UserDefaults migration**: one-time migration on first
  SwiftData read, never re-imports stale legacy/starter data after the
  SwiftData store has been intentionally emptied
  (`swiftDataRepositoryMigratesLegacyNotesWhenStoreIsEmpty`,
  `swiftDataRepositoryDoesNotRestoreStaleLegacyNotesAfterDeletingEverything`,
  `initializedEmptySwiftDataStoreIgnoresLegacyFirstRunStarterNotes`).
- **Duplicate/rapid actions**: rapid sequential edits persist only the latest
  snapshot (debounce + generation-counter test:
  `rapidEditsPersistOnlyTheLatestSnapshot`); duplicate note IDs on save are
  deduplicated defensively (`swiftDataRepositoryDeduplicatesSavedNotesByID`).
- **App backgrounding**: `ContentView` flushes pending changes on every
  `scenePhase` transition away from `.active`, exercised by the UI test's
  background/relaunch-equivalent teardown between test cases and directly by
  `flushPendingChangesSavesAndReloadsWidget`.
- **Boundary/invalid input**: malformed stored tint hex normalizes to a safe
  default on both encode and decode (`malformedTintHexNormalizesToDefaultBlue`);
  corrupted stored JSON throws a typed decoding error instead of silently
  discarding data (`invalidStoredDataThrowsInsteadOfMaskingCorruption`).
- **Permissions**: not applicable — the app requests none (no camera, photos,
  location, contacts, microphone, notifications).
- **Deep links / push / auth**: not applicable — none exist in this app.
- **State restoration / rotation**: `ContentView` recomputes its compact
  navigation path on horizontal-size-class change (iPhone rotation / Split
  View resize), verified by source review; iPad build succeeded at the
  resolved iPad simulator's default orientation.

## 3. UI and visual QA

Reviewed every SwiftUI view file in `CheatSheetApp/Sources` and
`CheatSheetWidgets/Sources` for layout, adaptivity, empty/loading/error states,
and platform conventions.

- **Adaptive layout**: `NavigationSplitView` (macOS/iPad) vs. compact
  `NavigationStack` (iPhone) switches correctly on `horizontalSizeClass`;
  toolbar is attached per-navigation-container (a documented fix already in
  the code — a `.toolbar` on the outer `NavigationStack` doesn't install bar
  items on iOS). Sidebar width is constrained 220–320pt; editor requests a
  320pt minimum on macOS. Window minimum size is 640×480, so
  220 (sidebar) + 320 (editor) = 540 < 640 — **no clipping at the smallest
  supported window size**.
- **Empty states**: dedicated views exist for "no note selected," "no notes at
  all" (with a create-note action), and "trash is empty," on both compact and
  split layouts.
- **Loading/error state**: `PersistenceStatusBanner` surfaces load/save
  failures inline with a retry action for load failures; the whole content
  area is `.disabled()` while persistence is suspended, preventing edits that
  would be silently lost.
- **Liquid Glass with fallback**: every glass API call (`.glassEffect`,
  `.buttonStyle(.glass...)`, `GlassEffectContainer`) is gated behind
  `#available(macOS 26.0, *)` / `#available(iOS 26.0, *)` with a
  material/`.bordered` fallback for the minimum supported OS versions
  (macOS 15 / iOS 18) — verified by reading `ViewModifiers.swift` and
  `LiquidGlassGroup.swift` directly, not just trusting the deployment target.
- **Dark/light mode**: `AppTheme`/`AppBackdrop` branch explicitly on
  `colorScheme` for both the window backdrop gradient and the glass
  fallback fill; widget background gradients likewise branch on
  `colorScheme` and additionally respect `widgetRenderingMode` (accented /
  vibrant Home Screen and StandBy modes render white-on-clear instead of
  full color).
- **Marketing screenshots** (`Docs/Images/`, referenced from `README.md`):
  - **UI-1 (found, not auto-fixed)**: `cheatsheet-desktop-overview.png` does
    not show the app. Instead of the sidebar + note editor the code actually
    renders, it shows an unrelated rounded card with a laptop icon inside a
    circular ring and "83%" — this looks like a stray system widget or
    screen-capture compositing artifact, and the note panel is a
    content-free "New Cheat Sheet" placeholder rather than real sample
    content like every other screenshot in the set. This is the *first*
    image in the README's platform table. **Not auto-fixed**: this is a
    marketing asset, not app code, and needs a real capture (the
    `app-store-screenshots` skill is the right tool for this) rather than a
    guess. The other four images
    (`cheatsheet-iphone.png`, `cheatsheet-ipad.png`,
    `cheatsheet-iphone-widget.png`, `cheatsheet-widget-gallery.png`) were
    visually reviewed and are accurate, on-brand, and — for the iPhone and
    iPad shots specifically — already sized to Apple's current App Store
    screenshot pixel dimensions (1320×2868 and 2064×2752 respectively).
- **Touch targets**: a shared `AppDesign.minimumHitSize = 44` constant is
  applied to the iOS palette swatch buttons; other interactive controls use
  standard system controls/buttons which already meet the 44pt guideline.

## 4. Accessibility QA (source-level review)

- Interactive elements consistently carry `accessibilityLabel` and/or
  `accessibilityIdentifier` (11 files, 25 call sites reviewed); decorative
  icons are marked `accessibilityHidden(true)`.
- Checklist/task rows expose state through text, not just an icon:
  `"Complete, <text>"` / `"Incomplete, <text>"` accessibility labels
  (`ChecklistLineView`, `WidgetLineView`), so VoiceOver users get task status
  without relying on the checkmark glyph or color.
- Color is never the only signal: the palette picker reads
  `@Environment(\.accessibilityDifferentiateWithoutColor)` and swaps its
  selection indicator to a filled checkmark badge when that setting is on,
  in addition to always showing a border-weight change
  (`GlassPaletteSwatchButton`).
- Dynamic Type: text uses semantic styles (`.title`, `.callout`, `.caption`,
  etc.) throughout; the only fixed-point font size found
  (`.font(.system(size: 36, weight: .semibold))` in `ContentView.swift`'s
  Trash-empty-state icon) is a decorative SF Symbol, not user content, so a
  fixed size there is correct rather than a Dynamic Type miss.
- No VoiceOver/Large-Content-Viewer/hardware-switch-control pass was possible
  in this environment (Simulator does not exercise real assistive hardware);
  documented as an environment limitation, not skipped silently.

## 5. Reliability, resilience, and static crash-risk review

Grepped all of `CheatSheetApp/Sources`, `CheatSheetWidgets/Sources`, and
`Shared/Sources` for the classic Swift crash/footgun patterns:

| Pattern | Result |
| --- | --- |
| Force unwrap (`!`), excluding `!=` | none found |
| `try!` | none found |
| `as!` | none found |
| `fatalError` / `preconditionFailure` / `assertionFailure` | none found |
| Stray `print()` (vs. structured `OSLog`) | none found |
| `TODO` / `FIXME` / `HACK` | none found |
| `DispatchQueue` (vs. structured concurrency) | none found — Task/actor only |

Concurrency review: `NoteStore` is `@MainActor @Observable`; its one detached
work item (the debounced save `Task`) correctly captures `[weak self,
persistenceWorker]` and checks the save "generation" counter before applying
results, so a cancelled or superseded save can't clobber newer in-memory state
or crash on a deallocated store. The four lightweight repository wrapper types
around `UserDefaults`/`ModelContainer` are `@unchecked Sendable`, which is the
standard, low-risk pattern for wrapping already-thread-safe Foundation/SwiftData
types — no unsynchronized mutable state was found inside them.

No Instruments session (Leaks, Time Profiler) was run — see Environment
Limitations in the checklist. Static review found no obvious retain-cycle
shapes (no `self` capture without `weak`/`unowned` inside closures stored on
`self`).

## 6. Performance (static review — no Instruments session available)

- Note lists render through SwiftUI's native `List`, not a manually-built
  `VStack` (`SidebarView`, `CompactNoteListView`) — cell reuse is automatic.
- Widget timeline refresh policy is `.after(.now.addingTimeInterval(60 * 30))`
  — a 30-minute cadence, not refresh-on-every-app-launch or a tight poll loop;
  reasonable for battery.
- Saves are debounced 400ms and coalesced (only the latest snapshot survives a
  burst of edits) — verified both by reading `NoteStore.schedulePersist` and by
  the `rapidEditsPersistOnlyTheLatestSnapshot` test.
- The 500-synthetic-note test demonstrates the filtering path stays correct at
  a dataset size far beyond what this app's real usage pattern (a personal
  cheat-sheet list) would realistically reach; no explicit Big-O concern was
  found in `filteredNotes`/`activeNotes` (linear scans over an in-memory
  array, appropriate at this scale).
- No large synchronous file/database work was found on a path that runs on
  the main actor outside of what SwiftData/UserDefaults already do
  internally; `NoteStore`'s own I/O goes through the `NotePersistenceWorker`
  actor.

## 7. Security and privacy review

- **No secrets in source**: grepped for API key/secret/password/token/bearer
  patterns across all Swift sources — zero hits. No `.env`, credentials, or
  certificate files in the repo.
- **No network stack**: zero occurrences of `http://`/`https://` in any Swift
  source file, consistent with `PRIVACY.md`'s "no network service" claim.
- **Local storage**: SwiftData (App Group container) is the source of truth;
  a legacy UserDefaults path exists only for one-time migration. Nothing
  sensitive (credentials, tokens, PII beyond the user's own note text) is
  stored — and note text itself never leaves the device.
- **Privacy manifests** (`CheatSheetApp/Resources/PrivacyInfo.xcprivacy`,
  `CheatSheetWidgets/Resources/PrivacyInfo.xcprivacy`): both declare exactly
  the `NSPrivacyAccessedAPICategoryUserDefaults` API, with both required
  reason codes (`CA92.1` for app-local access, `1C8F.1` for the
  App-Group-shared access the widget needs) and an empty
  `NSPrivacyCollectedDataTypes`/`NSPrivacyTracking: false`. This matches the
  actual code (`UserDefaults(suiteName:)` for the App Group,
  `@AppStorage`/`UserDefaults.standard` for local preferences) exactly — no
  over- or under-declaration found.
- **Entitlements**: macOS app and widget are sandboxed
  (`com.apple.security.app-sandbox: true`) with exactly one shared capability
  (the App Group) and Hardened Runtime enabled on Release. iOS entitlements
  request only the App Group (iOS apps are sandboxed by the platform). No
  entitlement requests anything beyond what the app actually uses.
- **Fixed this session**: `PRIVACY.md`'s Support and Source URLs pointed at
  `github.com/keetchcode/cheatsheet` — a GitHub username that has since been
  renamed to `weskcode` (confirmed via `gh auth status` and an HTTP redirect
  check: the old URL 301-redirects to the new one). The links still worked
  through GitHub's redirect, but a public-facing privacy policy shouldn't
  depend on that; both URLs now point directly at
  `github.com/weskcode/cheatsheet`.
- **Export compliance**: `ITSAppUsesNonExemptEncryption` is `false` in both
  platform `Info.plist` files, matching an app that uses no proprietary/custom
  cryptography beyond what the OS provides for data-at-rest.

## 8. Localization and internationalization

No localization exists (`*.lproj` search returned nothing) — the app is
English-only. This matches the project's stated "deliberately narrow" scope
and is not treated as a defect, but is called out explicitly (checklist)
since it's a product decision, not something to silently accept or silently
"fix" by adding translations nobody asked for.

## 9. Store and release compliance review

- App icon set is complete for macOS (16–1024pt @1x/2x) and iOS/iPad
  (20–167pt plus the 1024 marketing icon); the 1024 marketing icon is
  1024×1024 with **no alpha channel** (verified with `sips`), matching
  Apple's App Store icon requirement.
- `LSApplicationCategoryType` = Productivity on both platforms; consistent
  copyright string; `CFBundleDisplayName` = "CheatSheet" on both.
- No placeholder/debug content, no debug menus, no test data paths reachable
  from Release builds — `CheatSheetLaunchEnvironment`'s test-only code paths
  (in-memory store, onboarding overrides) are gated behind a launch argument
  (`-cheatsheet-ui-testing`) that a normal user/App-Review launch will never
  pass.
- No App Review "how do I test this" complexity to document — there's no
  login, no server dependency, no account, and no purchase flow; App Review
  can install and use the entire app with zero setup.
- App Group identifiers are consistent everywhere they're declared (checked
  independently of `verify-project-config.sh`, by direct diff of all four
  entitlements files, `project.yml`, and `CheatSheetNote.swift`).
- Version/build: was 1.1 (12) at audit start; bumped to **1.1 (13)** for this
  release candidate (see the checklist for why marketing version wasn't
  changed).

## 10. Regression testing after fixes

Two changes were made this session:

1. `PRIVACY.md` — two URL fixes (documentation only, zero code/behavior
   change; no rebuild needed to "verify" this beyond the plain-text diff
   above).
2. `project.yml` — `CURRENT_PROJECT_VERSION` 12 → 13 (build-number-only
   change). Re-verified by re-running `Scripts/verify-project-config.sh`
   after the bump — still passes — and by regenerating the Xcode project with
   `xcodegen generate` to confirm it picks up the new value cleanly.

No application code was changed this session (none of the findings rose to
"confirmed, safely fixable code defect" — see the checklist for the one item
that's a recommendation rather than a change: adding a Release build step to
CI).
