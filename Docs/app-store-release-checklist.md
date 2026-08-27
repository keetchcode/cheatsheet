# CheatSheet — App Store Release Checklist

Companion to [app-store-release-audit.md](app-store-release-audit.md) and
[app-store-release-qa-report.md](app-store-release-qa-report.md).

## Completed automatically (this session)

- [x] Full repository/architecture discovery and written audit
      ([app-store-release-audit.md](app-store-release-audit.md))
- [x] Clean macOS build + full unit test suite, arm64 (55/55 passed)
- [x] Clean macOS build + full unit test suite, x86_64 (55/55 passed)
- [x] macOS universal Release build (`arm64 x86_64` fat binary confirmed via `lipo`)
- [x] Clean iOS Simulator build + full unit test suite (55/55 passed)
- [x] iOS UI smoke test suite on Simulator (7/7, each individually confirmed —
      see QA report for the one toolchain-hang-and-retry story)
- [x] iPad Simulator build
- [x] macOS Release archive with local signing (entitlements verified correct)
- [x] `Scripts/verify-project-config.sh` (entitlement/App-Group/privacy-manifest
      consistency, Hardened Runtime present) — passed
- [x] Static review: force unwraps/casts/`try!`, `fatalError`,
      `assertionFailure`, stray `print()`, `TODO`/`FIXME` — none found
- [x] Static review: concurrency (`Task` capture lists, `@unchecked Sendable`
      usage, main-actor isolation) — no issues found
- [x] Secret scan (API keys, tokens, passwords) in source — none found
- [x] `.gitignore` / tracked-file audit — no build artifacts, no generated
      `.xcodeproj`, no `.DS_Store` committed
- [x] App icon asset check (all iOS/iPad/macOS sizes present; 1024 marketing
      icon has no alpha channel, correct 1024×1024 dimensions)
- [x] Privacy manifest review (both targets) against actual API usage — accurate
- [x] Fixed: two stale support/source URLs in `PRIVACY.md` pointed at a renamed
      GitHub username (`keetchcode` → `weskcode`); GitHub was 301-redirecting
      them, but they now point at the canonical URL directly
- [x] Build number bumped for this release candidate (see QA report for the
      exact before/after values)
- [x] Compiler-warning scan of every build/test log — zero real warnings (one
      benign informational line from the AppIntents metadata tool, expected
      since this app has no App Intents)
- [x] Fixed: CI never built the Release configuration that actually ships
      (only ran `xcodebuild test`, which builds Debug-equivalent). Added a
      "Build Release configuration" step to both the iOS and macOS CI jobs in
      `.github/workflows/ci.yml`, mirroring what `Scripts/verify-macos.sh`
      already does locally, so a Release-only regression can't silently pass
      CI. YAML syntax validated locally; the workflow itself will only
      actually run once pushed (not attempted — see git workflow notes).

## Completed manually (visual/behavioral review by the auditor, not by a test)

- [x] Source-level accessibility review: `accessibilityLabel`/`Hint`/`Identifier`
      coverage, 44pt minimum hit target constant, non-color selection indicator
      (`accessibilityDifferentiateWithoutColor`) on the palette swatches, Dynamic
      Type via semantic text styles almost everywhere (one fixed-size decorative
      icon, which is correct as-is)
- [x] Marketing screenshot review (`Docs/Images/*.png`) — found one broken image;
      see QA report finding UI-1
- [x] Window minimum-size arithmetic check (sidebar 220 + editor 320 = 540 <
      640pt window minimum) — no clipping at the smallest supported window size

## Blocked by environment (documented, not skipped silently)

- [ ] **Exact CI toolchain match**: CI pins Xcode 26; only Xcode 27 beta is
      installed on this machine. All builds/tests here ran on Xcode 27 beta.
      **Action**: re-run CI (or a local Xcode 26 build) before submitting, and
      treat this session's results as supplementary, not a replacement.
