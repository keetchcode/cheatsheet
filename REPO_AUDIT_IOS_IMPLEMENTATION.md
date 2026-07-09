# REPO_AUDIT_IOS Implementation

Date: 2026-07-09

## Work Summary

- **PR Batch 1: Persistence correctness and migration safety**
  - Fixed audit 13.1 by adding a SwiftData initialization marker so a deliberately empty initialized store stays empty instead of resurrecting starter notes.
  - Fixed audit 13.2 by making repository load/save operations throwing, surfacing `PersistenceStatus` in `NoteStore`, and adding privacy-safe `OSLog` errors.
  - Addressed audit 13.14 by publishing the widget snapshot only after the durable app save succeeds.

- **PR Batch 2: Concurrency and widget state**
  - Replaced the custom GCD save queue with an actor-backed persistence worker for `NoteStore` saves, preserving main-actor UI state.
  - Added runtime widget no-note state so WidgetKit placeholder content is no longer used as real app data.
  - Added tint validation and repair on note initialization, decoding, encoding, and display fallback.

- **PR Batch 3: Release and configuration hardening**
  - Removed archive pre-actions that mutated `project.yml`.
  - Added Release-only Hardened Runtime settings for macOS app and widget targets.
  - Centralized platform App Group IDs in shared code and added a project configuration verification script to detect drift.

- **PR Batch 4: Test and CI gates**
  - Added an iOS UI smoke-test target and dedicated `CheatSheetiOSUI` scheme.
  - Added a GitHub Actions workflow that regenerates the project, runs config verification, and runs iOS unit tests.
  - Added focused tests for empty SwiftData semantics, save failures, nil widget snapshots, corrupt colors, and 500-note filtering.

- **PR Batch 5: Docs and roadmap boundaries**
  - Updated release docs for explicit build-number bumping, English-only product stance, UI smoke coverage, and Hardened Runtime.
  - Deferred App Intents and signed archive/export work to follow-up PRs because audit 13.10 is a roadmap opportunity and audit 13.15 requires release signing credentials/artifacts.

## What I Did First and Why

I started with audit 13.1, 13.2, 13.3, and 13.14 because they are the data durability path: load, migration, save, and widget snapshot publication. These items can directly change user data behavior, so they needed to be fixed before release/config cleanup or broader workflow automation.

## Changes by File

### Shared persistence and model

- `Shared/Sources/CheatSheetNoteRepository.swift`
  - Audit 13.2: changed `CheatSheetNoteRepository` to `Sendable` with throwing load/save methods.
  - Audit 13.2: added typed `CheatSheetStorageError` cases with user-safe localized descriptions.
  - Audit 13.1: added `CheatSheetStoreMetadataRepository` for the SwiftData initialized-store marker.
  - Audit 13.14: made `WidgetNoteSnapshotRepository.saveNote` throwing so snapshot failures are visible.
  - Audit 13.7: marked storage helper wrappers as sendable boundaries around system storage types.

- `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift`
  - Audit 13.1: only seeds starter notes before the SwiftData store has ever been initialized.
  - Audit 13.2: propagates SwiftData fetch/save and widget snapshot errors instead of swallowing them.
  - Audit 13.14: writes widget snapshot only after `context.save()` succeeds.
  - Audit 13.7: uses the metadata repository from the App Group defaults.

- `Shared/Sources/CheatSheetNote.swift`
  - Audit 13.7: introduced `CheatSheetAppGroupID` namespace and kept `cheatSheetAppGroupID` as the platform-facing compatibility constant.
  - Audit 13.12: validates and normalizes `tintHex`; invalid values fall back to palette blue during init, decode, encode, and `Color(hex:)`.

### App state and lifecycle

- `CheatSheetApp/Sources/NoteStore.swift`
  - Audit 13.2: tracks `PersistenceStatus` and logs load/save failures with privacy-safe messages.
  - Audit 13.3: replaces the custom `DispatchQueue` worker with an actor-backed save worker.
  - Audit 13.14: reloads widget timelines only after successful durable save and snapshot publication.
  - Audit 13.13: supports large-note fixture coverage without changing app behavior.

- `CheatSheetApp/Sources/ContentView.swift`
  - Audit 13.3: scene-phase flush now awaits the async persistence path instead of synchronously blocking.

### Widget

- `CheatSheetWidgets/Sources/CheatSheetEntry.swift`
  - Audit 13.11: permits a runtime entry with no note.

- `CheatSheetWidgets/Sources/CheatSheetProvider.swift`
  - Audit 13.11: keeps starter note for placeholders only; snapshot/timeline now reflect actual nil snapshot state.
  - Audit 13.2: logs widget snapshot load errors without exposing note content.

- `CheatSheetWidgets/Sources/CheatSheetWidgetView.swift`
  - Audit 13.11: renders an explicit "No Widget Note" empty state when no runtime note exists.

### Tests and automation

- `CheatSheetTests/Sources/NoteRepositoryTests.swift`
  - Audit 13.1: added initialized-empty SwiftData regression coverage.
  - Audit 13.11: added nil widget snapshot coverage.
  - Audit 13.12: added malformed color normalization coverage.
  - Audit 13.14: updated tests for throwing repository/snapshot APIs.

- `CheatSheetTests/Sources/NoteStoreTests.swift`
  - Audit 13.2: added save-failure persistence status coverage.
  - Audit 13.3: updated flush tests for async persistence.
  - Audit 13.13: added deterministic 500-note filtering/sorting fixture.

- `CheatSheetUITests/Sources/CheatSheetiOSUITests.swift`
  - Audit 13.4: added first iOS UI automation smoke test for onboarding/main-surface launch.

