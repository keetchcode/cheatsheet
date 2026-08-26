# REPO_AUDIT_IOS.md

> Historical snapshot. See `CODE_AUDIT.md` for the current review and remediation status.

Audit date: 2026-07-09

Scope: full repository static architecture and codebase audit for the macOS, iOS, iPadOS, and WidgetKit targets in this repository.

Verification performed:

- `xcodegen generate --spec project.yml` completed successfully.
- `xcodebuild test -project CheatSheet.xcodeproj -scheme CheatSheetiOS -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -derivedDataPath /tmp/CheatSheet-iOS-Audit-DD CODE_SIGNING_ALLOWED=NO` passed: 40 Swift Testing tests in 5 suites.
- `Scripts/verify-macos.sh` passed: macOS arm64 tests, macOS x86_64 tests, and universal Release build. Final binary architectures: `x86_64 arm64`.
- Warning sweep of the iOS and macOS logs found no Swift compiler warnings. The iOS run emitted only xcodebuild's multiple-matching-destination selection warning.

Modernization references checked for July 2026 guidance:

- Apple SwiftUI Liquid Glass docs: https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- Apple WWDC25 "Build a SwiftUI app with the new design": https://developer.apple.com/videos/play/wwdc2025/323/
- Apple SwiftData `ModelActor` docs: https://developer.apple.com/documentation/swiftdata/modelactor

## 1. Executive Summary

CheatSheet is a small, local-first note/checklist app for developers, IT pros, and power users who want short command reminders and checklists available in the app and in a WidgetKit widget. The repo is in strong shape for its size: Swift 6, SwiftUI, SwiftData, WidgetKit, privacy manifests, no network layer, no third-party dependencies, and current iOS/macOS 26 Liquid Glass APIs gated behind availability checks.

The architecture is intentionally compact:

```text
CheatSheetApp App scene
  -> ContentView root navigation
  -> NoteStore (@Observable, @MainActor)
  -> CheatSheetNoteRepository
  -> SwiftData store in App Group
  -> WidgetNoteSnapshotRepository in App Group UserDefaults
  -> WidgetCenter.reloadAllTimelines()
  -> CheatSheetProvider reads widget snapshot
  -> CheatSheetWidgetView renders pinned or fallback note
```

Top findings:

1. **High: SwiftData empty-store semantics resurrect starter notes after all notes are deleted.** `SwiftDataCheatSheetNoteRepository.loadNotes()` returns starter notes whenever SwiftData fetches zero rows, so an intentionally empty store cannot survive relaunch. Evidence: `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:44-49`, `CheatSheetApp/Sources/NoteStore.swift:144-149`.
2. **High: Save/load errors are swallowed without user-visible recovery or durable telemetry.** SwiftData save failures are caught and ignored except for widget snapshot writes, so UI can report success while durable app data did not save. Evidence: `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:50-52`, `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:83-87`.
3. **Medium: Persistence is still custom queue based rather than a SwiftData `ModelActor`.** The current queue is pragmatic, but July 2026 SwiftData concurrency guidance points toward actor-isolated model access. Evidence: `CheatSheetApp/Sources/NoteStore.swift:264-282`.
4. **Medium: No CI workflow or formatter/linter gate exists in the repo.** Local scripts are good, but there is no `.github/workflows`, SwiftFormat, SwiftLint, or generated-project drift gate. Evidence: repo scan found none; build script exists at `Scripts/verify-macos.sh:34-64`.
5. **Medium: Critical user flows have unit coverage but no UI automation.** Swift Testing covers model/store behavior, but onboarding, compact iPhone navigation, split iPad layout, editor focus, and widget setup are not automated. Evidence: `CheatSheetTests/Sources/NoteStoreTests.swift:1-359`, `Docs/AppStoreReadiness.md:120-131`.
6. **Medium: Release archive pre-actions mutate `project.yml` during archive.** This can dirty the repo, make repeated archive attempts consume build numbers, and surprise CI/release operators. Evidence: `project.yml:194-198`, `project.yml:224-230`, `Scripts/increment-build-number.sh:16-44`.
7. **Medium: App Group identifiers are duplicated in project config, entitlements, docs, and source.** This is workable but drift-prone when changing teams or bundle IDs. Evidence: `project.yml:43-44`, `project.yml:105-106`, `Shared/Sources/CheatSheetNote.swift:4-8`, `README.md:88-103`.
8. **Low: Localization infrastructure is absent.** The app is English-only today, with strings embedded directly in views and no `.xcstrings` files. Evidence: `OnboardingView.swift:60-99`, `ContentView.swift:301-318`, no string catalog files found.

## 2. Repo Inventory (iOS-focused)

### Project structure

- XcodeGen project source of truth: `project.yml`.
- Generated project: `CheatSheet.xcodeproj`. README states it is generated and ignored by git: `README.md:38`.
- App code: `CheatSheetApp/Sources`.
- Shared model and persistence code: `Shared/Sources`.
- Widget code: `CheatSheetWidgets/Sources`.
- Tests: `CheatSheetTests/Sources`.
- Docs and release planning: `README.md`, `CONTRIBUTING.md`, `Docs/AppStoreReadiness.md`, `Docs/AppStoreDescription.md`, `audit/REPORT.md`.

### Targets and schemes

`project.yml` defines six targets:

- `CheatSheet`: macOS app, bundle ID `com.wesleykeetch.wesleycheatsheet`, sources from app/shared/resources, embeds `CheatSheetWidgets`. Evidence: `project.yml:18-53`.
- `CheatSheetWidgets`: macOS WidgetKit extension, bundle ID `com.wesleykeetch.wesleycheatsheet.widgets`. Evidence: `project.yml:53-83`.
- `CheatSheetiOS`: iOS/iPadOS app, bundle ID `com.wesleykeetch.wesleycheatsheet`, device family `1,2`, embeds `CheatSheetiOSWidgets`. Evidence: `project.yml:124-169`.
- `CheatSheetiOSWidgets`: iOS WidgetKit extension, same widget bundle ID, iOS App Group entitlement. Evidence: `project.yml:84-113`.
- `CheatSheetTests`: macOS unit-test bundle. Evidence: `project.yml:114-123`.
- `CheatSheetiOSTests`: iOS unit-test bundle. Evidence: `project.yml:170-179`.

Schemes:

- `CheatSheet`: app + widget + macOS tests.
- `CheatSheetApp`: app + widget for run/archive.
- `CheatSheetiOS`: iOS app + widget + iOS tests.

Evidence: `project.yml:180-230`, `xcodebuild -list -project CheatSheet.xcodeproj`.

### Build settings

- Swift language mode: `SWIFT_VERSION: "6.0"` at `project.yml:9-10`.
- Deployment targets: macOS 15.0 and iOS 18.0 at `project.yml:4-6`.
- Current local toolchain: Xcode 26.6, Apple Swift 6.3.3, iOS Simulator SDK 26.5, macOS SDK 26.5.
- Version: marketing `1.1`, build `11` at `project.yml:14-15`.
- Code signing: automatic, team `HD39MR492X`. Evidence: `project.yml:51-52`, `project.yml:112-113`, `project.yml:167-168`.

