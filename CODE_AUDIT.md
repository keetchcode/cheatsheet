# CheatSheet Code Audit

Snapshot reviewed: 2026-08-25. Scope includes the current `main` checkout, the complete working-tree diff, all untracked source/scripts/screenshots, macOS, iOS/iPadOS, widgets, tests, CI, and public documentation.

## 1. Executive summary

1. **[High] Superseded saves can still overwrite newer notes** — §3.1 — `CheatSheetApp/Sources/NoteStore.swift:261-268`
2. **[High] SwiftData failure can reopen a stale legacy store** — §5.1 — `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:5-18`
3. **[High] Retrying a failed load discards in-memory edits** — §5.2 — `CheatSheetApp/Sources/NoteStore.swift:228-239`
4. **[High] The widget screenshot workflow can replace simulator notes** — §5.3 — `CheatSheetApp/Sources/CheatSheetLaunchEnvironment.swift:52-77`
5. **[Medium] Partial screenshot inputs can replace a complete final set** — §5.4 — `Scripts/compose-app-store-screenshots.py:380-410`
6. **[Medium] The persistence test double has unsynchronized mutable state** — §3.2 — `CheatSheetTests/Sources/NoteStoreTests.swift:432-462`
7. **[Medium] Editor typing rebuilds and sorts every note cache** — §7.1 — `CheatSheetApp/Sources/NoteStore.swift:27-30`
8. **[Low] Public setup guidance does not fully describe all supported platforms** — §10.1 — `README.md:40-44`

The app's intended scope is strong and should remain unchanged: fast local notes, one pinned widget note, simple formatting, no account, no sync, no network service, and no third-party dependencies. The current Liquid Glass implementation is appropriately restrained, correctly availability-gated on macOS 26 and iOS 26, and has sensible material/button fallbacks.

### Remediation status

Resolved in the reviewed working tree: §2.2, §3.1, §3.2, §5.1, §5.2, §5.3, §5.4, §8.1, §10.1, and §10.2. The persistence fixes have regression coverage, screenshot capture is isolated and deterministic, and the complete final screenshot set passes validation. Sections §5.5, §7.1, §8.2, §9.1, and §9.2 remain measured recommendations rather than release blockers; addressing them now would add disproportionate structure to a deliberately small app.

## 2. Quick wins

### 2.1 Reuse the simulator resolver
- **Location:** `Scripts/capture-app-store-screenshots.sh:36-59`; `Scripts/capture-widget-screenshot.sh:23-43`; `Scripts/resolve-ios-simulator.sh:12-30`
- **What:** Nearly identical simulator JSON parsing and runtime selection exists three times.
- **Why:** Small differences will drift as device/runtime names change.
- **Action:** Give the shared resolver an optional device-name argument and call it from both capture scripts.
- **Severity:** Low

### 2.2 Make screenshot demo seeding failures visible
- **Location:** `CheatSheetApp/Sources/CheatSheetLaunchEnvironment.swift:74-78`
- **What:** Demo-content seeding discards any repository error with `try?`.
- **Why:** A capture can silently use empty or old content and still look superficially valid.
- **Action:** Fail the screenshot launch with a clear diagnostic when deterministic seeding fails.
- **Severity:** Low

### 2.3 Decide which generated screenshot artifacts belong in git
- **Location:** `AppStoreScreenshots/README.md:1-68`; `CONTRIBUTING.md:47`
- **What:** Raw captures, composed finals, and a contact sheet are all stored in the repository while contributor guidance says generated files should stay out of commits.
- **Why:** The current 11 MB duplication will grow and the contribution policy is ambiguous.
- **Action:** Document an explicit policy; preferably track upload-ready finals and selected README previews while ignoring reproducible raw/contact-sheet output.
- **Severity:** Low

## 3. Concurrency

