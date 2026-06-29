# CheatSheet Mac App Store Release and QA Plan

Updated: June 21, 2026

## Scope and Assumptions

- This plan is based on the current repository, with `project.yml` as the source of truth.
- CheatSheet is a native SwiftUI Mac app with a WidgetKit extension. It has no accounts, networking, analytics, advertising, payments, or third-party packages.
- Notes are stored locally with SwiftData and legacy `UserDefaults` migration. The widget reads locally shared data through an App Group.
- The current minimum deployment target is macOS 15.0, not macOS 27. macOS 27 is currently beta. Keep macOS 15.0 unless product requirements intentionally drop older Macs; test macOS 27 as forward compatibility, not as the minimum.
- Current release identity is version 1.1, build 3. A first App Store release may use 1.1, but use 1.0 if that is the intended public product version.

## Current Readiness Snapshot

Verified from the repository:

- Main bundle ID: `com.wesleykeetch.wesleycheatsheet`.
- Widget bundle ID: `com.wesleykeetch.wesleycheatsheet.widgets`.
- App Store Connect app name: `Liquid Glass: CheatSheet`.
- Team ID: `HD39MR492X`.
- Shared App Group: `HD39MR492X.com.wesleykeetch.wesleycheatsheet`.
- App and widget both enable App Sandbox and the same App Group.
- Swift language mode is 6.0; minimum macOS is 15.0.
- App category is Productivity.
- All plist and entitlement files parse successfully.
- The generated project exposes the expected app, widget, and test targets.
- There are no requested camera, microphone, location, contacts, photos, broad file, incoming-network, or outgoing-network capabilities.
- There are no third-party SDKs or Swift Package dependencies.
- Existing Swift Testing coverage contains 36 tests in five suites; the arm64 suite passed on June 21, 2026 using Xcode 26.5.

Release blockers or required decisions:

1. Run `Scripts/verify-macos.sh`, then complete a signed archive and Organizer validation on the release Mac. The June 21 diagnosis traced the earlier hang to File Provider coordination of the generated `.xcodeproj`; generating the project under `/private/tmp` resolved it, and 36 arm64 tests passed.
2. Register and enable the App Group for both explicit App IDs in Certificates, Identifiers & Profiles.
3. Confirm the 1024 px icon is fully opaque. Its current PNG contains an alpha channel; flatten it and regenerate all icon sizes if Organizer reports transparency.
4. Add a UI-test target and automate the critical app flows below, or complete and record the equivalent manual regression before submission.
5. Finish App Store Connect privacy, age rating, pricing, availability, support URL, privacy-policy URL, screenshots, and review notes.

## A. Release Readiness Checklist

### Build Configuration

- In `project.yml`, keep `MACOSX_DEPLOYMENT_TARGET: 15.0` and `SWIFT_VERSION: 6.0`. Build with the latest stable Xcode accepted by App Store Connect; use Xcode 27 beta only for macOS 27 compatibility testing.
- Add `ENABLE_HARDENED_RUNTIME: YES` to the app and widget Release settings in `project.yml`, regenerate, and confirm both targets still run. App Sandbox is the Mac App Store requirement; Hardened Runtime is additional defense and avoids distribution-mode drift.
- Keep automatic signing for the first archive unless the team requires managed profiles. Confirm the Release archive uses Apple Distribution signing and Mac App Store provisioning for both executables.
- Keep only the two existing entitlements. Do not add temporary sandbox exceptions, file access, network, camera, microphone, or location entitlements without a real feature that needs them.
- Set `ITSAppUsesNonExemptEncryption: NO` in the main app Info.plist only after confirming there is no custom or non-exempt encryption. Current source has no network or cryptography code.
- In Release build settings verify `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`, optimization is the Xcode Release default, testability is off, and no `-Onone`, sanitizer, debug dylib, or diagnostic launch argument leaks into Archive.

### Identifiers and Signing