### Dependencies

- No Swift Package Manager, CocoaPods, Carthage, or third-party packages were found.
- The app depends only on Apple frameworks: SwiftUI, Observation, SwiftData, WidgetKit, OSLog, Foundation, AppKit on macOS.

### Platform approach

- SwiftUI-only app shell; no UIKit lifecycle or AppDelegate/SceneDelegate.
- macOS adds `Settings` and `MenuBarExtra`. Evidence: `CheatSheetApp/Sources/CheatSheetApp.swift:23-30`.
- iOS/iPadOS uses the same `ContentView`, with compact navigation controlled by horizontal size class. Evidence: `CheatSheetApp/Sources/ContentView.swift:45-92`.
- WidgetKit extension uses `StaticConfiguration`. Evidence: `CheatSheetWidgets/Sources/CheatSheetWidget.swift:4-14`.

### Capabilities and privacy

- macOS app/widget: App Sandbox plus macOS App Group `HD39MR492X.com.wesleykeetch.wesleycheatsheet`. Evidence: `project.yml:39-44`, `project.yml:71-76`.
- iOS app/widget: App Group `group.com.wesleykeetch.wesleycheatsheet`. Evidence: `project.yml:156-160`, `project.yml:102-106`.
- Privacy manifests exist for app and widget and declare UserDefaults required-reason API `CA92.1`; no collected data or tracking. Evidence: `CheatSheetApp/Resources/PrivacyInfo.xcprivacy`, `CheatSheetWidgets/Resources/PrivacyInfo.xcprivacy`.
- No network, analytics, crash reporting, ads, payments, push notifications, background tasks, Keychain, Siri intents, CloudKit, or URL schemes were found.

## 3. Architecture & Data Flow

### Component diagram

```text
App entrypoint
  CheatSheetApp.swift
    owns @State NoteStore
    macOS: WindowGroup + Settings + MenuBarExtra
    iOS: WindowGroup

UI layer
  ContentView
    split layout: NavigationSplitView
    compact iOS: NavigationStack(path: [Note.ID])
    toolbar: create, trash, archive
  SidebarView / SidebarNoteRow
    list, search, selection
  EditorView / EditorTextPanel / EditorHeader
    title/body editing, color/font, widget pin
  TrashNoteView
    restore and permanent delete
  MenuBarQuickAccessView
    macOS quick capture and recent notes
  OnboardingView
    first-run guidance

State/domain layer
  NoteStore (@Observable @MainActor)
    notes, active/archived caches, selectedNoteID, searchText
    add/archive/restore/delete/pin
    debounce saves and flushes on scene inactivity

Data layer
  CheatSheetNoteRepository protocol
    SwiftDataCheatSheetNoteRepository
      PersistedCheatSheetNote @Model
      App Group SwiftData store
      legacy UserDefaults migration fallback
    UserDefaultsCheatSheetNoteRepository
      legacy full-note JSON fallback
    WidgetNoteSnapshotRepository
      single widget note snapshot in App Group UserDefaults

Widget layer
  CheatSheetProvider
    reads WidgetNoteSnapshotRepository.appGroup()
    emits timeline every 30 minutes
  CheatSheetWidgetView
    renders title, parsed checklist lines, tint/font
```

### Responsibilities

- `CheatSheetApp`: scene ownership and shared `NoteStore` lifetime. Evidence: `CheatSheetApp/Sources/CheatSheetApp.swift:3-36`.
- `ContentView`: root navigation, toolbar commands, onboarding sheet, trash routing, compact path routing, scene-phase flush. Evidence: `CheatSheetApp/Sources/ContentView.swift:16-43`, `ContentView.swift:58-92`, `ContentView.swift:161-179`.
- `NoteStore`: central mutation boundary and cache owner. Evidence: `CheatSheetApp/Sources/NoteStore.swift:6-37`, `NoteStore.swift:100-181`.
- `SwiftDataCheatSheetNoteRepository`: durable persistence, legacy migration, widget snapshot update. Evidence: `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:37-88`.
- `WidgetNoteSnapshotRepository`: minimal widget read path independent of SwiftData. Evidence: `Shared/Sources/CheatSheetNoteRepository.swift:67-96`.
- `CheatSheetProvider`: widget timeline and snapshot generation. Evidence: `CheatSheetWidgets/Sources/CheatSheetProvider.swift:6-26`.

### Data flow

```text
User edits TextField/TextEditor
  -> Binding from NoteStore.binding(for:)
  -> NoteStore.notes[index] update
  -> notes didSet rebuilds active/archived caches
  -> schedulePersist() debounces 400 ms
  -> NotePersistenceWorker.save()
  -> SwiftDataCheatSheetNoteRepository.saveNotes()
  -> ModelContext upsert/delete/save
  -> WidgetNoteSnapshotRepository.saveNote(widgetDisplayNote)
  -> WidgetCenter.reloadAllTimelines() only if widget note changed
  -> CheatSheetProvider reads snapshot next timeline
```

Evidence: `NoteStore.swift:86-97`, `NoteStore.swift:184-208`, `SwiftDataCheatSheetNoteRepository.swift:55-88`, `CheatSheetProvider.swift:22-25`.

## 4. What the App Does (User Workflows)

### Primary workflows

1. **Create and edit a local cheat-sheet note**
   - Trigger: toolbar "New Note" or menu bar "New Note".
   - UI: `ContentView.createNote()` or `MenuBarQuickAccessView`.
   - State: `NoteStore.addNote()` inserts at top, selects it, and persists immediately.
   - Persistence: SwiftData store and widget snapshot update.
   - Evidence: `ContentView.swift:161-165`, `MenuBarQuickAccessView.swift:41-52`, `NoteStore.swift:100-115`.

2. **Edit note title/body/style**
   - Trigger: title `TextField`, body `TextEditor`, color swatches, font menu.
   - UI: `EditorHeader`, `EditorTextPanel`, `GlassPalettePicker`, `FontStylePicker`.
   - State: binding updates note by ID and updates `updatedAt`.
   - Persistence: debounced 400 ms save, flushed when scene leaves active.
   - Evidence: `EditorHeader.swift:9-51`, `EditorTextPanel.swift:11-19`, `GlassPalettePicker.swift:29-37`, `NoteStore.swift:86-97`, `ContentView.swift:33-35`.

3. **Pin a note for the widget**
   - Trigger: "Use in Widget" button or widget hint pin action.
   - UI: `EditorHeader` and `WidgetSetupHintView`.
   - State: `NoteStore.setPinned()` clears all other pins and pins only the selected active note.
   - Persistence/side effect: immediate save and timeline reload if widget note changes.
   - Evidence: `EditorHeader.swift:43-50`, `ContentView.swift:146-156`, `NoteStore.swift:167-176`, `NoteStore.swift:211-217`.

4. **Search notes and trash**
   - Trigger: `.searchable` in sidebar or compact note list.
   - UI: `SidebarView` for split layout, `CompactNoteListView` for compact iOS.
   - State: `store.searchText`.
   - Data: filters cached active or archived arrays by title/body.
   - Evidence: `SidebarView.swift:33-38`, `ContentView.swift:347-351`, `NoteStore.swift:61-79`.