### 3.1 Superseded saves can still overwrite newer notes
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:261-268`; `CheatSheetApp/Sources/NoteStore.swift:388-397`
- **What:** Cancelling `saveTask` does not prevent a task already waiting to enter `NotePersistenceWorker.save` from writing its stale snapshot; generation checks only suppress stale UI status.
- **Why:** Rapid edits can allow an older snapshot to land after a newer snapshot, losing the newest note state.
- **Action:** Check cancellation inside the actor immediately before the repository write and add a delayed overlapping-save regression test. A single coalescing persistence loop would provide the strongest latest-write-wins guarantee.
- **Severity:** High

### 3.2 Persistence test double has a real data race
- **Location:** `CheatSheetTests/Sources/NoteStoreTests.swift:432-462`
- **What:** `SpyNoteRepository` declares `@unchecked Sendable` while `loadError`, `saveError`, and `savedNotes` are mutable and unsynchronized.
- **Why:** Worker-actor saves can race main-actor test reads or writes, creating flaky tests and Thread Sanitizer failures.
- **Action:** Protect the state with a lock/`Mutex`, or use an actor-backed async test seam instead of unchecked sendability.
- **Severity:** Medium

## 4. API modernity

_No findings._ The reviewed SwiftUI code uses modern navigation, observation, change handling, accessibility modifiers, and correctly gated Liquid Glass APIs. No app-source compiler warnings or deprecated API warnings were observed.

## 5. Bugs / logic errors

### 5.1 SwiftData failure can reopen a stale legacy store
- **Location:** `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:5-18`; `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:47-63`
- **What:** Any SwiftData container creation failure falls back to writable legacy UserDefaults even after legacy data has already been migrated and SwiftData marked initialized.
- **Why:** A transient SwiftData failure can expose stale legacy notes, accept edits there, and then make those edits disappear once the nonempty SwiftData store opens again.
- **Action:** Consult the initialization marker before allowing writable legacy fallback. After migration, surface storage unavailable/read-only or explicitly reconcile stores by note ID and modification date.
- **Severity:** High

### 5.2 Retrying a failed load discards in-memory edits
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:228-239`; `CheatSheetApp/Sources/PersistenceStatusBanner.swift:52-59`
- **What:** The failure banner says edits are kept in memory, but `retryLoad()` replaces `notes` wholesale when loading later succeeds.
- **Why:** Notes or edits created during the failure disappear when the user selects **Try Again**.
- **Action:** Either disable mutations while loading is suspended, or preserve the suspended snapshot and require an explicit merge/discard decision before replacement.
- **Severity:** High

### 5.3 Widget screenshot capture can replace real simulator notes
- **Location:** `CheatSheetApp/Sources/CheatSheetLaunchEnvironment.swift:52-77`; `Scripts/capture-widget-screenshot.sh:97-105`
- **What:** Debug demo mode seeds the live App Group repository with replacement content, and the documented widget script runs it on an arbitrary existing named simulator.
- **Why:** Running the marketing workflow can permanently replace a developer's notes stored in that simulator's shared container.
- **Action:** Create or clone a dedicated disposable screenshot simulator/container, or back up and restore the store. Refuse demo seeding unless the process proves it is in that isolated environment.
- **Severity:** High

### 5.4 Partial screenshot inputs can replace a complete final set
- **Location:** `Scripts/compose-app-store-screenshots.py:380-410`; `Scripts/verify-app-store-screenshots.py:65-70`; `Scripts/verify-app-store-screenshots.py:115-145`
- **What:** Composition clears existing finals before validating the complete raw set, skips missing inputs, and succeeds after producing any image; verification accepts any 1–10 images in only the directories that exist.
- **Why:** A partial run can destroy the last complete upload set and still pass verification.
- **Action:** Preflight every declared device class and required filename, compose into a temporary directory, then atomically replace finals only after full success.
- **Severity:** Medium

### 5.5 Size-class root replacement can lose navigation context
- **Location:** `CheatSheetApp/Sources/ContentView.swift:40-50`; `CheatSheetApp/Sources/ContentView.swift:109-122`
- **What:** Compact and regular layouts replace the complete navigation root with unrelated `NavigationStack` and `NavigationSplitView` hierarchies while sharing a retained compact path.
- **Why:** iPad rotation or multitasking width changes can reset visible navigation and leave stale compact routing state.
- **Action:** Prefer one adaptive navigation structure, or isolate compact/regular roots and explicitly normalize path/selection when the layout class changes.
- **Severity:** Medium

## 6. Security

_No security vulnerability found._ Notes remain local, no network or account surface exists, App Groups are explicit, privacy manifests declare the relevant UserDefaults reasons, and UI tests use an in-memory store. The destructive screenshot-mode issue is tracked as a data-integrity bug in §5.3.

## 7. Performance

