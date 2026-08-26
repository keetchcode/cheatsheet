# CheatSheet Code Audit

Generated 2026-08-25 from commit `c3cbd31` and updated after the remediation pass. Scope: 50 Swift files across macOS, iOS/iPadOS, WidgetKit, unit tests, UI tests, CI, and screenshot tooling. The focused recent-change range is `9af40e7^..c3cbd31` (five direct-to-`main` commits). GitHub contains no pull requests for this repository, so there were no PR discussions, approvals, or merge checks to reconcile.

The app has a strong product premise and a disciplined dependency-free implementation. The confirmed data-authority defect, stale widget side effect, shared-window navigation ambiguity, broad content glass, editor cache churn, public error details, and small structural issues identified below were remediated. Local cross-platform tests and published CI are green. **Senior review decision: source changes approved.** Signed distribution, physical-device accessibility, and live widget behavior remain release-process checks rather than source-review failures.

## 1. Executive summary

1. **[Resolved] Deleted notes or starter content could return after initialization** — §5.1.
2. **[Medium] SwiftData initialization and loading block the main actor** — §3.1 — `CheatSheetApp/Sources/NoteStore.swift:65-96`.
3. **[Resolved] Stale save completion widget effects** — §3.2.
4. **[Resolved] Shared selection across windows** — §5.2.
5. **[Resolved] Editor typing rebuilt and sorted all note caches** — §7.1.
6. **[Resolved] Custom Liquid Glass was overused as content chrome** — §8.1.
7. **[Resolved] Size-class replacement could discard visible context** — §5.3.
8. **[Low] Repository concurrency relies on unchecked promises** — §3.3 — `Shared/Sources/CheatSheetNoteRepository.swift:41-49`.

No critical security issue, compiler warning, deprecated API, network exposure, third-party dependency risk, continuous animation, shader, or unbounded background task was found.

## 2. Quick wins

### 2.1 Resolved: validate save generation before widget effects
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:311-315`
- **What:** The generation guard follows the widget reload call.
- **Why:** Moving the guard above every completion side effect is a small change with a clear ordering benefit.
- **Resolution:** The generation guard now precedes widget effects.

### 2.2 Resolved: share screenshot-writing support
- **Location:** `CheatSheetUITests/Sources/AppStoreScreenshotUITests.swift:197-227`; `CheatSheetUITests/Sources/WidgetScreenshotUITests.swift:167-197`
- **What:** Both suites duplicate attachment creation, directory creation, PNG writing, environment parsing, and failure reporting.
- **Why:** A test-only helper would remove about 60 synchronized lines without affecting production architecture.
- **Resolution:** Both suites now use `XCTestCase.captureScreenshot(named:)`; the unused app argument and duplicated file-writing code were removed.

### 2.3 Resolved: normalize the persistence worker declaration
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:388-399`
- **What:** The file-scope actor is indented as if it remains nested in `NoteStore`.
- **Why:** The misleading structure makes a safety-critical boundary harder to scan.
- **Resolution:** The actor declaration is aligned at file scope.

## 3. Concurrency

### 3.1 Persistence loading runs synchronously on the main actor
- **Location:** `CheatSheetApp/Sources/CheatSheetApp.swift:8-10`; `CheatSheetApp/Sources/NoteStore.swift:65-96,230-233`; `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:54-58,132-135`
- **What:** App initialization constructs the SwiftData container and fetches notes synchronously through the main-actor `NoteStore`; Retry performs the same synchronous fetch.
- **Why:** Migration, corruption recovery, file coordination, or a larger store can delay first presentation or freeze the Retry interaction.
- **Action:** Put container setup and reads behind an asynchronous persistence actor, start with an explicit loading state, and publish the result on the main actor while retaining the current safe failure suspension.
- **Severity:** Medium