- Apple Developer portal: create or verify explicit App IDs for `com.wesleykeetch.wesleycheatsheet` and `com.wesleykeetch.wesleycheatsheet.widgets`.
- Enable App Groups on both identifiers and attach `HD39MR492X.com.wesleykeetch.wesleycheatsheet` to both.
- App Store Connect: create the macOS app record as `Liquid Glass: CheatSheet` with the exact main bundle ID and SKU; bundle IDs cannot be corrected after a build is attached.
- Archive inspection must show the widget nested at `CheatSheet.app/Contents/PlugIns/CheatSheetWidgets.appex`, with the extension bundle ID and versions matching the parent.

### Info.plist and Assets

- Keep `LSApplicationCategoryType = public.app-category.productivity`, display name, copyright, version, and build values generated from `project.yml`.
- Do not add `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, or location usage strings: the app does not call those APIs.
- Flatten the AppIcon images against an opaque background, then check the 16, 32, 64, 128, 256, 512, and 1024 px renditions in light and dark appearances.
- Keep the app and widget privacy manifests in resources; both declare the required-reason `UserDefaults` API used for local preferences and app-group widget snapshots.

### Privacy and Permission Verification

Run from a clean macOS user account and reset prior decisions before retesting.

- First launch: expect no camera, microphone, location, contacts, photos, network-volume, Downloads, or Documents prompts.
- Notes: create/edit/relaunch and verify persistence only inside the signed app/App Group containers. Do not inspect or write arbitrary user folders.
- Widget: add it from the gallery, pin a note, edit it, archive it, and verify the timeline updates without access prompts.
- Activity Monitor: enable the Sandbox column and confirm `CheatSheet` is shown as sandboxed.
- System Settings > Privacy & Security: verify CheatSheet does not appear under Camera, Microphone, Location Services, Contacts, Photos, or Full Disk Access after the full test pass.
- App Store Connect privacy answer, based on current code: **Data Not Collected**. Re-audit this answer whenever networking, analytics, crash reporting, accounts, or an SDK is added.

### Performance and UX Gates

- Cold start: test after reboot and after `killall CheatSheet`; target useful UI within 1 second on a representative Apple Silicon Mac and within 2 seconds on the slowest supported Intel Mac.
- Main-thread responsiveness: use Instruments > Time Profiler and Hangs while creating, searching, editing, archiving, restoring, and switching 500 notes. No visible input hitch should exceed 100 ms.
- Memory: use Allocations and Leaks for a 15-minute edit/search/trash/widget session. Require zero persistent leaks and no unbounded growth after repeating the workflow five times.
- Persistence: type continuously for 60 seconds, quit normally, force quit, relaunch, and verify the last flushed content. Confirm the 400 ms debounce does not lose final edits when the scene becomes inactive.
- Logging: inspect Console for faults, crashes, sandbox denials, SwiftData migration errors, and widget timeline failures. Note titles and bodies must remain private in logs.
- Widget: verify placeholder, snapshot, small/medium/large families, no pinned note, long content, archived pinned note, restart, logout/login, and upgrade from a legacy `UserDefaults` install.

### Compatibility and Accessibility

- OS matrix: macOS 15 latest patch, macOS 26 latest stable, and macOS 27 beta. Add every stable major version between the minimum and current release if hardware/VMs are available.
- CPU matrix: native Apple Silicon and native Intel. Also inspect the archive with `lipo -info`; use a universal binary only if Intel remains supported.
- Display matrix: 1280x800, 1440x900, Retina 2560x1600 or larger, smallest supported window, maximized window, and multiple displays.
- Appearance: light, dark, Increase Contrast, Reduce Transparency, Reduce Motion, Differentiate Without Color, and accent-color changes.
- Input: keyboard-only navigation, Full Keyboard Access, VoiceOver labels/order, menu commands, search focus, Escape/Return behavior, mouse, and trackpad.
- Content: empty, one note, 500 notes, very long title/body, emoji, right-to-left text, large accessibility text, and US/non-US locale. Current UI is English-only; either declare English only or add a string catalog before localization.

## B. Test Plan

### Existing Unit Tests

Run both architectures and build the universal Release app outside File Provider coordination:

```sh
Scripts/verify-macos.sh
```

The script generates the project bundle and DerivedData in `/private/tmp`, links
the repository inputs into that local project root, disables indexing/stat-cache
work, and runs tests serially. This is required while this checkout remains under
a File Provider-managed Documents directory. Moving the checkout to a normal
local directory such as `~/Developer/CheatSheet` removes the need for the wrapper.

The current suites cover parsing, repository save/load and migration, note-store selection/pinning/persistence, trash behavior, and widget note selection. Add focused tests for:

- SwiftData migration idempotence when both legacy and current stores contain data.
- Migration/store corruption recovery without replacing valid notes.
- Exact 30-day trash expiration boundary and clock changes.
- Rapid edit/debounce cancellation followed by scene flush.
- Large collections and duplicate IDs.
- Widget output for no notes, only archived notes, and very long Unicode content.

### UI Automation

Add `CheatSheetUITests` in `project.yml` with deterministic launch arguments for an isolated temporary store. Automate:

1. Fresh launch, onboarding completion, relaunch, and onboarding reset from Settings.
2. Create, rename, edit, search, select, and delete a note.
3. Pin one note, pin another, and confirm only one remains pinned.
4. Move to Trash, restore, permanently delete, and return from an empty Trash.
5. Change palette/font and verify controls expose selected accessibility state.
6. Launch with 500 seeded notes and measure search/edit responsiveness.

Widget gallery installation remains a manual system integration test; UI tests should cover the shared selection rule and app-side pinning.

### Manual Matrix and Exit Criteria

- Run the full critical workflow on every OS/CPU row above with network online and offline. Behavior should be identical because the app has no networking.
- Use a new macOS account for first-launch and TestFlight install tests; also test over an existing development install to catch container/signature and migration issues.
- Exit only with: zero crashers, zero data-loss bugs, zero sandbox denials, zero Accessibility Inspector critical findings, no unresolved Organizer validation errors, and documented disposition for warnings.

### Crash Triage

1. Record version/build, Mac model/CPU, macOS version, install source, exact steps, frequency, and whether the data store was migrated.
2. Collect the crash report from App Store Connect/Xcode Organizer or Console, plus relevant privacy-redacted system logs.
3. Preserve the exact `.xcarchive` and dSYMs for every uploaded build. Match UUIDs with `dwarfdump --uuid` before symbolication.
4. Reproduce with the same signed build and store state; then use Address Sanitizer, Thread Sanitizer, or Zombies in separate Debug runs as appropriate.
5. Add a regression test, fix the smallest owning component, rerun both unit architectures and the affected manual workflow, then increment the build number.

## C. Optimization Recommendations

- `NoteStore` currently loads, filters, sorts, and saves synchronously on `@MainActor`. This is acceptable for small note sets, but profile 500+ notes. If traces show stalls, move SwiftData fetch/save work behind a `ModelActor` and return immutable values to the main actor.
- `activeNotes`, `archivedNotes`, and filtered variants repeatedly filter/sort arrays. Do not pre-emptively cache them; optimize only if Time Profiler shows measurable cost, then centralize invalidation when `notes` changes.
- Keep the 400 ms save debounce and conditional widget reload. Performance tests must prove final-edit flushing and that ordinary non-pinned edits do not trigger unnecessary widget timelines.
- There is no networking, so do not add a cache layer. If sync is introduced, define offline behavior, request coalescing, cache expiry, retry/backoff, and App Privacy changes before implementation.
- Measure archive and installed size. Remove unused assets/localizations and verify App Thinning output; do not add an app-level splash screen or eager startup work.
- CI should pin XcodeGen and stable Xcode versions, regenerate the project, run `git diff --exit-code` for generated drift if the project becomes tracked, lint plists, run arm64 tests on each change, and run x86_64 plus signed archive validation on release branches. Avoid uploading from beta Xcode unless App Store Connect explicitly accepts that build.

## D. App Store Submission Preparation

### Versioning

- `CFBundleShortVersionString` is the customer-visible release version, currently 1.1.
- `CFBundleVersion` is the monotonically increasing build number, currently 3. Every upload for version 1.1 must use 4, 5, and so on after the previous build is uploaded.
- App and widget must use the same marketing version and build number.

### Archive and Artifact Verification

```sh
xcodegen generate --spec project.yml
xcodebuild -project CheatSheet.xcodeproj -scheme CheatSheetApp -configuration Release -destination 'generic/platform=macOS' -archivePath /private/tmp/CheatSheet.xcarchive archive
codesign --verify --deep --strict --verbose=2 /private/tmp/CheatSheet.xcarchive/Products/Applications/CheatSheet.app
codesign -d --entitlements :- /private/tmp/CheatSheet.xcarchive/Products/Applications/CheatSheet.app
codesign -d --entitlements :- /private/tmp/CheatSheet.xcarchive/Products/Applications/CheatSheet.app/Contents/PlugIns/CheatSheetWidgets.appex
lipo -info /private/tmp/CheatSheet.xcarchive/Products/Applications/CheatSheet.app/Contents/MacOS/CheatSheet
```

- Prefer Product > Archive in stable Xcode, then Organizer > Validate App. Resolve every error and understand every warning before Distribute App > App Store Connect > Upload.
- Inspect archived Info.plists for version, build, deployment target, category, bundle IDs, and extension point. Confirm dSYMs exist and no development provisioning, debug entitlement, test bundle, or unexpected framework is embedded.
- After processing, enable internal Mac TestFlight testing. Install from TestFlight on a clean user account and repeat the critical workflow before selecting that build for review.

### Metadata and Assets

- Upload 1-10 Mac screenshots at one accepted 16:10 size: 1280x800, 1440x900, 2560x1600, or 2880x1800. Prefer 2880x1800 and show only shipping UI.
- Recommended order: editor/sidebar, desktop widget, checklist workflow, palette/font controls, and Trash restore. Keep claims literal and ensure screenshot text is readable.
- Complete app name (`Liquid Glass: CheatSheet`), description, keywords, support URL, privacy-policy URL, copyright, category, pricing, territories, release method, and review contact.
- Complete the age-rating questionnaire based on the app itself, not arbitrary user-authored notes; do not select Kids Category.
- Review notes: explain that no account is required and provide exact widget steps: launch, create/select a note, choose **Use in Widget**, then add CheatSheet from the macOS widget gallery.

### Situation-Specific Blockers

- App Group missing or mismatched on either provisioning profile: app may work while widget is blank.
- Transparent or malformed Mac icon: asset/Organizer validation failure.
- Unsigned or differently versioned widget extension: upload rejection.
- App privacy says Data Not Collected while a future SDK or network feature collects data: compliance rejection.
- Screenshot dimensions outside Apple's four accepted Mac sizes: metadata cannot be submitted.
- Minimum OS accidentally changed to macOS 27: excludes all current stable customers and ties release to beta tooling.
- Missing support/privacy URLs, age rating, review contact, pricing/availability, export-compliance answer, or selected build: submission remains incomplete.

## E. Ordered Runbook: Today to Submit

1. Freeze features; triage existing uncommitted changes; choose public version 1.0 or 1.1 and increment the build.
2. Update `project.yml` for Hardened Runtime and final version/build; add `ITSAppUsesNonExemptEncryption` only after the encryption check; regenerate with XcodeGen.
3. Flatten/validate AppIcon alpha and capture final 2880x1800 screenshots.
4. Register both App IDs and the shared App Group in the Developer portal; refresh signing in stable Xcode.
5. Run plist lint, `git diff --check`, arm64 and x86_64 unit tests, then the UI/manual matrix on macOS 15 and 26.
6. Run forward-compatibility smoke tests using Xcode 27 beta and macOS 27 beta; do not use the beta archive for submission.
7. Profile cold launch, typing/search, 500-note behavior, memory/leaks, and widget timelines; fix only measured regressions and rerun affected tests.
8. Create the signed Release archive in stable Xcode; inspect signatures, entitlements, versions, architectures, extension embedding, dSYMs, and archived plists.
9. Validate and upload in Organizer. Resolve all processing warnings, complete export compliance, and wait for the build to finish processing.
10. Distribute through internal Mac TestFlight. On a clean account test onboarding, edit/persist/relaunch, pin/add/update widget, search, styles, Trash/restore/delete, offline use, and uninstall/reinstall.
11. Complete App Store Connect privacy (`Data Not Collected`), age rating, URLs, pricing, availability, metadata, screenshots, and review notes.
12. Select the tested build, Add for Review, inspect the draft submission once more, then Submit for Review. Use manual release after approval for the first version so availability can be checked before launch.