### 7.1 Every editor keystroke rebuilds and sorts all note caches
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:27-30`; `CheatSheetApp/Sources/NoteStore.swift:128-140`; `CheatSheetApp/Sources/NoteStore.swift:357-361`
- **What:** Updating one note replaces an array element, whose `didSet` filters and sorts all active and archived notes.
- **Why:** Typing cost grows with the complete note collection even though most edits do not change ordering.
- **Action:** Update the matching cached row for ordinary title/body/style edits and rebuild/re-sort only for insertion, deletion, archive, pin, or ordering changes. Measure before adding more machinery; the current behavior is acceptable for small collections.
- **Severity:** Medium

## 8. SwiftUI / UI

### 8.1 Menu-bar quick access does not use the shared glass vocabulary
- **Location:** `CheatSheetApp/Sources/MenuBarQuickAccessView.swift:35-91`; `CheatSheetApp/Sources/MenuBarQuickAccessView.swift:93-163`; `CheatSheetApp/Sources/MenuBarQuickAccessView.swift:208-245`
- **What:** The menu-bar UI uses direct bordered styles and one-off material/quaternary surfaces instead of the existing glass-compatible modifiers.
- **Why:** It is the main macOS quick-access surface but will look less cohesive than the primary window on macOS 26.
- **Action:** Use shared glass-compatible button/panel treatments for the primary actions and group neighboring glass elements. Keep decorative glass limited; interaction and content should stay dominant.
- **Severity:** Low

### 8.2 Motion polish should remain small and accessible
- **Location:** `CheatSheetApp/Sources/ContentView.swift:125-188`; `CheatSheetApp/Sources/PersistenceStatusBanner.swift:11-45`
- **What:** State changes currently appear without a coordinated transition, but the app has no Reduce Motion-sensitive animation policy.
- **Why:** A subtle insert/remove transition for the persistence banner, widget hint, and empty/editor state would improve clarity; broad decorative motion would work against the utility's purpose.
- **Action:** Add only short state-linked opacity/scale or content transitions, read `accessibilityReduceMotion`, and avoid continuous animation, timers, shaders, or gratuitous glass morphing.
- **Severity:** Low

## 9. Dead code / duplication / refactor

### 9.1 ContentView owns too many independent policies
- **Location:** `CheatSheetApp/Sources/ContentView.swift:4-409`
- **What:** One file contains root adaptation, toolbar placement, trash routing, widget education, compact list UI, and editor routing.
- **Why:** Cross-platform navigation fixes become harder to review and test in a 409-line orchestration view.
- **Action:** Extract `CompactNoteListView`, `WidgetSetupHintView`, and toolbar/navigation policy into focused files while keeping `ContentView` as the composition root.
- **Severity:** Low

### 9.2 NoteStore mixes persistence state with SwiftUI binding construction
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:1-5`; `CheatSheetApp/Sources/NoteStore.swift:128-140`
- **What:** The domain/persistence store imports SwiftUI primarily to manufacture an ID-based `Binding`.
- **Why:** It couples core state to the UI framework and adds another responsibility to a 398-line store.
- **Action:** Expose an ID-based update method/subscript and construct the binding in the editor/root view or a small UI adapter.
- **Severity:** Low

## 10. Cross-cutting recommendations

### 10.1 Document all deployment targets and platform paths
- **Location:** `README.md:40-44`; `README.md:26`; `project.yml:4-6`; `CONTRIBUTING.md:24-38`; `CONTRIBUTING.md:68-76`
- **What:** Requirements list macOS only, Liquid Glass is described only for macOS, and contributor/testing/issue guidance remains macOS-centric despite iOS/iPadOS and two widget targets.
- **Why:** Public contributors cannot quickly tell the supported deployment matrix or run the matching verification path.
- **Action:** State macOS 15+, iOS/iPadOS 18+, Liquid Glass on both platform families at version 26+, the iOS test command, all four entitlements, and platform/OS details required in bug reports.
- **Severity:** Low

### 10.2 Keep the product boundary explicit
- **Location:** `README.md:1-35`; `CONTRIBUTING.md:1-5`
- **What:** The repository already describes a small local utility, but there is no short non-goals section.
- **Why:** Open-source feature requests can gradually pull the app toward sync, accounts, rich documents, and dependency-heavy architecture.
- **Action:** Add a concise product-principles/non-goals section: local-first, instant, one pinned widget note, plain-text-oriented, native frameworks, no account/network requirement, and no feature unless it improves glanceability or capture speed.
- **Severity:** Low

## 11. What was NOT audited

- Signed archives, notarization, TestFlight, and App Store Connect state.
- Physical-device behavior, widget refresh timing, and cross-process App Group behavior under production signing.
- SpringBoard widget placement on a physical device; simulator UI flows and iPad screenshot capture were exercised, while the disposable widget-capture script was reviewed but not run end-to-end.
- VoiceOver, keyboard-only navigation, Dynamic Type, Reduce Motion, and contrast on live devices.
- Instruments, energy, memory, launch-time, and SwiftUI invalidation traces.
- Localization quality; the project currently presents English UI.
- Historical behavior before the current checkout except where the git history/diff made intent clear.

## 12. Verification

- Superseded-save cancellation, safe SwiftData fallback, suspended-edit protection, and repository synchronization now have focused regression coverage.
- Screenshot demo seeding is restricted to test/screenshot mode, widget capture uses a disposable simulator, and composition replaces finals only after complete preflight and successful generation.
- Project configuration verification passed.
- iOS Simulator unit tests passed: **52 tests across 5 suites**.
- macOS arm64 unit tests passed: **52 tests across 5 suites**.
- macOS x86_64 unit tests passed: **52 tests across 5 suites**.
- iPhone Simulator UI smoke tests passed: **4 tests**, covering launch, onboarding, note creation, and healthy persistence state.
- iPad Simulator screenshot UI tests passed in dark and light appearances.
- App Store screenshot verification passed for **12 files** across iPhone 6.9-inch and iPad 13-inch classes.
- Universal macOS Release build passed and contained **arm64 + x86_64**.
- `git diff --check` passed.
- No app-source compiler warning was observed. One Xcode 27 beta launch-session assertion warning came from the IDE toolchain, not the app source.
