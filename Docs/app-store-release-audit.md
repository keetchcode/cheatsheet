# CheatSheet — App Store Release Audit

Date: 2026-08-27
Auditor: Claude Code (automated release-readiness pass)
Scope: `main` @ `6cc7feb` at the start of this audit

## 0. Framing

The task that triggered this audit was written as if CheatSheet had never shipped
("first production release, version 1.0"). That does not match the repository:
`project.yml` already carries `MARKETING_VERSION: "1.1"` / `CURRENT_PROJECT_VERSION: "12"`,
and git history includes `Prepare iOS TestFlight release`, `Prepare App Store identity`,
`Fix CheatSheet audit findings`, and `Finalize build 12 release candidate`. This is a
mature, previously-hardened app, not a green-field v1.0.

**Per explicit user confirmation**, this audit treats the work as **readiness for the
next App Store submission of an existing app**, using the current version/build as the
baseline. No version numbers were reset. The build number is bumped as a normal part of
cutting a new release candidate (see §8).

## 1. What CheatSheet is

CheatSheet is a small, local-first, open-source note-taking utility for macOS, iOS, and
iPadOS, plus a companion WidgetKit extension. It has no backend, no accounts, no
analytics, and no third-party dependencies. Product principles are documented in
`README.md`: "deliberately narrow," local-first, one pinned note for the widget, no
sync/collaboration/account system without a separate product decision.

- **Bundle IDs**: `com.wesleykeetch.wesleycheatsheet` (app, both platforms),
  `com.wesleykeetch.wesleycheatsheet.widgets` (widget extension, both platforms)
- **Team**: `HD39MR492X`
- **Deployment targets**: macOS 15.0, iOS/iPadOS 18.0 (`project.yml`)
- **Swift**: 6.0, strict concurrency
- **Marketing version / build**: 1.1 / 12 at audit start
- **App Groups**: `HD39MR492X.com.wesleykeetch.wesleycheatsheet` (macOS),
  `group.com.wesleykeetch.wesleycheatsheet` (iOS) — shared between app and widget
- **Category**: Productivity (`public.app-category.productivity`)
- **Dependencies**: none (no SPM packages, no CocoaPods, no Carthage)
- **Source of truth for the Xcode project**: `project.yml` (XcodeGen). The generated
  `CheatSheet.xcodeproj` is git-ignored.

## 2. Architecture

SwiftUI throughout, using `@Observable`/`@MainActor` (Swift 6, not the legacy
`ObservableObject` pattern) for the single view-model, `NoteStore`
([NoteStore.swift](../CheatSheetApp/Sources/NoteStore.swift)). Layout:

```text
CheatSheetApp/       Shared SwiftUI app sources for macOS, iOS, and iPadOS
CheatSheetWidgets/   WidgetKit extension sources for macOS and iOS/iPadOS
Shared/              Model, parsing, and persistence code (shared by app + widget)
CheatSheetTests/     Swift Testing coverage (macOS + iOS unit test targets)
CheatSheetUITests/   XCTest UI smoke tests (iOS)
```

**Persistence** ([SwiftDataCheatSheetNoteRepository.swift](../Shared/Sources/SwiftDataCheatSheetNoteRepository.swift)):
SwiftData is the primary store, in an App Group container so the widget can read the
pinned note directly. A `UserDefaults`-backed legacy repository and a
`hasInitializedSwiftDataStore` flag handle one-time migration from an older
UserDefaults-based format without ever resurrecting stale data after a user
intentionally empties their notes. Saves are id-based upsert/delete against SwiftData
(not "wipe and reinsert"), and de-duplicate by note ID defensively.

**NoteStore** debounces saves (400ms) so rapid edits coalesce into one write, tracks a
save "generation" counter so a stale in-flight save can't clobber a newer one, and
**suspends persistence entirely** if the initial load fails — this is a deliberate
data-loss guard: writing an empty/partial snapshot over a store the app failed to read
would be silent, permanent data loss, so the app instead shows a
[PersistenceStatusBanner.swift](../CheatSheetApp/Sources/PersistenceStatusBanner.swift)
with a retry action and disables editing until a reload succeeds.

**Widget**: a `TimelineProvider` re-reads a small App-Group-shared "widget note
snapshot" and refreshes every 30 minutes — not on every app save — which keeps update
frequency battery-reasonable. Supports small/medium/large families and both accented
and full-color widget rendering modes.

**Adaptive UI**: `NavigationSplitView` for macOS/iPad, `NavigationStack` for compact
iPhone widths, with `#available` fallbacks from Liquid Glass (`.glassEffect`,
`.buttonStyle(.glass...)`) to `.bordered`/material backgrounds on pre-macOS/iOS 26.

## 3. Major user flows