- `.github/workflows/ci.yml`
  - Audit 13.5: added CI gate for checkout, Xcode selection, XcodeGen, project config verification, and iOS unit tests.

- `Scripts/verify-project-config.sh`
  - Audit 13.5, 13.6, 13.7, 13.8: lints plist/entitlement files, rejects archive pre-actions, verifies Hardened Runtime settings, and checks App Group drift.

### Release docs and project config

- `project.yml`
  - Audit 13.4: added `CheatSheetiOSUITests` target and `CheatSheetiOSUI` scheme.
  - Audit 13.6: removed archive pre-actions from release schemes.
  - Audit 13.8: added Release-only `ENABLE_HARDENED_RUNTIME: YES` for macOS app and widget targets.

- `Docs/AppStoreReadiness.md`
  - Audit 13.6: updated versioning docs to use explicit build-number bumping before archive.
  - Audit 13.8: updated Hardened Runtime wording from "add" to "keep".
  - Audit 13.9: documented current English-only stance.
  - Audit 13.4: documented the new UI smoke scheme and remaining UI automation expansion.

## Priority Item Coverage

| Audit item | Status | Notes |
| --- | --- | --- |
| 13.1 Empty SwiftData store resurrects starter notes | Implemented | Added initialized marker and regression test for saved empty store. |
| 13.2 Persistence errors hidden from UI/logs | Implemented | Throwing repository API, `PersistenceStatus`, and privacy-safe logs added. |
| 13.3 Persistence should move from custom queue to SwiftData actor isolation | Partial | Removed GCD worker and isolated saves behind an actor. Full `ModelActor` ownership of `ModelContext` remains a next-step refactor. |
| 13.4 No UI automation | Partial | Added iOS UI test target/scheme and launch smoke test. Full create/edit/search/pin/trash/onboarding UI flows remain. |
| 13.5 No CI/static gates | Implemented | Added GitHub Actions workflow and local config verification script. |
| 13.6 Archive pre-action mutates `project.yml` | Implemented | Removed archive pre-actions; build bump is now explicit via script. |
| 13.7 App Group IDs duplicated | Partial | Centralized source constants and added drift verification. Full code generation from `project.yml` remains future hardening. |
| 13.8 Missing explicit Hardened Runtime | Implemented | Added Release settings and verified via generated project/config gate plus Release build. Signed artifact inspection remains release-gated. |
| 13.9 No localization infrastructure | Implemented by decision | Documented English-only support per audit option. No string catalogs added because localization is not currently a product goal. |
| 13.10 No App Intents/system integration | Deferred | Audit frames this as a missed opportunity, not a bug. Left for roadmap PR after persistence actor API is fully async. |
| 13.11 Widget fallback shows starter note | Implemented | Runtime snapshot/timeline can now represent no note and render empty state. |
| 13.12 Corrupted colors render black | Implemented | Invalid tint values normalize to palette blue. |
| 13.13 No performance fixture | Implemented | Added 500-note filter/sort test. |
| 13.14 Storage/widget snapshot coupling | Implemented | Snapshot publication now follows durable app save success and throws on failure. |
| 13.15 No signed archive/export evidence | Blocked by environment | Requires release signing/provisioning and export/archive inspection on release Mac. |

## Test/Build Evidence

- `Scripts/verify-project-config.sh`
  - Result: passed, output `Project configuration verified.`

- `xcodebuild -list -project CheatSheet.xcodeproj`
  - Result: passed; generated project exposes `CheatSheetiOSUITests` target and `CheatSheetiOSUI` scheme.

- `xcodebuild test -project CheatSheet.xcodeproj -scheme CheatSheetiOS -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -derivedDataPath /tmp/CheatSheet-iOS-Implementation-DD CODE_SIGNING_ALLOWED=NO`
  - Result: passed.
  - Evidence: 45 tests in 5 suites passed; `** TEST SUCCEEDED **`.

- `xcodebuild test -project CheatSheet.xcodeproj -scheme CheatSheetiOSUI -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -derivedDataPath /tmp/CheatSheet-iOS-UI-DD CODE_SIGNING_ALLOWED=NO`
  - Result: passed.
  - Evidence: 1 UI test passed; `** TEST SUCCEEDED **`.

- `Scripts/verify-macos.sh`
  - Result: passed.
  - Evidence: arm64 macOS tests passed with 45 tests; x86_64 macOS tests passed with 45 tests; universal Release build succeeded with `x86_64 arm64`; final output `Verification succeeded`.

## Remaining Risks

- Full SwiftData `ModelActor` ownership is not complete. The GCD queue is gone and save work is actor-isolated, but the repository still creates `ModelContext` internally rather than being a dedicated `ModelActor`.
- UI automation is only a launch smoke test. The critical create/edit/search/pin/trash/restore/onboarding flows still need deterministic isolated-store launch support.
- App Group IDs are guarded by a drift script, but not generated from `project.yml` yet.
- App Intents, Spotlight, and deep-link surfaces remain roadmap work.
- Signed archive/export, embedded extension entitlement inspection, App Store Connect processing, and provisioning checks were not run in this local sprint.

## Next PR Suggestions

1. Convert SwiftData persistence to a dedicated `ModelActor` service with async repository methods.
2. Add UI-test launch arguments for an isolated temporary store, then automate create/edit/search/pin/trash/restore/onboarding.
3. Generate App Group source constants from `project.yml`, or inject them from build settings/Info.plist.
4. Add App Intents for create note, open pinned note, search notes, and pin note once persistence has a clean async service facade.
5. Run signed archive/export validation on the release Mac and attach entitlement/version/privacy-manifest evidence to the release checklist.
