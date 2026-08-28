# CheatSheet

CheatSheet is a small, open-source macOS, iOS, and iPadOS app for keeping short coding notes, checklists, and command reminders close by. A WidgetKit extension keeps one pinned note visible while you work.

## Platforms

<table>
  <tr>
    <th>macOS</th>
    <th>iPhone</th>
    <th>iPad</th>
  </tr>
  <tr>
    <td><img src="Docs/Images/cheatsheet-desktop-overview.png" alt="CheatSheet on macOS" /></td>
    <td><img src="Docs/Images/cheatsheet-iphone.png" alt="CheatSheet on iPhone" /></td>
    <td><img src="Docs/Images/cheatsheet-ipad.png" alt="CheatSheet on iPad" /></td>
  </tr>
</table>

## Widgets

CheatSheet includes WidgetKit extensions for macOS, iOS, and iPadOS. Widgets follow the pinned note's color and font and support the system small, medium, and large families.

<table>
  <tr>
    <th>iPhone Home Screen</th>
    <th>macOS Widget Gallery</th>
  </tr>
  <tr>
    <td><img src="Docs/Images/cheatsheet-iphone-widget.png" alt="CheatSheet widget on the iPhone Home Screen" /></td>
    <td><img src="Docs/Images/cheatsheet-widget-gallery.png" alt="Small, medium, and large CheatSheet widgets on macOS" /></td>
  </tr>
</table>

## Features

- Create and edit short plain-text notes.
- Search note titles and contents.
- Render headings, bullets, and open or completed checklist lines in previews and widgets.
- Choose from ten note colors and four system font styles.
- Pin one note for the macOS, iOS, and iPadOS widgets.
- Use small, medium, and large widget layouts with automatic content limits.
- Move notes to Trash, restore them, delete them immediately, or let them expire after 30 days.
- Capture a note and open recent notes from the macOS menu bar.
- Use adaptive navigation for compact iPhone layouts and split-view iPad and Mac layouts.
- Store notes locally with SwiftData and app-group persistence; no account or network connection is required.
- See recoverable storage failures in the app and retry loading without overwriting stored notes.
- Use native Liquid Glass controls throughout on macOS and iOS/iPadOS 26.
- Use semantic text styles, accessibility labels, and non-color selection indicators.
- Available in English and Spanish, with locale-aware date and time formatting throughout.

## Localization

CheatSheet ships fully localized in English and neutral international Spanish
(`es`), including onboarding, the first-run starter notes, accessibility labels,
error messages, and the WidgetKit extension. Strings live in String Catalogs:

```text
CheatSheetApp/Resources/Localizable.xcstrings       App and shared-model strings
CheatSheetWidgets/Resources/Localizable.xcstrings    Widget extension strings
```

`Scripts/verify-localization.sh` checks both catalogs for missing translations,
mismatched `%@`/`%lld` placeholders between languages, and untranslated stable
keys; it runs in CI alongside `Scripts/verify-project-config.sh`. Adding a new
user-visible string requires adding both an English and a Spanish entry to the
relevant catalog.

## Project Layout

```text
CheatSheetApp/       Shared SwiftUI app sources for macOS, iOS, and iPadOS
CheatSheetWidgets/   WidgetKit extension sources for macOS and iOS/iPadOS
Shared/              Shared model, parsing, storage, and persistence code
CheatSheetTests/     Swift Testing coverage
CheatSheetUITests/   End-to-end UI tests
Docs/                Product images used by this README
Scripts/             Reproducible build and verification tooling
project.yml          XcodeGen project definition
```

`project.yml` is the source of truth for the Xcode project. The generated `CheatSheet.xcodeproj` is ignored by git.

## Requirements

- macOS 26 or later, or iOS/iPadOS 26 or later
- Xcode 26 for submission builds. An Xcode 27 beta is fine for development only
  — see the [OS support policy](Docs/os-support-policy.md).
- XcodeGen