5. **Trash, restore, and permanently delete notes**
   - Trigger: toolbar archive, Trash route, restore/delete buttons.
   - State: archive sets `archivedAt`, clears pin; restore clears `archivedAt`; permanent delete removes archived note.
   - Persistence: immediate save.
   - Evidence: `ContentView.swift:23-30`, `TrashNoteView.swift:60-78`, `NoteStore.swift:121-149`.

6. **Onboarding**
   - Trigger: first launch when `hasCompletedOnboarding` is false.
   - UI: platform-specific `OnboardingView`.
   - State: `@AppStorage("hasCompletedOnboarding")`.
   - Evidence: `ContentView.swift:37-42`, `OnboardingView.swift:3-37`, `OnboardingView.swift:129-132`.

7. **Widget rendering**
   - Trigger: WidgetKit placeholder/snapshot/timeline, app-side timeline reload.
   - Data: `WidgetNoteSnapshotRepository` from App Group UserDefaults.
   - UI: `CheatSheetWidgetView` parses and renders note display lines.
   - Evidence: `CheatSheetProvider.swift:7-26`, `CheatSheetWidgetView.swift:10-42`, `WidgetLineView.swift:9-26`.

## 5. Who It's For (Roles/Personas inferred)

- **Developers:** README and App Store docs describe coding commands, Git flow, Swift, terminal reminders, and command checklists. Evidence: `README.md:3`, `Docs/AppStoreDescription.md:13-37`.
- **IT pros and power users:** App Store description explicitly includes IT pros and power users. Evidence: `Docs/AppStoreDescription.md:35-37`.
- **Local-first privacy-conscious users:** README and release docs emphasize no accounts, analytics, network, ads, or tracking. Evidence: `README.md:112-115`, `Docs/AppStoreReadiness.md:7-9`.
- **Widget-focused users:** core value is pinning one note to WidgetKit. Evidence: `README.md:21-26`, `CheatSheetWidget.swift:11-13`.

No role or permission separation exists in code; all users are local device users.

## 6. Module & Function Catalog

| Module / Symbol | Role | Inputs / Outputs | Reads / Writes | Called from |
|---|---|---|---|---|
| `CheatSheetApp` | Scene root and shared store owner | `@AppStorage showMenuBarQuickAccess`, `@State NoteStore` | Per-app preferences | System app launch |
| `ContentView` | Root app UI, navigation, toolbar, onboarding | `NoteStore`, scene phase, size class | `hasCompletedOnboarding`, `showWidgetHints` | `CheatSheetApp` |
| `NoteStore` | Main state and mutation boundary | Repository, widget reload closure, clock | Notes, selection, search, cached lists | UI bindings and commands |
| `NotePersistenceWorker` | Serial background save wrapper | `[CheatSheetNote]`, wait flag | Repository saves | `NoteStore.persist()` |
| `CheatSheetNoteRepositoryFactory.live()` | Live repository creation | App Group availability | SwiftData, UserDefaults fallback | `NoteStore` default init |
| `SwiftDataCheatSheetNoteRepository` | Main durable persistence | `[CheatSheetNote]` | SwiftData store file in App Group; widget snapshot | Repository factory, tests |
| `PersistedCheatSheetNote` | SwiftData model | scalar note fields and sort index | SwiftData row | SwiftData repository |
| `UserDefaultsCheatSheetNoteRepository` | Legacy/fallback JSON store | `[CheatSheetNote]` | App Group UserDefaults key `cheatSheet.notes` | Repository factory, migration |
| `WidgetNoteSnapshotRepository` | Widget snapshot persistence | `CheatSheetNote?` | App Group UserDefaults key `cheatSheet.widgetNote` | SwiftData repository, widget provider |
| `CheatSheetProvider` | WidgetKit timeline provider | Widget timeline context | Widget snapshot | WidgetKit |
| `CheatSheetWidgetView` | Widget rendering | Timeline entry | None | `CheatSheetWidget` |
| `DisplayLine` and parsing extensions | Parse note bodies into display rows | Note body string, line limit | None | app preview and widget |
| `EditorHeader` | Title, status, color/font/pin controls | `Binding<CheatSheetNote>` | Note title/style/pin through binding | `EditorTextPanel` |
| `TrashNoteView` | Restore/delete UI | archived note, action closures | State flag for confirmation | `ContentView` |
| `MenuBarQuickAccessView` | macOS quick capture | Store and open-window closure | quick capture state; notes via store | `MenuBarExtra` |
| `Scripts/verify-macos.sh` | macOS test/build verification | local repo | temp generated project and DerivedData | developer/release workflow |
| `Scripts/increment-build-number.sh` | Archive build number bump | `project.yml` | mutates `CURRENT_PROJECT_VERSION` | archive pre-actions |

## 7. Critical Path Walkthroughs (top 3 workflows)

### 7.1 Create, edit, and persist a note

1. User taps toolbar New Note in split or compact UI. `ContentToolbar` calls `createAction`, which maps to `ContentView.createNote()`. Evidence: `ContentView.swift:190-247`, `ContentView.swift:161-165`.
2. `createNote()` exits trash mode, calls `store.addNote()`, then sets compact navigation path to the new note ID on iOS. Evidence: `ContentView.swift:161-165`.
3. `NoteStore.addNote()` creates a `CheatSheetNote`, inserts it at index 0, selects it, and calls `persistImmediately()`. Evidence: `NoteStore.swift:100-115`.
4. `notes.didSet` rebuilds active and archived caches. Evidence: `NoteStore.swift:9-13`, `NoteStore.swift:233-238`.
5. The editor gets a binding from `NoteStore.binding(for:)`; setting it updates by stable note ID and refreshes `updatedAt`. Evidence: `NoteStore.swift:86-97`.
6. Edits schedule a 400 ms `Task.sleep` debounce on `MainActor`, then persist. Evidence: `NoteStore.swift:184-195`.
7. `NotePersistenceWorker` serializes save work on a utility `DispatchQueue`. Evidence: `NoteStore.swift:264-282`.
8. `SwiftDataCheatSheetNoteRepository.saveNotes()` upserts, deletes removed notes, saves the context, and writes the widget snapshot. Evidence: `SwiftDataCheatSheetNoteRepository.swift:55-88`.
9. `ContentView` flushes pending changes when the scene is no longer active. Evidence: `ContentView.swift:33-35`, `NoteStore.swift:178-182`.

Concurrency boundary: UI mutation is `@MainActor`; persistence crosses to a custom serial `DispatchQueue`; SwiftData contexts are created per load/save call.

### 7.2 Pin a note and update the widget