### 3.2 Resolved: stale save completions could affect widget publication
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:259-275,311-340`
- **What:** Generation checks prevent old completions from changing visible persistence status, but `handleSaveSuccess` updates widget bookkeeping and reloads timelines before checking the generation.
- **Why:** A cancelled synchronous write can finish late, leave `lastReloadedWidgetNote` representing an older snapshot, and issue a stale or redundant final widget reload.
- **Resolution:** The generation guard now precedes widget bookkeeping, timeline reload, status, and task cleanup.

### 3.3 Stateful repositories use `@unchecked Sendable`
- **Location:** `Shared/Sources/CheatSheetNoteRepository.swift:41-49,97-105,135-144`; `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:36-51`; `CheatSheetApp/Sources/NoteStore.swift:388-398`
- **What:** Stateful synchronous repositories opt out of compiler checking while serialization is supplied by the current consumer's private actor.
- **Why:** A future intent, widget, or shared-code consumer can call the public repositories concurrently without compiler enforcement.
- **Action:** Prefer an actor-isolated asynchronous repository boundary or give each implementation internal synchronization with documented invariants.
- **Severity:** Low

## 4. API modernity

_No findings._ Fresh iOS and macOS clean builds emitted no app-source warnings. Navigation, Observation, `onChange`, accessibility, and availability checks use current APIs for the declared targets. Liquid Glass requires Xcode 26 and CI now selects it explicitly.

## 5. Bugs / logic errors

### 5.1 Resolved: deleted notes or starter content could be resurrected after initialization
- **Location:** `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:57-76`; `Shared/Sources/CheatSheetNoteRepository.swift:57-61`; `CheatSheetTests/Sources/NoteRepositoryTests.swift:135-181`
- **What:** When SwiftData fetches an empty store, `loadNotes()` imports the legacy repository before checking `hasInitializedSwiftDataStore`. A retained legacy payload restores migrated notes; the production legacy repository also returns nonempty starter notes when it has no payload. The existing empty-store regression test substitutes `EmptyLegacyRepository`, masking both production paths.
- **Why:** After initialization, deleting every note and relaunching can reverse the intentional empty state by restoring old notes or starter content.
- **Resolution:** Initialized SwiftData is checked before legacy loading. Regression tests cover retained legacy notes and the production no-payload UserDefaults behavior.
- **Introduced by:** `87323a8` (`Implement iOS audit fixes`).
- **Severity:** High

### 5.2 Resolved: every app window shared one selection
- **Location:** `CheatSheetApp/Sources/CheatSheetApp.swift:5-39`; `CheatSheetApp/Sources/NoteStore.swift:37-43`
- **What:** One app-owned `NoteStore`, including `selectedNoteID`, is injected into every `WindowGroup` scene.
- **Why:** Opening or navigating a note in one macOS or iPad window changes the detail shown by other windows, which conflicts with normal Apple multiwindow expectations and can confuse simultaneous editing.
- **Resolution:** The deliberately minimal product now declares one macOS `Window` and disables iOS multiple scenes.

### 5.3 Resolved: size-class changes replaced the navigation root without reconciliation
- **Location:** `CheatSheetApp/Sources/ContentView.swift:41-51,73-123,143-175`
- **What:** Compact and regular layouts swap complete `NavigationStack` and `NavigationSplitView` roots while retaining separate selection/path state.
- **Why:** iPad rotation or multitasking width changes can reset the visible route or reappear with stale compact navigation state.
- **Resolution:** Size-class changes now reconcile the compact path with the selected note.

## 6. Security

### 6.1 Resolved: framework persistence errors were logged publicly
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:304-320`; `CheatSheetWidgets/Sources/CheatSheetProvider.swift:35-36`
- **What:** Persistence and widget errors interpolate framework-provided descriptions using OSLog public privacy.
- **Why:** Some storage/container diagnostics can include local paths or implementation details. This is low risk in a local-only app, but unnecessary for public diagnostic output.
- **Resolution:** Underlying persistence error descriptions now use private OSLog interpolation.

