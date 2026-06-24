# Contributing

Thanks for taking the time to improve CheatSheet.

This project is meant to stay small, native, and easy to build. The best contributions are focused, well tested, and easy to review.

## Development Setup

1. Install Xcode 26 or later.
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

## Running Tests

```sh
Scripts/verify-macos.sh
```

The script generates its project and DerivedData under `/private/tmp`. This avoids
`NSFileCoordinator` hangs when a checkout lives in a File Provider-managed
Documents folder.

If you are only changing shared parsing or model code, add or update focused tests in `CheatSheetTests`.

## Widget Signing

The desktop widget needs a shared app group. Forks should use their own Apple Developer Team ID and app group. Update the app group in `project.yml`, both entitlements files, and `Shared/Sources/CheatSheetNote.swift`, then run `xcodegen generate`.

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

- macOS version.
- Xcode version if the issue is build related.
- Steps to reproduce.
- What you expected to happen.
- What happened instead.

Feature requests should explain the use case and why it belongs in a small note and widget app.