1. User taps the pin button in `EditorHeader`, or the widget setup hint button. Evidence: `EditorHeader.swift:43-50`, `ContentView.swift:181-187`.
2. `NoteStore.setPinned(_:)` maps over all notes, setting exactly one active note to `isPinned = true` and clearing all others. Evidence: `NoteStore.swift:167-176`.
3. `persistImmediately()` cancels pending debounced saves and saves current state. Evidence: `NoteStore.swift:198-202`.
4. `reloadWidgetTimelinesIfNeeded(for:)` compares the current widget display note to `lastReloadedWidgetNote`. Evidence: `NoteStore.swift:211-217`.
5. If the widget note changed, the default reload closure calls `WidgetCenter.shared.reloadAllTimelines()`. Evidence: `NoteStore.swift:39-42`.
6. SwiftData save writes `notes.widgetDisplayNote` to `WidgetNoteSnapshotRepository`. Evidence: `SwiftDataCheatSheetNoteRepository.swift:83-87`, `CheatSheetNoteRepository.swift:88-96`.
7. Widget timeline provider loads the snapshot and returns a timeline entry. Evidence: `CheatSheetProvider.swift:16-25`.
8. `CheatSheetWidgetView` displays title and bounded display lines according to widget family. Evidence: `CheatSheetWidgetView.swift:19-31`, `WidgetFamily+CheatSheetLayout.swift:13-19`.

Caching behavior: app caches only active/archived lists; widget caches only one selected note snapshot in UserDefaults.

### 7.3 Archive, restore, and permanently delete notes

1. User taps "Move to Trash" in the toolbar. Evidence: `ContentView.swift:215-220`, `ContentView.swift:231-237`.
2. `NoteStore.archiveSelectedNote()` delegates to `archiveNote(_:)`, setting `archivedAt`, clearing `isPinned`, updating selection, and saving immediately. Evidence: `NoteStore.swift:121-134`.
3. Trash mode uses `store.enterTrash()` to select the most recently archived note, sets `isShowingTrash`, and clears compact navigation. Evidence: `ContentView.swift:167-172`, `NoteStore.swift:151-154`.
4. `TrashNoteView` displays restore and permanent delete actions with a confirmation dialog. Evidence: `TrashNoteView.swift:60-78`.
5. Restore clears `archivedAt`, updates selection, and saves. Evidence: `NoteStore.swift:136-142`.
6. Permanent delete removes archived notes matching the ID and saves. Evidence: `NoteStore.swift:144-149`.
7. Expired archived notes are purged on init and before every persist using a 30-day interval. Evidence: `NoteStore.swift:49-58`, `NoteStore.swift:240-260`, `CheatSheetNote+Trash.swift:29-32`.

Correctness risk: if permanent deletion leaves the SwiftData store empty, next launch currently returns starter notes because `loadNotes()` treats an empty SwiftData fetch as first launch. Evidence: `SwiftDataCheatSheetNoteRepository.swift:44-49`.

## 8. Data Model & Persistence

### Domain model

`CheatSheetNote` is a `Codable`, `Identifiable`, `Equatable`, `Sendable` value type with:

- `id: UUID`
- `title: String`
- `body: String`
- `tintHex: String`
- `fontStyleRawValue: String?`
- `isPinned: Bool`
- `updatedAt: Date`
- `archivedAt: Date?`

Evidence: `Shared/Sources/CheatSheetNote.swift:10-62`.

Computed behavior:

- `displayTitle` trims and falls back to "Untitled Note". Evidence: `CheatSheetNote.swift:40-43`.
- `fontStyle` falls back to monospaced when raw value is absent or unknown. Evidence: `CheatSheetNote.swift:45-57`.
- `isArchived` is derived from `archivedAt != nil`. Evidence: `CheatSheetNote.swift:59-61`.
- `widgetDisplayNote` selects the first pinned active note or first active note. Evidence: `CheatSheetNote.swift:97-100`.

### SwiftData model

`PersistedCheatSheetNote` is a SwiftData `@Model` with scalar note fields plus `sortIndex`. `id` is marked unique. Evidence: `Shared/Sources/PersistedCheatSheetNote.swift:4-16`.

Persistence behavior:

- `loadNotes()` fetches all persisted notes sorted by `sortIndex`.
- If SwiftData has no notes and legacy notes exist, it migrates legacy notes into SwiftData.
- If SwiftData has no notes and no legacy notes, it returns starter notes.
- If fetch fails, it returns legacy notes or starter notes.

Evidence: `SwiftDataCheatSheetNoteRepository.swift:37-52`.

Save behavior:

- Deduplicates incoming notes by preserving the last occurrence for an ID.
- Upserts notes by ID, deletes removed notes and duplicate persisted rows, then saves.
- Writes the widget snapshot after save, and also in the catch path.

Evidence: `SwiftDataCheatSheetNoteRepository.swift:55-99`.

### Legacy and widget stores

- Legacy full-note JSON store: App Group UserDefaults key `cheatSheet.notes`. Evidence: `CheatSheetNoteRepository.swift:22-54`.
- Widget snapshot store: App Group UserDefaults key `cheatSheet.widgetNote`. Evidence: `CheatSheetNoteRepository.swift:67-96`.

### Migration strategy

Current migration is opportunistic, one-way, and implicit:

1. Try SwiftData.
2. If SwiftData is empty, load legacy UserDefaults.
3. Save legacy notes into SwiftData.
4. There is no explicit migrated marker, no cleanup of legacy full-note data in this code, and no schema versioning beyond SwiftData defaults.

This is acceptable for a v1 local app, but the empty-store bug means the migration path needs a "has initialized store" marker or a separate first-launch seed path.

## 9. Concurrency, Performance, and Security Controls

### Concurrency

Strengths:

- `NoteStore` is explicitly `@Observable @MainActor`. Evidence: `NoteStore.swift:6-8`.
- UI binds to state through stable note IDs, avoiding stale array index writes. Evidence: `NoteStore.swift:86-97`.
- Debounced saves use `Task.sleep(for:)` and cancellation. Evidence: `NoteStore.swift:184-195`.

Risks:

- `NotePersistenceWorker` is `@unchecked Sendable` and uses `DispatchQueue` instead of a SwiftData `ModelActor`. Evidence: `NoteStore.swift:264-282`.
- `flushPendingChanges()` can synchronously block on the persistence queue from `MainActor`. Evidence: `NoteStore.swift:178-182`, `NoteStore.swift:272-276`.
- `NoteStore.init` loads notes synchronously on the main actor. Evidence: `NoteStore.swift:49-58`.

Modernization angle: for July 2026 SwiftData code, prefer a `ModelActor` or other actor-isolated repository facade for all `ModelContext` work. Keep `NoteStore` as a main-actor view model that consumes immutable values from the actor.

### Performance

Strengths:

- Active and archived note lists are cached when `notes` changes. Evidence: `NoteStore.swift:15-16`, `NoteStore.swift:233-238`.
- Widget and preview line parsing is bounded by `displayLines(limit:)`. Evidence: `DisplayLine.swift:16-37`, `CheatSheetWidgetView.swift:28-31`, `StickyNotePreview.swift:21-30`.
- Widget timeline reloads are conditional on widget note changes. Evidence: `NoteStore.swift:211-217`.

Risks:

