# CheatSheet

CheatSheet is a small open source macOS app for keeping short coding notes, checklists, and command reminders close by. It includes a desktop WidgetKit widget so one pinned note can stay visible while you work.

The app is intentionally simple:

- Create and edit small cheat-sheet notes.
- Pin one note for the desktop widget.
- Pick a note color and font style.
- Move notes to Trash, restore them, or let them delete automatically after 30 days.
- Store notes locally using SwiftData and app-group persistence.
- Use Liquid Glass styling on macOS 26 with material fallbacks on macOS 15 through 25.

## Project Layout

```text
CheatSheetApp/       macOS SwiftUI app
CheatSheetWidgets/   WidgetKit extension
Shared/              Shared model, parsing, storage, and persistence code
CheatSheetTests/     Swift Testing coverage
project.yml          XcodeGen project definition
```

`project.yml` is the source of truth for the Xcode project. The generated `CheatSheet.xcodeproj` is ignored by git.

## Requirements

- macOS 15 or later
- Xcode 26 or later
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

Build from the command line:

```sh
xcodebuild -project CheatSheet.xcodeproj -scheme CheatSheet -destination 'platform=macOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build
```

Run tests:

```sh
xcodebuild -project CheatSheet.xcodeproj -scheme CheatSheet -destination 'platform=macOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO test
```

## Running The Widget

The app and widget share data through an app group. The current app group is:

```text
HD39MR492X.com.wesleykeetch.CheatSheet
```

If you fork the project and want to run the widget with your own Apple Developer account, update the app group in these places:

- `project.yml`
- `CheatSheetApp/CheatSheet.entitlements`
- `CheatSheetWidgets/CheatSheetWidgets.entitlements`
- `Shared/Sources/CheatSheetNote.swift`

Then regenerate the project:

```sh
xcodegen generate
```

After running the app once, add the CheatSheet widget from the macOS widget gallery. Pin a note in the app with `Use in Widget`, then the widget will read that note from the shared app group.

## Privacy

CheatSheet stores notes locally on your Mac. The app does not include analytics, accounts, sync, or network services.

## Contributing

Contributions are welcome. Please keep the project small, native, and easy to understand.

Start with [CONTRIBUTING.md](CONTRIBUTING.md) for setup, style, and pull request guidance.

## License

CheatSheet is available under the MIT License. See [LICENSE](LICENSE) for details.
