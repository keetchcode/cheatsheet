# CheatSheet Release Readiness

Updated: August 26, 2026

This is the current release checklist for the macOS, iOS, iPadOS, and WidgetKit targets. `project.yml` is the configuration source of truth. Historical analysis lives in the clearly labeled audit snapshots; current engineering findings live in `CODE_AUDIT.md`.

## Product scope

CheatSheet is a deliberately small, local-only developer note app. It creates and edits short plain-text notes, searches titles and bodies, styles notes with ten colors and four fonts, moves notes through a 30-day Trash, offers macOS menu-bar quick capture, and shows one selected note through WidgetKit. It has no account, networking, sync, analytics, advertising, payment, or third-party SDK.

## Current release identity

- Marketing version: 1.1
- Current repository build: 12
- App bundle ID: `com.wesleykeetch.wesleycheatsheet`
- Widget bundle ID: `com.wesleykeetch.wesleycheatsheet.widgets`
- Apple team: `HD39MR492X`
- Minimum systems: macOS 15 and iOS/iPadOS 18
- Swift language mode: Swift 6
- Category: Productivity
- App Store name: `Liquid Glass: CheatSheet`
- App privacy answer: Data Not Collected, while the current source remains local-only

## Verified in the repository

- macOS and iOS/iPadOS apps plus both WidgetKit extensions are generated from `project.yml`.
- Platform-specific App Groups match between each app and widget entitlement.
- macOS app and widget use App Sandbox and Hardened Runtime in Release.
- Privacy manifests declare no collection or tracking and include required-reason UserDefaults access.
- `ITSAppUsesNonExemptEncryption` is false for both main apps; the source contains no networking or custom cryptography.
- SwiftData migration preserves legacy notes, rejects corrupt payloads without destructive fallback, and treats an initialized empty store as authoritative.
- Unit coverage includes parsing, ordering, migration, duplicate IDs, corruption, saving, selection, pinning, Trash boundaries, persistence failures, debounce ordering, and widget selection.
- Deterministic UI automation uses an in-memory store and covers onboarding, healthy launch, creation, edit/search, color/font/pinning, and Trash restore/permanent deletion.
- The upload-ready iPhone and iPad screenshot sets are genuine app captures and pass dimension, format, color, alpha, size, count, ordering, and caption checks.
- App Store metadata in `Docs/AppStoreDescription.md` passes Apple's character limits.

## Release gates

### Verified locally

- Project generation and configuration validation
- Clean iOS Release Simulator build with no app-source warnings
- iOS unit tests and deterministic UI tests
- macOS arm64 and x86_64 tests
- Universal macOS Release build and architecture inspection
- Native iPhone and iPad screenshots in light and dark appearances
- Repository privacy, entitlement, and dependency review

### Must be verified with distribution signing

- iOS and macOS archives signed with Apple Distribution identities
- Production provisioning profiles containing the correct App Groups
- Embedded widget bundle IDs, versions, signatures, and entitlements
- Organizer validation with a currently supported stable Xcode
- Processed App Store Connect builds installed from TestFlight
- Widget installation and refresh from the system gallery on physical iPhone, iPad, and Mac
- Upgrade/migration over the previously published build

### External App Store Connect work

- Sign in and confirm the app/version records and latest processed build
- Upload the final iPhone, iPad, and required 16:10 Mac screenshots
- Apply the metadata, support URL, and privacy-policy URL from `Docs/AppStoreDescription.md`
- Confirm Data Not Collected, age rating, pricing, availability, copyright, review contact, and manual release selection
- Attach the tested build, add it for review, inspect the submission, and submit

## Required QA matrix

Run the critical workflow—onboarding, create, edit, relaunch, search, style, pin, widget refresh, archive, restore, permanent delete, and offline launch—on:

- iPhone compact width and rotation
- iPad portrait, landscape, and split-screen size changes
- macOS minimum window and a normal desktop window
- Light and Dark appearances
- standard and accessibility text sizes
- Increase Contrast, Reduce Transparency, Reduce Motion, and Differentiate Without Color
- VoiceOver or Accessibility Inspector, plus keyboard-only navigation on Mac/iPad

System integration checks must include small, medium, and large widgets; no-note and long-note states; pinning a replacement note; archiving the pinned note; restart; and upgrade from build 11 or the latest public build.

## Performance and stability policy

The app is optimized for short notes and modest collections. Editing updates the affected visible cache entry rather than filtering and sorting the whole collection on every keystroke. Persistence is serialized and debounced, and stale completions cannot publish widget state.

Remaining architectural opportunities are not release blockers without measured regressions:

- Initial SwiftData container creation/load still occurs before first render. Measure cold launch with a realistically large migrated store before introducing an asynchronous loading state.
- Each save writes the complete collection. Measure typing and save latency with 500 notes before replacing the simple repository contract with granular mutations.
- Final scene deactivation flush is asynchronous. Validate rapid edit-then-lock/terminate behavior on physical devices; adopt background execution or journaling only if this produces loss in real testing.

## Publication runbook

1. Freeze the release candidate and increment the build number once.
2. Regenerate the project and run configuration, plist, entitlement, privacy, screenshot, and metadata validation.
3. Run all unit and UI suites, macOS dual-architecture verification, and unsigned Release builds.
4. Complete the accessibility and physical-device/widget matrix.
5. Build signed iOS and macOS archives using an App Store-supported stable Xcode.
6. Inspect archive identities, entitlements, embedded extensions, versions, architectures, and dSYMs; then run Organizer validation.
7. Upload both platform builds and install the processed binaries through internal TestFlight.
8. Repeat the critical workflow and upgrade test on the TestFlight builds.
9. Complete App Store Connect metadata and screenshots, select the tested builds, and submit for review with manual release.

Do not describe source builds, simulator tests, or GitHub CI as proof of production signing, physical-device behavior, TestFlight processing, or App Review approval.