- Initial load and first cache build are synchronous. This is fine for small notes, but profile 500+ notes as release docs already recommend. Evidence: `Docs/AppStoreReadiness.md:147-154`.
- Widget timeline reload on store init is unconditional. Evidence: `NoteStore.swift:53-54`.
- No performance tests currently seed large note sets or measure edit/search responsiveness.

### Security and privacy

Strengths:

- No network stack, no auth tokens, no API endpoints, no Keychain, no analytics, no ads, no payments, and no crash reporting SDKs were found.
- App privacy manifests declare no collected data and no tracking.
- Widget logs mark note titles private. Evidence: `CheatSheetProvider.swift:18`, `CheatSheetProvider.swift:24`.
- App Group access fails closed in `CheatSheetAppGroup.defaults()` by throwing when the suite is unavailable. Evidence: `CheatSheetNoteRepository.swift:12-19`.

Risks:

- Save/load failures are swallowed rather than surfaced, which can hide data durability problems.
- Mac Release settings do not explicitly set `ENABLE_HARDENED_RUNTIME: YES` in `project.yml`; release docs already recommend adding it. Evidence: no setting in `project.yml`, recommendation at `Docs/AppStoreReadiness.md:44-45`.
- Archive-time build number mutation is a process risk, not a runtime security issue.

## 10. Observability, Logging, and Error Handling

Current observability:

- Widget provider uses `OSLog.Logger` with private note title interpolation. Evidence: `CheatSheetProvider.swift:1-4`, `CheatSheetProvider.swift:18-24`.
- No app-side logger exists for persistence failures, migration fallback, App Group failures, or data corruption recovery.
- No crash reporting or analytics SDK exists, consistent with privacy posture.

Error handling strengths:

- Repository factory falls back from SwiftData to legacy UserDefaults, then to unavailable starter notes. Evidence: `SwiftDataCheatSheetNoteRepository.swift:4-19`.
- Invalid legacy JSON returns starter notes rather than crashing. Evidence: `CheatSheetNoteRepository.swift:43-48`.

Error handling gaps:

- SwiftData fetch and save errors are swallowed. Evidence: `SwiftDataCheatSheetNoteRepository.swift:50-52`, `SwiftDataCheatSheetNoteRepository.swift:83-87`.
- `UnavailableCheatSheetNoteRepository.saveNotes(_:)` silently discards data. Evidence: `CheatSheetNoteRepository.swift:57-65`.
- UI has no banner/sheet/state for storage unavailable, migration failed, or last save failed.

Recommendation: add a small `PersistenceStatus` on `NoteStore` and a privacy-safe `Logger` category for storage. Preserve the no-analytics stance while making local failures visible and testable.

## 11. Build/Run/Deploy & Configuration

### Build and local verification

- XcodeGen is required. Evidence: `README.md:40-49`.
- `Scripts/verify-macos.sh` generates a temporary project outside File Provider, runs arm64 tests, runs x86_64 tests, builds universal Release, and prints `lipo` info. Evidence: `Scripts/verify-macos.sh:16-69`.
- README documents iOS/iPadOS test/build commands. Evidence: `README.md:78-84`.

### Versioning

- `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` live in `project.yml`. Evidence: `project.yml:14-15`.
- Info.plists consume build settings for version and bundle ID. Evidence: `project.yml:24-29`, `project.yml:130-132`.
- Archive pre-actions run `Scripts/increment-build-number.sh`. Evidence: `project.yml:194-198`, `project.yml:224-230`.

Risk: archive pre-actions mutate `project.yml` and regenerate the project. This is convenient locally but can dirty a release checkout and consume build numbers on failed archive attempts. Prefer an explicit pre-release build-number command, or gate the script so archives require an intentional environment variable in CI.

### Entitlements and bundle IDs

- App IDs: `com.wesleykeetch.wesleycheatsheet`, widget `com.wesleykeetch.wesleycheatsheet.widgets`.
- App Groups:
  - macOS: `HD39MR492X.com.wesleykeetch.wesleycheatsheet`
  - iOS/iPadOS: `group.com.wesleykeetch.wesleycheatsheet`
- Entitlements parse and match target settings.

Evidence: `project.yml:39-44`, `project.yml:71-76`, `project.yml:102-106`, `project.yml:156-160`.

### CI and quality gates

No CI workflow, SwiftFormat config, SwiftLint config, or package/dependency resolution config was found.

Recommended CI gates:

1. Install/pin XcodeGen.
2. Run `xcodegen generate --spec project.yml`.
3. Run `plutil -lint` on plist, entitlement, and privacy files.
4. Run iOS tests on a stable simulator.
5. Run `Scripts/verify-macos.sh` on release branches or nightly.
6. Run `git diff --check`.
7. Fail if generated project drift appears when the project is intentionally tracked, or keep it ignored and treat `project.yml` as authoritative.

## 12. Tests & Quality Signals

Existing tests:

- `DisplayLineTests`: checklist/heading parsing and bounded display lines. Evidence: `DisplayLineTests.swift:3-79`.
- `CheatSheetNoteTrashTests`: trash date text. Evidence: `CheatSheetNoteTrashTests.swift:4-20`.
- `WidgetNoteSelectionTests`: widget note selection rules. Evidence: `WidgetNoteSelectionTests.swift:4-53`.
- `NoteRepositoryTests`: UserDefaults repository, SwiftData save/load, migration, widget snapshot, deduplication. Evidence: `NoteRepositoryTests.swift:5-219`.
- `NoteStoreTests`: note creation, selection, archiving, restore, delete, pinning, binding stability, expiration, flush/reload behavior. Evidence: `NoteStoreTests.swift:4-359`.

Verified quality signals on 2026-07-09:

- iOS tests: 40 tests in 5 suites passed.
- macOS arm64 tests: 40 tests in 5 suites passed.
- macOS x86_64 tests: 40 tests in 5 suites passed.
- macOS universal Release build succeeded.
- No Swift compiler warnings were found in captured logs.

Gaps:

- No UI test target.
- No widget runtime automation.
- No corruption/recovery test for SwiftData save failure or fetch failure.
- No test for intentionally empty SwiftData store after final permanent delete.
- No large data performance test for 500+ notes.
- No release archive validation test for signed entitlements or App Store export.
- No accessibility automation or snapshot testing.

## 13. Issues & Risks (Prioritized)

### 13.1 Empty SwiftData store resurrects starter notes

- **Problem:** `loadNotes()` returns `CheatSheetNote.starterNotes` whenever SwiftData fetches zero notes. If a user archives and permanently deletes everything, relaunch can seed starter content again.
- **Evidence:** `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift:44-49`, `CheatSheetApp/Sources/NoteStore.swift:144-149`.
- **Impact:** Correctness and UX. Users cannot maintain a truly empty store.
- **Recommended fix:** Add an explicit first-launch or migration-complete marker in App Group defaults, or seed starter notes only before the SwiftData store has ever been initialized. Add a SwiftData repository test for saved empty collection returning empty.
- **Effort:** S.
- **July 2026 modernization angle:** Keep SwiftData as the durable store, but make seed/migration state explicit and testable.

### 13.2 Persistence errors are hidden from UI and logs

