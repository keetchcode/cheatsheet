# Contributing

Thanks for taking the time to improve CheatSheet.

This project is meant to stay small, native, and easy to build. The best contributions are focused, well tested, and easy to review.

## Development Setup

1. Install Xcode 26. An Xcode 27 beta is fine for development, but must
   never be used for a submission build — see `Docs/os-support-policy.md`.
   The app requires macOS 26 / iOS 26, so a Mac running macOS 26 or later is
   needed to run the macOS app and its tests.
2. Install XcodeGen.
3. Generate the project.

```sh
brew install xcodegen
xcodegen generate
```

4. Open `CheatSheet.xcodeproj` or build from the command line.

```sh
Scripts/verify-macos.sh
```

## Verifying the Build SDK

Before archiving for the App Store, confirm the active toolchain ships the
SDK this branch targets. A beta SDK is rejected at upload.

```sh
Scripts/verify-build-sdk.sh
```

## Running Tests

```sh
Scripts/verify-macos.sh
```

The script generates its project and DerivedData under `/private/tmp`. This avoids
`NSFileCoordinator` hangs when a checkout lives in a File Provider-managed
Documents folder.

If you are only changing shared parsing or model code, add or update focused tests in `CheatSheetTests`.

For iOS and iPadOS unit tests:

```sh
xcodegen generate --spec project.yml
xcodebuild test -project CheatSheet.xcodeproj -scheme CheatSheetiOS -destination "id=$(Scripts/resolve-ios-simulator.sh)" -derivedDataPath /tmp/CheatSheet-iOS-Test-DD CODE_SIGNING_ALLOWED=NO
```

Tests run on iOS 26.5 or newer. `Scripts/resolve-ios-simulator.sh` fails rather
than selecting an older runtime; install a newer simulator via Xcode > Settings >
Components, or override the floor with `CHEATSHEET_MIN_IOS_RUNTIME`.

## Widget Signing

The widgets need a shared app group. Forks should use their own Apple Developer
Team ID and app groups. Update `project.yml`, the macOS and iOS entitlement files
under `CheatSheetApp/` and `CheatSheetWidgets/`, and
`Shared/Sources/CheatSheetNote.swift`, then run `xcodegen generate`.

## Branching (Git Flow)

This project follows [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/):

- `main` — always reflects the latest released version. Only release and hotfix branches merge here.
- `develop` — integration branch for the next release. Feature branches merge here.
- `feature/<short-name>` — new work, branched from `develop`. Merge back into `develop` via pull request when done.
- `release/<version>` — cut from `develop` to stabilize a release (version bumps, release notes, final QA). Merges into both `main` (tagged) and back into `develop`.
- `hotfix/<short-name>` — urgent fixes branched from `main`. Merges into both `main` (tagged) and `develop`.
- `feature/ios-<major>-readiness` — long-lived OS adoption branch off `develop`, carrying a different SDK
  contract from the shipping line. Keep it thin and merge `develop` into it often. See
  [`Docs/os-support-policy.md`](Docs/os-support-policy.md).

Guidelines:

- Never commit directly to `main` or `develop`; use a pull request.
- Keep branch names lowercase and hyphenated, e.g. `feature/widget-color-picker`, `hotfix/checklist-crash`.
- Delete a branch after it merges.
- Tag every merge into `main` with the release version (e.g. `v1.2.0`).
- Keep `main` and `develop` submittable at all times. Beta-SDK work belongs on an OS readiness branch.

## Code Style

- Prefer SwiftUI and system frameworks.
- Keep features small and local to the relevant target.
- Avoid third-party dependencies unless there is a clear reason.
- Use Swift Testing for behavior that can be tested without launching the app.
- Keep UI accessible with labels, Dynamic Type-friendly fonts, and minimum 44 point hit targets.
- Keep generated files out of commits.

## Conduct

Be kind, specific, and practical. Assume good intent, keep feedback focused on the work, and help maintain a welcoming space for people learning macOS app development.

## Pull Requests

Before opening a pull request:

1. Regenerate the project if `project.yml` changed.
2. Run the relevant tests.
3. Update documentation when user-facing behavior changes.
4. Keep the pull request focused on one change.

Please include:

- What changed.
- Why it changed.
- How you tested it.

## Issues

Bug reports should include:

- Platform and OS version (macOS, iOS, or iPadOS).
- Xcode version if the issue is build related.
- Steps to reproduce.
- What you expected to happen.
- What happened instead.

Feature requests should explain the use case and why it belongs in a small note and widget app.