1. **First launch** → onboarding sheet → dismiss → seeded starter notes (2 notes,
   one pre-pinned) shown in the sidebar/list.
2. **Create / edit a note** → title + Markdown-ish body (headings via `#`, checklist
   items via `- [ ]` / `- [x]`), live-parsed into `DisplayLine`s for previews and the
   widget.
3. **Style a note** → 10-color palette, 4 font styles (mono/system/rounded/serif).
4. **Pin a note** → shown in the macOS/iOS/iPadOS widget via the shared App Group.
5. **Search** notes by title/body.
6. **Trash** → move to Trash (30-day retention, countdown text), restore, or delete
   immediately; expired entries are purged on load and on every save snapshot.
7. **macOS menu bar quick access** → capture a note or jump to a recent one without
   opening the main window.
8. **Settings** → toggle onboarding replay, widget hint visibility, menu bar item.

## 4. What's *not* in this app (by design, confirmed against source)

No accounts, no network calls of any kind (`rg`'d for `http(s)://` in source: zero
hits), no analytics/tracking SDKs, no push notifications, no deep links/universal
links, no in-app purchase/subscription code, no Sign in with Apple, no camera/photo
library/location/microphone/contacts usage (no corresponding `Info.plist` usage
description keys, and none needed). This matches `PRIVACY.md`'s claim exactly and
matches both `PrivacyInfo.xcprivacy` manifests, which declare only the
`NSPrivacyAccessedAPICategoryUserDefaults` API with reasons `CA92.1` (app-local) and
`1C8F.1` (App-Group-shared) and an empty `NSPrivacyCollectedDataTypes`/tracking
declaration.

## 5. Dependencies, secrets, environment

- **Third-party dependencies**: none.
- **Secrets**: none found in source (`rg`'d for api key/secret/password/token/bearer
  patterns — zero hits). No `.env` or credentials files. `.gitignore` correctly
  excludes `DerivedData/`, `*.xcresult`, `xcuserdata/`, and the generated
  `CheatSheet.xcodeproj/`.
- **Required tooling**: Xcode 26+ and XcodeGen (`brew install xcodegen`), per
  `README.md`/`CONTRIBUTING.md`.
- **Signing**: `CODE_SIGN_STYLE: Automatic`, `DEVELOPMENT_TEAM: HD39MR492X` for every
  target. A local "Apple Development: Wesley Keetch" identity matching that team is
  present in this environment's keychain, so Debug/local builds sign successfully;
  this audit did not touch Distribution certificates or attempt an App Store Connect
  upload (out of scope for an automated pass — see §9).

## 6. Environment limitations for this audit

- **Xcode version**: this machine has Xcode 27.0 beta (`27A5252f`) only; no Xcode 26
  stable is installed. The project's CI (`.github/workflows/ci.yml`) pins to
  Xcode 26. All builds/tests in this audit ran on Xcode 27 beta — results are a
  useful supplementary signal but **do not replace** a green run on the pinned
  Xcode 26 CI toolchain before submitting. This is an environment gap, not a code
  defect.
- **No physical devices**: only iOS Simulator and local macOS were available. No
  on-device battery/thermal/VoiceOver-hardware testing was possible.
- **No Instruments profiling session**: performance review in §7 is static
  (code-reading), not measured. Documented as a limitation per the instructions
  rather than skipped silently.
- **No App Store Connect access**: this session has no App Store Connect
  credentials. Anything requiring that portal is listed as a manual action, not
  attempted.

## 7. Risk-based QA plan (executed in §ing QA report)

Given the app's small, well-tested surface area, the plan prioritizes:

1. Clean build + full existing test suite on macOS and iOS (arm64 + x86_64 where
   applicable), both Debug and Release.
2. Static review for crash risk: force unwraps/casts/try, `fatalError`, main-actor
   discipline, retain cycles, `Sendable` correctness.
3. Persistence resilience: load failure, save failure, corrupt data, migration,
   expiry — largely already covered by existing unit tests; verify they actually
   run and pass rather than assuming so.
4. Manual/simulator pass over the primary flows (create, edit, style, pin, trash,
   search, onboarding) on iPhone and iPad simulators, light and dark, at least one
   large Dynamic Type size.
5. Accessibility source review: labels, hints, identifiers, minimum hit targets,
   non-color selection indicators, Dynamic Type.
6. App Store compliance review: Info.plist, entitlements, privacy manifest, icon
   assets, export-compliance flag, category, copyright string, App Group
   consistency across every entitlements file and `project.yml`.
7. Repo hygiene: no committed secrets/build artifacts, no stale/broken
   documentation assets, no dead code paths.

Full results are in [app-store-release-qa-report.md](app-store-release-qa-report.md).
The completed/blocked/manual-action breakdown is in
[app-store-release-checklist.md](app-store-release-checklist.md).