- **Problem:** Fetch/save failures fall back or continue silently.
- **Evidence:** `SwiftDataCheatSheetNoteRepository.swift:50-52`, `SwiftDataCheatSheetNoteRepository.swift:83-87`, `CheatSheetNoteRepository.swift:57-65`.
- **Impact:** Reliability and data durability. Users can lose changes without knowing the store failed.
- **Recommended fix:** Return typed persistence results or throw from repository methods; store a `PersistenceStatus` in `NoteStore`; log privacy-safe errors; show a recoverable storage warning when needed.
- **Effort:** M.
- **July 2026 modernization angle:** Actor-isolated repositories should expose structured async throws instead of side-effect-only save methods.

### 13.3 Persistence should move from custom queue to SwiftData actor isolation

- **Problem:** `NotePersistenceWorker` uses `@unchecked Sendable` and a `DispatchQueue`.
- **Evidence:** `CheatSheetApp/Sources/NoteStore.swift:264-282`.
- **Impact:** Maintainability and future Swift concurrency correctness.
- **Recommended fix:** Introduce a `ModelActor`-backed persistence service that owns `ModelContext`; keep `NoteStore` main-actor only; return value snapshots to UI.
- **Effort:** M.
- **July 2026 modernization angle:** Apple documents `ModelActor` as the SwiftData concurrency primitive for actor-isolated model access.

### 13.4 No UI automation for primary workflows

- **Problem:** Unit coverage is solid, but app navigation and editing flows are not exercised by UI tests.
- **Evidence:** test files under `CheatSheetTests/Sources`; UI automation plan exists but is not implemented at `Docs/AppStoreReadiness.md:120-131`.
- **Impact:** Regression risk for iPhone compact navigation, iPad split layout, onboarding, editor focus, trash, and accessibility.
- **Recommended fix:** Add `CheatSheetUITests` and `CheatSheetiOSUITests` targets with isolated temporary store launch arguments. Automate create/edit/search/pin/trash/restore/onboarding.
- **Effort:** M.
- **July 2026 modernization angle:** Use Xcode UI testing with deterministic launch configuration; keep Widget gallery installation manual but cover app-side widget selection.

### 13.5 No CI or static quality gates

- **Problem:** Verification depends on local manual commands.
- **Evidence:** no `.github/workflows`, `.swift-format`, `.swiftlint.yml`, `Package.swift`, `Podfile`, or `Cartfile` found; local script at `Scripts/verify-macos.sh`.
- **Impact:** Merge/release risk.
- **Recommended fix:** Add a GitHub Actions workflow or equivalent local CI script to run XcodeGen, plist lint, iOS tests, macOS verification, and whitespace checks.
- **Effort:** M.
- **July 2026 modernization angle:** Pin stable Xcode/XcodeGen versions; run Xcode 26.x stable as release baseline and keep Xcode 27 beta only for forward compatibility until accepted by App Store Connect.

### 13.6 Archive pre-action mutates `project.yml`

- **Problem:** Archives increment `CURRENT_PROJECT_VERSION` by editing `project.yml` during the archive action.
- **Evidence:** `project.yml:194-198`, `project.yml:224-230`, `Scripts/increment-build-number.sh:16-44`.
- **Impact:** Release process drift, dirty worktrees, accidental build-number consumption.
- **Recommended fix:** Move build bump to an explicit release command before archive, or require a `CHEATSHEET_ALLOW_ARCHIVE_BUILD_BUMP=1` style gate. Record the bump in source control before upload.
- **Effort:** S.
- **July 2026 modernization angle:** Prefer reproducible archives with source-controlled version numbers and separately auditable release automation.

### 13.7 App Group IDs are duplicated across config, source, and docs

- **Problem:** App Group strings exist in `project.yml`, entitlements, source, README, and release docs.
- **Evidence:** `project.yml:43-44`, `project.yml:105-106`, `Shared/Sources/CheatSheetNote.swift:4-8`, `README.md:88-103`.
- **Impact:** Signing/widget breakage when team or bundle IDs change.
- **Recommended fix:** Generate an app-group constants file from `project.yml` or load the group from Info.plist build settings so source does not own the same constant separately.
- **Effort:** M.
- **July 2026 modernization angle:** Keep XcodeGen as the single configuration source and generate code/config from it.

### 13.8 Mac Release settings omit explicit Hardened Runtime

- **Problem:** `ENABLE_HARDENED_RUNTIME` is not set in `project.yml`, while release docs call it out as a required hardening step.
- **Evidence:** no setting in `project.yml`; recommendation at `Docs/AppStoreReadiness.md:44-45`.
- **Impact:** Distribution-mode drift and weaker defense-in-depth for notarized/non-store distribution.
- **Recommended fix:** Add Release-only `ENABLE_HARDENED_RUNTIME: YES` for macOS app and widget targets, regenerate, archive, and inspect entitlements.
- **Effort:** S.
- **July 2026 modernization angle:** Treat signed artifact inspection as part of release readiness, not only simulator build success.

### 13.9 No localization infrastructure

- **Problem:** User-facing strings are embedded in Swift files and docs; no `.xcstrings` files were found.
- **Evidence:** `OnboardingView.swift:60-99`, `ContentView.swift:301-318`, no string catalog files found.
- **Impact:** Internationalization, accessibility testing with non-US locales, and App Store localization readiness.
- **Recommended fix:** If localization is a product goal, introduce String Catalogs for app/widget strings. If not, document English-only support.
- **Effort:** M.
- **July 2026 modernization angle:** Use Xcode String Catalogs and generated symbols where appropriate.

### 13.10 No deep links, App Intents, Shortcuts, or Spotlight integration

- **Problem:** The app has no system surfaces beyond widgets and menu bar.
- **Evidence:** build logs extracted no App Intents symbols; no App Intent files found; `CheatSheetApp.swift` defines only scenes.
- **Impact:** Discoverability and automation missed opportunity, not a bug.
- **Recommended fix:** Consider App Intents for create note, open pinned note, search notes, and pin note actions.
- **Effort:** M.
- **July 2026 modernization angle:** App Intents are the system path for Shortcuts, Spotlight, Siri, controls, and other Apple surfaces.

### 13.11 Widget fallback always shows starter note when no snapshot exists

- **Problem:** `CheatSheetProvider` falls back to `CheatSheetNote.starterNotes[0]` for snapshot/timeline when no widget snapshot exists.
- **Evidence:** `CheatSheetProvider.swift:22-25`.
- **Impact:** UX ambiguity. Widget may look populated before the user has pinned or created a note.
- **Recommended fix:** Distinguish placeholder/gallery content from runtime no-note state. Return a runtime entry that says "Open CheatSheet to choose a widget note."
- **Effort:** S.
- **July 2026 modernization angle:** Use WidgetKit placeholder only for gallery previews; runtime timelines should reflect actual data state.

### 13.12 Corrupted color strings render as black without recovery

- **Problem:** `Color(hex:)` ignores scanner failure and derives RGB from zero.
- **Evidence:** `Shared/Sources/CheatSheetNote.swift:164-174`.
- **Impact:** Low correctness issue if persisted `tintHex` is corrupt or manually edited.
- **Recommended fix:** Validate `tintHex` against `CheatSheetPalette`; fall back to palette blue and repair on save.
- **Effort:** S.
- **July 2026 modernization angle:** Keep persisted user preference values normalized through small value types or failable initializers.