No exploitable security vulnerability was found. Notes are local, the app has no account/network/IAP surface, privacy manifests cover UserDefaults access, app-group identifiers are explicit, and deterministic demo data is restricted to UI-test/screenshot modes. Signed distribution and production App Group behavior remain outside this source audit.

## 7. Performance

### 7.1 Resolved: each editor keystroke rebuilt every note cache
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:27-30,128-139,347-361`
- **What:** Updating one note replaces an array element whose observer filters the full collection twice and sorts active and archived caches.
- **Why:** Cost grows with the whole library and occurs on the main actor for every typed character; this is code-backed risk, not yet trace-backed user-visible jank.
- **Resolution:** Content/style edits now update the matching active or archived cache entry; structural changes still perform a full rebuild.

No images are decoded in render paths, list identity is stable, and there are no timers, shaders, continuous effects, or broad animations. No Instruments trace was captured, so CPU, frame pacing, launch time, and memory are unquantified.

## 8. SwiftUI / UI

### 8.1 Resolved: large content surfaces used custom Liquid Glass
- **Location:** `CheatSheetApp/Sources/EditorTextPanel.swift:24-39`; `CheatSheetApp/Sources/OnboardingView.swift:27-35,82-103`; `CheatSheetApp/Sources/OnboardingStepRow.swift:1-26`; `CheatSheetApp/Sources/StickyNotePreview.swift:40-43`; `CheatSheetApp/Sources/TrashNoteView.swift:17-55`
- **What:** On supported systems, the editor body, onboarding card/steps, preview, and trash content card receive custom glass panels.
- **Why:** Apple's current materials guidance treats Liquid Glass as a sparse functional layer for controls and navigation and advises standard materials for the content layer; broad content glass weakens hierarchy and competes with the note itself.
- **Resolution:** Editor, preview, step icons, and trash content now use calm material-backed surfaces. Native glass remains on controls and the onboarding modal layer.

### 8.2 Compact editor repeats the title
- **Location:** `CheatSheetApp/Sources/ContentView.swift:162-165`; `CheatSheetApp/Sources/EditorHeader.swift:7-12`
- **What:** iPhone displays the note name simultaneously as an inline navigation title and as the editable large title field.
- **Why:** The duplicate hierarchy consumes scarce vertical space and makes the screen feel like a form inside a detail page rather than a focused note canvas.
- **Action:** Keep the editable title as the content hero and use a generic/empty inline navigation title, or collapse the content title when the navigation title is visible.
- **Severity:** Low

### 8.3 Visual quality is coherent but not fully proven accessibly
- **Location:** `CheatSheetApp/Sources/GlassPaletteSwatchButton.swift:3-51`; `CheatSheetApp/Sources/EditorHeader.swift:14-51`; `CheatSheetApp/Sources/OnboardingView.swift:41-127`
- **What:** The code uses semantic fonts, 44-point iOS color targets, selection labels, non-color selection indicators, `ViewThatFits`, and scrollable onboarding, but no automated or recorded audit covers extreme Dynamic Type, VoiceOver order, Increase Contrast, Reduce Transparency, or keyboard-only traversal.
- **Why:** Accessibility and adaptation are core Apple design-award criteria; source-level care is necessary but not sufficient proof.
- **Action:** Add an accessibility QA matrix and at least one UI test at an accessibility text size; validate both appearances and transparency/contrast settings on physical iPhone, iPad, and Mac.
- **Severity:** Low

## 9. Dead code / duplication / refactor

### 9.1 Archive-expiry logic is duplicated
- **Location:** `CheatSheetApp/Sources/NoteStore.swift:364-385`
- **What:** The mutating purge and static load filter encode the same retention predicate separately.
- **Why:** A future policy adjustment can make load/retry behavior disagree with save-time behavior.
- **Action:** Keep one canonical filtering function and assign its result from the mutating path.
- **Severity:** Low

### 9.2 Test support dominates the largest source file
- **Location:** `CheatSheetTests/Sources/NoteStoreTests.swift:1-510`
- **What:** Behavioral tests, builders, synchronization state, and the repository spy share one 510-line file.
- **Why:** Persistence regression tests are now important enough that a monolithic fixture slows focused review and maintenance.
- **Action:** Move the repository spy/builders into test support and group persistence-failure/concurrency tests separately from note-operation tests.
- **Severity:** Low

No clearly unreachable production type, abandoned feature path, commented-out implementation, debug `print`, TODO/FIXME marker, or stale-version source file was found.

### 9.3 Historical audit documents compete with current truth
- **Location:** `REPO_AUDIT_IOS.md:1-18`; `REPO_AUDIT_IOS_IMPLEMENTATION.md:1-29`; `audit/REPORT.md`; `CODE_AUDIT.md`
- **What:** Multiple root-level/current-looking audit artifacts overlap, one includes a developer-machine absolute path, and older implementation claims are not visibly archived.
- **Why:** Public contributors cannot quickly tell which readiness assessment is authoritative.
- **Action:** Make `CODE_AUDIT.md` canonical; move historical reports under `Docs/Audits/` with clear as-of/archive banners and remove local absolute paths.
- **Severity:** Low

## 10. Cross-cutting recommendations

1. **Fix data authority before visual refinement.** §5.1 is the only release-blocking source defect found; the empty SwiftData store must remain authoritative after migration.
2. **Make state ownership match Apple scene behavior.** Durable notes can be shared, but selection/navigation should be per scene unless the app intentionally permits only one window.
3. **Let content lead and glass support it.** The strongest current screens are the plain iPhone list and editor. Reducing custom content glass will improve hierarchy more than adding morphing or decorative animation.
4. **Measure rather than speculate.** Profile launch and typing with a large Release fixture, then keep the current simple cache design if measurements show no meaningful hitching.
5. **Keep motion purposeful.** No decorative animation is preferable to arbitrary motion. If transitions are added, limit them to navigation/state continuity and honor Reduce Motion.
6. **Require PR review for material changes.** All five reviewed commits landed directly on `main`; branch protection with required CI and one approval would have made the migration lifecycle gap more likely to surface before publication.

## 11. What was NOT audited

- Physical-device launch, typing latency, thermal/energy behavior, memory growth, and frame pacing.
- VoiceOver, Voice Control, Switch Control, keyboard-only traversal, Dynamic Type extremes, Increase Contrast, Reduce Transparency, and Reduce Motion in live use.
- Signed App Group behavior, widget refresh timing, background snapshots, TestFlight, notarization, and App Store Connect.
- Simultaneous multiwindow interaction was reviewed from state ownership but not reproduced live.
- Older supported iOS 18/macOS 15 fallback appearance was compiled but not visually exercised.
- Localization beyond the current English interface.

## 12. Verification

- **§5.1 remediation** — initialized metadata is checked before legacy storage; two focused regression tests prove that an intentional empty state remains empty with retained legacy notes and production starter-note behavior.
- GitHub review found **zero pull requests** in the repository; the five reviewed commits were direct pushes to `main`.
- Fresh clean iOS Simulator and macOS arm64 builds succeeded with zero app-source warning/error lines under Xcode 27 beta.
- Published GitHub CI for commit `c3cbd31` passed macOS tests, iOS unit tests, configuration verification, and four iOS UI smoke tests using Xcode 26.
- Fresh local verification passed **54 tests across five suites** on iOS, macOS arm64, and macOS x86_64. A fresh universal macOS Release build contains both architectures.
- Twelve final screenshots were freshly captured at the standard content size in light and dark appearances, then passed exact device dimensions, PNG/RGB/no-alpha, size, ordering, and caption validation.
- Current native-resolution iPhone/iPad dark and light captures were visually inspected for hierarchy, layout, truncation, controls, and platform adaptation.
- `git diff --check` passed after the remediation and report updates; the working tree began clean at `c3cbd31`.