Install XcodeGen with Homebrew:

```sh
brew install xcodegen
```

## Build

Generate the project:

```sh
xcodegen generate
```

Confirm the active toolchain ships the SDK this branch targets. Required before
archiving for the App Store:

```sh
Scripts/verify-build-sdk.sh
```

Build from the command line:

```sh
Scripts/verify-macos.sh
```

This runs arm64 and x86_64 tests, then builds a universal Release app. It generates
the Xcode project under `/private/tmp` because a checkout stored in a File
Provider-managed Documents folder can make `xcodebuild` block in
`NSFileCoordinator` while opening the generated project bundle.

For a single local build from a checkout outside File Provider-managed storage:

```sh
xcodegen generate
xcodebuild -project CheatSheet.xcodeproj -scheme CheatSheet -destination 'platform=macOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build
```

Build and test the iOS/iPadOS app and widget:

```sh
xcodegen generate --spec project.yml
xcodebuild test -project CheatSheet.xcodeproj -scheme CheatSheetiOS -destination "id=$(Scripts/resolve-ios-simulator.sh)" -derivedDataPath /tmp/CheatSheet-iOS-Test-DD CODE_SIGNING_ALLOWED=NO
```

`Scripts/resolve-ios-simulator.sh` prints the newest available iPhone simulator
UDID that meets the minimum test runtime (iOS 26.5; override with
`CHEATSHEET_MIN_IOS_RUNTIME`). Prefer it over a device name: a bare
`name=iPhone 17` destination resolves to `OS:latest`, which fails once the
installed runtime is newer than that device. It fails loudly rather than falling
back to a runtime below the floor, so the suite cannot pass against a
configuration the app does not support.

To check the iPad layout, resolve the newest qualifying iPad simulator:

```sh
xcodebuild build -project CheatSheet.xcodeproj -scheme CheatSheetiOS -destination "id=$(Scripts/resolve-ios-simulator.sh ipad)" -derivedDataPath /tmp/CheatSheet-iPad-DD CODE_SIGNING_ALLOWED=NO
```

## Running The Widget

The app and widget share data through platform app groups. The current app groups are:

```text
macOS:      HD39MR492X.com.wesleykeetch.wesleycheatsheet
iOS/iPadOS: group.com.wesleykeetch.wesleycheatsheet
```

If you fork the project and want to run the widget with your own Apple Developer account, update the app group in these places:

- `project.yml`
- `CheatSheetApp/CheatSheet.entitlements`
- `CheatSheetApp/CheatSheet-iOS.entitlements`
- `CheatSheetWidgets/CheatSheetWidgets.entitlements`
- `CheatSheetWidgets/CheatSheetWidgets-iOS.entitlements`
- `Shared/Sources/CheatSheetNote.swift`

Then regenerate the project:

```sh
xcodegen generate
```

After running the app once, add the CheatSheet widget from the macOS widget gallery or the iOS/iPadOS widget picker. Pin a note in the app with `Use in Widget`, then the widget will read that note from the shared app group.

## Privacy

CheatSheet stores notes locally on device. The app does not include analytics, accounts, sync, or network services.
See the public [Privacy Policy](PRIVACY.md) for the complete disclosure.

## Product Principles

CheatSheet is deliberately narrow. Changes should make capturing or glancing at
a short note faster without turning the app into a general document editor.

- Local-first and useful without an account or network connection.
- Plain-text-oriented, instant, and native to each Apple platform.
- One pinned note for the widget rather than a complex widget dashboard.
- No third-party dependency unless the platform cannot reasonably provide the feature.
- No sync, collaboration, rich-document, or account system without a separate product decision.

## Contributing

Contributions are welcome. Please keep the project small, native, and easy to understand.

Start with [CONTRIBUTING.md](CONTRIBUTING.md) for setup, style, and pull request guidance.

## License

CheatSheet is available under the MIT License. See [LICENSE](LICENSE) for details.