### 13.13 No performance fixture for large note counts

- **Problem:** Release docs call for 500-note profiling, but tests do not seed/measure large collections.
- **Evidence:** `Docs/AppStoreReadiness.md:79-84`, no performance tests found.
- **Impact:** Scaling regressions may appear late.
- **Recommended fix:** Add a deterministic large-note test for filter/sort/parser behavior and a manual Instruments checklist artifact for release.
- **Effort:** S/M.
- **July 2026 modernization angle:** Use focused XCTest/Swift Testing performance checks for pure model work and Instruments for UI hangs.

### 13.14 Storage and widget state are coupled through a snapshot side effect

- **Problem:** Saving app data also writes the widget snapshot, including in the SwiftData save error path.
- **Evidence:** `SwiftDataCheatSheetNoteRepository.swift:83-87`.
- **Impact:** Widget can show state that failed to persist in the main store.
- **Recommended fix:** Make app save and widget snapshot save explicit steps with result reporting. Only publish widget snapshot after durable app save succeeds, unless intentionally operating in degraded mode.
- **Effort:** M.
- **July 2026 modernization angle:** Prefer explicit effect orchestration over hidden side effects in repository methods.

### 13.15 No signed archive/export evidence in this audit

- **Problem:** Simulator tests and unsigned Release builds passed, but this audit did not create a signed archive, inspect provisioning profiles, or export an `.ipa`/Mac App Store package.
- **Evidence:** verification commands used `CODE_SIGNING_ALLOWED=NO`.
- **Impact:** App Store readiness remains partly external.
- **Recommended fix:** Run the signed archive/export checks from `Docs/AppStoreReadiness.md:164-189` on the release Mac before submission.
- **Effort:** M.
- **July 2026 modernization angle:** Treat signed artifact inspection as a separate gate from source build/test success.

## 14. Improvement Plan (Next steps)

### Do first: safety and maintainability

1. Fix empty SwiftData store semantics and add regression tests.
2. Add structured persistence error propagation, privacy-safe logging, and UI storage status.
3. Move build-number increments out of archive pre-actions or gate them explicitly.
4. Add Release-only Hardened Runtime settings for macOS targets and verify signed artifacts.
5. Centralize App Group identifiers through generated config or Info.plist/build settings.

### Architecture and performance

1. Refactor persistence behind a `ModelActor` and async repository API.
2. Split `ContentView` into `RootNavigationView`, `NoteDetailView`, `TrashCoordinatorView`, and compact/split shells if it grows beyond current scope.
3. Add large-note performance fixtures for filtering, parsing, and save/load.
4. Make widget snapshot publication an explicit effect after durable save success.
5. Add runtime no-note widget state distinct from placeholder starter content.

### Tests and quality

1. Add UI test targets for macOS and iOS with isolated temporary store launch arguments.
2. Automate onboarding, create/edit/search/pin/trash/restore flows.
3. Add SwiftData edge-case tests: empty store after delete, save failure, fetch failure, corrupt tint repair, migration marker behavior.
4. Add CI: XcodeGen, plist lint, iOS tests, macOS verification, whitespace checks.
5. Add manual release artifact checklist output for signed archive, embedded widget, entitlements, versions, and privacy manifests.

### Suggested PR breakdown

1. **PR 1:** Empty-store semantics and tests.
2. **PR 2:** Persistence error result model and logging.
3. **PR 3:** Release/versioning hardening and docs cleanup.
4. **PR 4:** CI workflow plus plist/diff checks.
5. **PR 5:** UI test target and first critical flow.
6. **PR 6:** ModelActor persistence migration.
7. **PR 7:** Widget no-note state and explicit snapshot publication.

## 15. Future Features Roadmap

### System integration

1. **App Intents for create/open/pin note**
   - User value: Shortcuts, Siri, Spotlight, Controls, and automation access.
   - Code areas: new AppIntents target/files, `NoteStore` action facade, persistence actor.
   - Dependencies: stable note IDs and async repository access.
   - Approach: add intents that operate on note entities without launching full UI where possible.

2. **Spotlight indexing for note titles**
   - User value: find cheat sheets from system search.
   - Code areas: persistence save pipeline, privacy docs.
   - Dependencies: local indexing policy.
   - Approach: index titles and optional previews with user opt-out.

3. **Share extension or share sheet import**
   - User value: save snippets from Safari, Terminal docs, or other apps.
   - Code areas: new extension target, App Group persistence.
   - Dependencies: robust App Group config.
   - Approach: receive plain text and create a new note.

4. **URL import/export format**
   - User value: share notes between devices manually without accounts.
   - Code areas: parsing/export service, document picker.
   - Dependencies: privacy review and conflict handling.
   - Approach: local JSON/Markdown import/export with validation.

### Note experience

5. **Markdown preview mode**
   - User value: cleaner reading for command snippets and headings.
   - Code areas: `DisplayLine`, editor detail view.
   - Dependencies: no third-party parser unless scope grows.
   - Approach: support a small documented Markdown subset.

6. **AttributedString rich text editor option**
   - User value: bold/italic/code styling while staying native.
   - Code areas: note model, editor, persistence migration.
   - Dependencies: iOS/macOS 26 TextEditor rich text APIs.
   - Approach: keep plain Markdown as default; add rich text only if product direction changes.

7. **Templates**
   - User value: quick Git checklist, release checklist, deploy steps.
   - Code areas: starter/template service, onboarding.
   - Dependencies: none.
   - Approach: ship local templates without accounts or network.

8. **Tags or folders**
   - User value: organize growing note sets.
   - Code areas: model, SidebarView, search.
   - Dependencies: migration and UI tests.
   - Approach: simple tags before nested folders.

9. **Pinned note history**
   - User value: quickly switch widget note.
   - Code areas: `NoteStore`, widget snapshot, UI.
   - Dependencies: widget selection tests.
   - Approach: maintain recent pinned IDs locally.

10. **Duplicate note**
    - User value: create variations of command checklists.
    - Code areas: `NoteStore`, toolbar/menu.
    - Dependencies: none.
    - Approach: copy title/body/style with new ID and timestamp.

### Widget and presentation

11. **Runtime no-note widget state**
    - User value: clear guidance instead of starter content when no note is available.
    - Code areas: `CheatSheetProvider`, `CheatSheetEntry`, widget view.
    - Dependencies: small entry-state enum.
    - Approach: distinguish placeholder, snapshot, and runtime empty states.

12. **Configurable widget note**
    - User value: choose note per widget instance.
    - Code areas: WidgetKit App Intent configuration, note entity query.
    - Dependencies: App Intents note entities.
    - Approach: migrate from global pinned-note snapshot to per-widget configuration.

13. **Lock Screen / StandBy style widgets if useful**
    - User value: glanceable reminders outside Home Screen.
    - Code areas: widget families and layout.
    - Dependencies: content density review.
    - Approach: add only if text remains readable.