- [ ] **Instruments profiling** (Time Profiler, Allocations, Leaks): not run —
      no interactive Instruments session available in this environment.
      Performance review was static/code-reading only (see QA report §Performance).
- [ ] **Physical-device testing**: simulator only. No on-device battery/thermal,
      no real VoiceOver-hardware pass, no real multitasking/Stage Manager pass.
- [ ] **Upgrade-from-older-build testing**: could not install a real prior
      TestFlight build and upgrade in place inside this environment.
- [x] **macOS Release archive**: succeeded with local Apple Development
      signing; entitlements verified correct by direct `codesign` inspection.
      Only the Development→Distribution certificate swap remains (app owner's
      Apple Developer account action).
- [ ] **iOS Release archive**: failed — the cached iOS wildcard provisioning
      profile on this machine lacks the App Groups capability (three specific
      `xcodebuild` errors on `CheatSheetiOSWidgets`, see QA report §1.4). This
      is an environment/credentials limitation (no live Apple Developer Portal
      session here to auto-refresh the profile), **not a project defect** —
      `verify-project-config.sh` already confirms the App Group entitlements
      are correct, and the identical configuration archives cleanly on macOS.
      **Action**: open the project in Xcode signed into your Apple ID (or
      regenerate the iOS App ID's provisioning profile in the Developer Portal
      to include App Groups) and re-archive.
- [ ] **Distribution signing / export for either platform**: not attempted —
      requires the developer's Distribution certificate/profile, which this
      environment does not have and should not attempt to obtain.

## Requires App Store Connect action (the app owner, not automatable here)

- [ ] Confirm whether this app already has an App Store Connect record (git
      history references a prior TestFlight submission) or whether one needs to
      be created for `com.wesleykeetch.wesleycheatsheet`.
- [ ] Upload the new build (after an Xcode 26 archive + export with a
      Distribution certificate) via Xcode Organizer or Transporter.
- [ ] Confirm/complete the App Privacy "Nutrition Label" questionnaire in App
      Store Connect — it should state **no data collected**, matching
      `PrivacyInfo.xcprivacy` and `PRIVACY.md` exactly.
- [ ] Confirm export compliance answers at upload time (`ITSAppUsesNonExemptEncryption`
      is already `false` in both `Info.plist` files, which should satisfy the
      standard-encryption-only case and typically avoids the annual
      self-classification report, but confirm in App Store Connect).
- [ ] Upload App Store screenshots per platform/size (the two 6.9" iPhone and
      13" iPad marketing images in `Docs/Images/` are already at Apple's
      required pixel dimensions — 1320×2868 and 2064×2752 — so they are
      plausible starting points, but the macOS image in `Docs/Images/` is
      **not** at a macOS App Store screenshot size and the widget-gallery image
      is a feature shot, not a screenshot; new macOS captures are needed).
- [ ] Age rating questionnaire, support URL, marketing URL, and privacy policy
      URL fields in App Store Connect (repo now points at
      `https://github.com/weskcode/cheatsheet` — confirm this is the URL you
      want listed publicly in the store listing before submitting).
- [ ] Confirm the Distribution provisioning profile / certificate for team
      `HD39MR492X` is current and covers both the app and widget extension
      bundle IDs on both platforms.

## Requires product, legal, business, or design decisions

- [ ] **Regenerate `Docs/Images/cheatsheet-desktop-overview.png`** — see QA
      report finding UI-1. This is a README/marketing asset, not app code; a
      real capture (ideally via the `app-store-screenshots` skill) is needed
      rather than a guess at what it should show.
- [ ] **Localization**: currently English-only. Not a blocker (matches the
      product's stated "deliberately narrow" scope), but worth a conscious
      decision rather than a default if the target audience is
      non-English-first.
- [ ] **SwiftData schema versioning**: `PersistedCheatSheetNote` has no
      `VersionedSchema`/`SchemaMigrationPlan` yet. Not a defect today (this is
      still schema v1), but the *next* time the model shape changes, a
      migration plan will be needed — flagging now so it isn't a surprise later.