14. **Interactive widget checklist toggles**
    - User value: mark small checklist items without opening the app.
    - Code areas: widget intents, persistence actor, display parser.
    - Dependencies: model must preserve task identity, not just parse lines.
    - Approach: introduce structured checklist items before making widget interactive.

### Reliability and release

15. **CI and release artifact verification**
    - User value: safer contributions and uploads.
    - Code areas: `.github/workflows`, scripts, docs.
    - Dependencies: CI runner with Xcode.
    - Approach: start with iOS test + plist lint; add macOS release check on release branches.

16. **Storage health screen**
    - User value: confidence that local data is saving.
    - Code areas: `SettingsView`, `NoteStore`, repository status.
    - Dependencies: persistence error result model.
    - Approach: show last save status and app-group availability.

17. **Manual backup/export**
    - User value: no-account backup.
    - Code areas: export/import service, document picker.
    - Dependencies: privacy and file access review.
    - Approach: user-initiated file export only.

18. **iCloud sync as optional future feature**
    - User value: notes across devices.
    - Code areas: persistence, conflict resolution, privacy copy, settings.
    - Dependencies: CloudKit entitlement, sync design, App Privacy changes.
    - Approach: only after local persistence and conflict model are hardened.

## 16. Appendix: File/Path Index (group files by purpose)

### Project and release config

- `project.yml`: XcodeGen source of truth for targets, schemes, settings, entitlements, versions.
- `Scripts/verify-macos.sh`: macOS arm64/x86_64 test and universal Release build wrapper.
- `Scripts/increment-build-number.sh`: archive build-number increment script.
- `CheatSheetApp/Info.plist`: macOS app plist.
- `CheatSheetApp/iOSInfo.plist`: iOS/iPadOS app plist.
- `CheatSheetWidgets/Info.plist`: widget extension plist.
- `CheatSheetApp/CheatSheet.entitlements`: macOS app sandbox and App Group.
- `CheatSheetApp/CheatSheet-iOS.entitlements`: iOS App Group.
- `CheatSheetWidgets/CheatSheetWidgets.entitlements`: macOS widget sandbox and App Group.
- `CheatSheetWidgets/CheatSheetWidgets-iOS.entitlements`: iOS widget App Group.
- `CheatSheetApp/Resources/PrivacyInfo.xcprivacy`: app privacy manifest.
- `CheatSheetWidgets/Resources/PrivacyInfo.xcprivacy`: widget privacy manifest.

### App shell and navigation

- `CheatSheetApp/Sources/CheatSheetApp.swift`: app entrypoint and scenes.
- `CheatSheetApp/Sources/ContentView.swift`: root layout, navigation, toolbar, onboarding, trash routing.
- `CheatSheetApp/Sources/SidebarView.swift`: split sidebar list/search.
- `CheatSheetApp/Sources/SidebarNoteRow.swift`: list row display.
- `CheatSheetApp/Sources/MenuBarQuickAccessView.swift`: macOS menu-bar quick capture.
- `CheatSheetApp/Sources/SettingsView.swift`: settings UI.

### Editor and note UI

- `CheatSheetApp/Sources/EditorView.swift`: editor shell.
- `CheatSheetApp/Sources/EditorTextPanel.swift`: title/body editor panel.
- `CheatSheetApp/Sources/EditorHeader.swift`: title, style, pin controls.
- `CheatSheetApp/Sources/GlassPalettePicker.swift`: color picker.
- `CheatSheetApp/Sources/GlassPaletteSwatchButton.swift`: color swatch button.
- `CheatSheetApp/Sources/FontStylePicker.swift`: font style menu.
- `CheatSheetApp/Sources/TrashNoteView.swift`: trash detail view.
- `CheatSheetApp/Sources/EmptyStateView.swift`: no-note UI.
- `CheatSheetApp/Sources/StickyNotePreview.swift`: preview card.
- `CheatSheetApp/Sources/ChecklistLineView.swift`: parsed line rendering.

### Styling and onboarding

- `CheatSheetApp/Sources/AppDesign.swift`: spacing, sizing, hit target constants.
- `CheatSheetApp/Sources/AppTheme.swift`: fallback colors/materials.
- `CheatSheetApp/Sources/ViewModifiers.swift`: Liquid Glass and button style compatibility wrappers.
- `CheatSheetApp/Sources/LiquidGlassGroup.swift`: GlassEffectContainer wrapper.
- `CheatSheetApp/Sources/AppBackdrop.swift`: macOS background.
- `CheatSheetApp/Sources/OnboardingView.swift`: first-launch onboarding.
- `CheatSheetApp/Sources/OnboardingStartButton.swift`: onboarding call to action.
- `CheatSheetApp/Sources/OnboardingStepRow.swift`: onboarding steps.

### Domain and persistence

- `Shared/Sources/CheatSheetNote.swift`: domain model, palette, font style, App Group constants.
- `Shared/Sources/CheatSheetNote+Trash.swift`: trash status and retention policy.
- `Shared/Sources/CheatSheetNoteRepository.swift`: repository protocol, UserDefaults store, widget snapshot store.
- `Shared/Sources/SwiftDataCheatSheetNoteRepository.swift`: SwiftData repository and migration/fallback.
- `Shared/Sources/PersistedCheatSheetNote.swift`: SwiftData `@Model`.
- `Shared/Sources/DisplayLine.swift`: checklist/heading parsing.

### Widgets

- `CheatSheetWidgets/Sources/CheatSheetWidgetBundle.swift`: widget bundle entry.
- `CheatSheetWidgets/Sources/CheatSheetWidget.swift`: widget configuration.
- `CheatSheetWidgets/Sources/CheatSheetProvider.swift`: placeholder/snapshot/timeline provider.
- `CheatSheetWidgets/Sources/CheatSheetEntry.swift`: timeline entry.
- `CheatSheetWidgets/Sources/CheatSheetWidgetView.swift`: widget root view.
- `CheatSheetWidgets/Sources/WidgetLineView.swift`: widget line rendering.
- `CheatSheetWidgets/Sources/WidgetFamily+CheatSheetLayout.swift`: family-specific layout constants.
- `CheatSheetWidgets/Sources/CheatSheetNote+WidgetTint.swift`: widget tint helpers.

### Tests

- `CheatSheetTests/Sources/NoteRepositoryTests.swift`: repository persistence/migration tests.
- `CheatSheetTests/Sources/NoteStoreTests.swift`: store behavior tests.
- `CheatSheetTests/Sources/DisplayLineTests.swift`: parser tests.
- `CheatSheetTests/Sources/CheatSheetNoteTrashTests.swift`: trash copy tests.
- `CheatSheetTests/Sources/WidgetNoteSelectionTests.swift`: widget selection tests.

### Documentation

- `README.md`: product description, build/test instructions, App Group guidance.
- `CONTRIBUTING.md`: setup, style, PR guidance.
- `Docs/AppStoreReadiness.md`: release and QA plan.
- `Docs/AppStoreDescription.md`: App Store metadata draft.
- `audit/REPORT.md`: prior audit and implemented findings history.
