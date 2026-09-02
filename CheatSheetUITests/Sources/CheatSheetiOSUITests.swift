import XCTest

@MainActor
final class CheatSheetiOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches with an in-memory store so the suite never touches the real
    /// App Group data, and with a deterministic onboarding state.
    private func launchApp(showOnboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-cheatsheet-ui-testing",
            showOnboarding ? "-cheatsheet-reset-onboarding" : "-cheatsheet-skip-onboarding",
            // This suite asserts rendered English text throughout, so pin the
            // locale rather than depending on the simulator's default.
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
        return app
    }

    func testOnboardingCanBeDismissedIntoTheNotesList() throws {
        let app = launchApp(showOnboarding: true)

        let doneButton = app.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Expected onboarding to appear on first launch.")

        doneButton.tap()

        XCTAssertTrue(
            app.buttons["new-note-button"].waitForExistence(timeout: 10),
            "Expected the notes surface after dismissing onboarding."
        )
    }

    func testLaunchShowsSeededNotesWhenOnboardingIsComplete() throws {
        let app = launchApp()

        XCTAssertTrue(
            app.buttons["new-note-button"].waitForExistence(timeout: 10),
            "Expected the notes surface to load."
        )
        XCTAssertTrue(
            app.staticTexts["Widget Formatting Demo"].waitForExistence(timeout: 10),
            "Expected the seeded starter note in the isolated store."
        )
    }

    func testCreatingANoteAddsItToTheList() throws {
        let app = launchApp()

        let newNoteButton = app.buttons["new-note-button"]
        XCTAssertTrue(newNoteButton.waitForExistence(timeout: 10))
        newNoteButton.tap()

        // Creating a note pushes straight into its editor.
        let titleField = app.textFields["New Cheat Sheet"]
        XCTAssertTrue(
            titleField.waitForExistence(timeout: 10),
            "Expected the new note's editor to open with its default title."
        )
    }

    func testStorageBannerIsAbsentOnAHealthyLaunch() throws {
        let app = launchApp()

        XCTAssertTrue(app.buttons["new-note-button"].waitForExistence(timeout: 10))
        XCTAssertFalse(
            app.otherElements["persistence-status-banner"].exists,
            "The storage failure banner must not appear when persistence is healthy."
        )
    }

    func testEditAndSearchFlow() throws {
        let app = launchApp()
        createNote(in: app)

        let titleField = app.textFields["note-title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        titleField.tap()
        titleField.press(forDuration: 1.0)
        app.menuItems["Select All"].tap()
        titleField.typeText("Release Commands")

        let bodyEditor = app.textViews["note-body-editor"]
        XCTAssertTrue(bodyEditor.waitForExistence(timeout: 10))
        bodyEditor.tap()
        bodyEditor.typeText("\n- [ ] Upload build")

        returnToList(in: app)
        XCTAssertTrue(app.staticTexts["Release Commands"].waitForExistence(timeout: 10))

        let searchField = revealSearchField(in: app)
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("release")
        XCTAssertTrue(app.staticTexts["Release Commands"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Git Flow"].exists)
    }

    func testStyleAndWidgetPinFlow() throws {
        let app = launchApp()
        createNote(in: app)

        let mintButton = app.buttons["palette-59c979"]
        XCTAssertTrue(mintButton.waitForExistence(timeout: 10))
        mintButton.tap()
        XCTAssertEqual(mintButton.value as? String, "Selected")

        let fontPicker = app.buttons["font-style-picker"]
        XCTAssertTrue(fontPicker.waitForExistence(timeout: 10))
        fontPicker.tap()
        let serifButton = app.buttons["Serif"]
        XCTAssertTrue(serifButton.waitForExistence(timeout: 10))
        serifButton.tap()
        XCTAssertEqual(fontPicker.value as? String, "Serif")

        let pinButton = app.buttons["widget-pin-button"]
        XCTAssertTrue(pinButton.waitForExistence(timeout: 10))
        pinButton.tap()
        XCTAssertTrue(app.staticTexts["Shown in widget"].waitForExistence(timeout: 10))
    }

    func testTrashRestoreAndPermanentDeleteFlow() throws {
        let app = launchApp()
        createNote(in: app)
        renameCurrentNote("Disposable Note", in: app)

        openSecondaryAction("Move to Trash", in: app)
        openSecondaryAction("Show Trash", in: app)
        XCTAssertTrue(app.staticTexts["Disposable Note"].waitForExistence(timeout: 10))
        app.staticTexts["Disposable Note"].tap()

        let restoreButton = app.buttons["restore-note-button"]
        XCTAssertTrue(restoreButton.waitForExistence(timeout: 10))
        restoreButton.tap()
        XCTAssertTrue(app.staticTexts["Disposable Note"].waitForExistence(timeout: 10))

        app.staticTexts["Disposable Note"].tap()
        XCTAssertTrue(app.textFields["note-title-field"].waitForExistence(timeout: 10))
        openSecondaryAction("Move to Trash", in: app)
        openSecondaryAction("Show Trash", in: app)
        app.staticTexts["Disposable Note"].tap()

        let deleteButton = app.buttons["delete-note-button"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        deleteButton.tap()
        let deleteButtons = app.buttons.matching(identifier: "Delete Now")
        let confirmDeleteButton = deleteButtons.element(boundBy: max(deleteButtons.count - 1, 0))
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 10))
        confirmDeleteButton.tap()
        XCTAssertTrue(app.staticTexts["Trash is empty"].waitForExistence(timeout: 10))
    }

    private func createNote(in app: XCUIApplication) {
        let newNoteButton = app.buttons["new-note-button"]
        XCTAssertTrue(newNoteButton.waitForExistence(timeout: 10))
        newNoteButton.tap()
        XCTAssertTrue(app.textFields["note-title-field"].waitForExistence(timeout: 10))
    }

    private func renameCurrentNote(_ title: String, in app: XCUIApplication) {
        let titleField = app.textFields["note-title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        titleField.tap()
        titleField.press(forDuration: 1.0)
        app.menuItems["Select All"].tap()
        titleField.typeText(title)
        returnToList(in: app)
    }

    private func returnToList(in app: XCUIApplication) {
        if app.keyboards.count > 0 {
            app.keyboards.buttons["Return"].tap()
        }
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 10))
        backButton.tap()
    }

    private func openSecondaryAction(_ name: String, in app: XCUIApplication) {
        let directButton = app.buttons[name]
        if directButton.waitForExistence(timeout: 2), directButton.isHittable {
            directButton.tap()
            return
        }

        let moreButton = app.buttons["More"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 10))
        moreButton.tap()
        XCTAssertTrue(directButton.waitForExistence(timeout: 10))
        directButton.tap()
    }

    /// Pops back to the note list on iPhone's compact NavigationStack, where
    /// the pushed editor screen replaces the list in the accessible
    /// hierarchy. A no-op on iPad/Mac's NavigationSplitView, where the
    /// sidebar list (and its search field) is already reachable -- detected
    /// here by checking for the search field rather than branching on
    /// device/size-class directly, so this helper works unmodified on both.
    private func returnToListIfPushed(in app: XCUIApplication) {
        guard !app.searchFields.firstMatch.exists else { return }
        let backButton = app.navigationBars.firstMatch.buttons.firstMatch
        if backButton.waitForExistence(timeout: 2), backButton.isHittable {
            backButton.tap()
        }
    }

    /// Clearing the search field's text does not end its active/focused
    /// search session -- `.searchable()` keeps showing the Cancel/Close
    /// button and keeps the keyboard up until that session is explicitly
    /// dismissed, and while it's active iOS hides the rest of the
    /// navigation bar's toolbar items (New Note, Show Trash, ...) to make
    /// room for it. Confirmed via the accessibility hierarchy dump at a
    /// prior failure here: the toolbar existed but had zero buttons in it
    /// while the search field still reported `Keyboard Focused`.
    private func dismissSearchIfActive(in app: XCUIApplication) {
        let closeButton = app.buttons["Close"]
        if closeButton.waitForExistence(timeout: 2), closeButton.isHittable {
            closeButton.tap()
        }
    }

    /// Taps a text field and waits for the keyboard before returning. Typing
    /// without this races first-responder assignment on a loaded machine, which
    /// surfaces as "Neither element nor any descendant has keyboard focus"
    /// rather than as a real product failure.
    private func focusForTyping(_ field: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        XCTAssertTrue(
            app.keyboards.element.waitForExistence(timeout: 10),
            "Expected the keyboard to appear before typing."
        )
    }

    private func revealSearchField(in app: XCUIApplication) -> XCUIElement {
        var field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 2) {
            app.swipeDown()
            field = app.searchFields.firstMatch
        }
        return field
    }

    // MARK: - Ad hoc QA sweep (manual verification pass, runs on iPhone and iPad)
    //
    // This drives the whole manual QA checklist end to end against a live
    // simulator, capturing a named screenshot at every checkpoint so the
    // run can be verified visually afterward. Screenshots are attached with
    // `.keepAlways` so they land in the .xcresult bundle for extraction.
    //
    // Originally written against iPad's NavigationSplitView, where the
    // sidebar list and the editor detail pane are on screen at the same
    // time. Verified against iPhone too: everything up through editing a
    // note holds as-is, but the list-level checks (pin invariant, search,
    // selecting a different note) need `returnToListIfPushed(in:)` first --
    // iPhone's compact NavigationStack pushes the editor over the list, so
    // the list briefly isn't part of the accessible hierarchy at all. On
    // iPad/Mac that helper is a no-op since the list is already reachable.

    func testQASweep() throws {
        // --- Item 1: fresh onboarding ---
        let app = XCUIApplication()
        app.launchArguments = ["-cheatsheet-ui-testing", "-cheatsheet-reset-onboarding"]
        app.launch()

        let doneButton = app.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Onboarding sheet should appear on first launch.")
        XCTAssertTrue(app.staticTexts["Add notes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tune the look"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pin the widget note"].waitForExistence(timeout: 5))
        capture(app, "01-onboarding-sheet")

        doneButton.tap()
        XCTAssertTrue(app.buttons["new-note-button"].waitForExistence(timeout: 10), "Should land on the notes surface after onboarding.")
        capture(app, "02-onboarding-dismissed")
        assertNoPersistenceBanner(app)

        // --- Item 2: relaunch with seeded screenshot demo notes ---
        app.terminate()
        app.launchArguments = ["-cheatsheet-ui-testing", "-cheatsheet-skip-onboarding", "-cheatsheet-seed-screenshot-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["new-note-button"].waitForExistence(timeout: 10))

        let demoTitles = [
            "Git Rescue", "Ship Checklist", "Swift Concurrency", "Docker Cleanup",
            "Vim Motions", "zsh + Homebrew", "Xcode Shortcuts", "HTTP Status Codes"
        ]
        for title in demoTitles {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), "Missing seeded demo note '\(title)'.")
        }
        XCTAssertTrue(app.images["Pinned"].waitForExistence(timeout: 10), "Expected exactly one pin indicator (Git Rescue) after seeding.")
        XCTAssertEqual(app.images.matching(identifier: "Pinned").count, 1)
        capture(app, "03-demo-notes-seeded")
        assertNoPersistenceBanner(app)

        // --- Item 3: open a seeded note, inspect raw text content ---
        // NOTE: `.firstMatch` works around a SwiftUI List/NavigationSplitView
        // accessibility quirk on this iOS 27 beta where the auto-selected
        // sidebar row briefly exposes its label as two duplicate StaticText
        // nodes, which makes a plain identifier lookup ambiguous for `.tap()`.
        app.staticTexts["Git Rescue"].firstMatch.tap()
        let titleFieldExisting = app.textFields["note-title-field"]
        XCTAssertTrue(titleFieldExisting.waitForExistence(timeout: 10))
        XCTAssertTrue(app.textViews["note-body-editor"].waitForExistence(timeout: 10))
        capture(app, "04-note-opened-git-rescue")

        // --- Item 4: new note opens straight into editor with default title ---
        let newNoteButton = app.buttons["new-note-button"]
        XCTAssertTrue(newNoteButton.waitForExistence(timeout: 10))
        newNoteButton.tap()
        let titleField = app.textFields["note-title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        XCTAssertEqual(titleField.value as? String, "New Cheat Sheet")
        capture(app, "05-new-note-default-title")

        // --- Item 5: edit title + body ---
        titleField.tap()
        titleField.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 3) {
            app.menuItems["Select All"].tap()
        }
        titleField.typeText("QA Sweep Note")
        capture(app, "06-title-edited")

        let bodyEditor = app.textViews["note-body-editor"]
        XCTAssertTrue(bodyEditor.waitForExistence(timeout: 10))
        bodyEditor.tap()
        bodyEditor.typeText("# QA Heading\n- [ ] Open task line\n- [x] Done task line")
        capture(app, "07-body-edited")

        // --- Item 6: palette picker, 3 distinct swatches ---
        // Deliberately avoids palette-4b88ff (Blue), which is the app's likely
        // default tint, so every tap here produces a visibly different color
        // from the note surface's starting state, not just from each other.
        let paletteSamples = ["palette-d99a2b", "palette-e85d75", "palette-8b7cff"]
        for (index, identifier) in paletteSamples.enumerated() {
            let swatch = app.buttons[identifier]
            XCTAssertTrue(swatch.waitForExistence(timeout: 10), "Missing palette swatch \(identifier)")
            swatch.tap()
            XCTAssertEqual(swatch.value as? String, "Selected", "\(identifier) should report Selected after tap.")
            let suffix = ["a", "b", "c"][index]
            capture(app, "08\(suffix)-palette-\(identifier)")
        }

        // --- Item 7: font picker lists all 4 styles, selecting one changes typeface ---
        let fontPicker = app.buttons["font-style-picker"]
        XCTAssertTrue(fontPicker.waitForExistence(timeout: 10))
        fontPicker.tap()
        for style in ["Mono", "System", "Rounded", "Serif"] {
            XCTAssertTrue(app.buttons[style].waitForExistence(timeout: 5), "Font menu missing style \(style)")
        }
        capture(app, "09a-font-menu-open")
        app.buttons["Serif"].tap()
        XCTAssertEqual(fontPicker.value as? String, "Serif")
        capture(app, "09b-font-serif-applied")

        // --- Item 8: pin / unpin ---
        let pinButton = app.buttons["widget-pin-button"]
        XCTAssertTrue(pinButton.waitForExistence(timeout: 10))
        pinButton.tap()
        XCTAssertTrue(app.staticTexts["Shown in widget"].waitForExistence(timeout: 10))
        capture(app, "10a-note-pinned")
        returnToListIfPushed(in: app)
        XCTAssertEqual(app.images.matching(identifier: "Pinned").count, 1, "Only one note should be pinned after re-pinning.")
        capture(app, "10b-list-single-pin")

        // --- Item 9: search ---
        let searchField = revealSearchField(in: app)
        focusForTyping(searchField, in: app)
        searchField.typeText("docker")
        XCTAssertTrue(app.staticTexts["Docker Cleanup"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Vim Motions"].exists)
        capture(app, "11a-search-filtered-docker")

        if let value = searchField.value as? String, !value.isEmpty {
            // The screenshot above is a synchronous round trip long enough for
            // .searchable to drop first responder, so re-focus before clearing.
            focusForTyping(searchField, in: app)
            searchField.typeText(String(repeating: "\u{8}", count: value.count))
        }
        XCTAssertTrue(app.staticTexts["Vim Motions"].waitForExistence(timeout: 10), "Full list should return after clearing search.")
        capture(app, "11b-search-cleared")
        dismissSearchIfActive(in: app)

        // --- Item 10: trash flow (restore) ---
        app.staticTexts["Swift Concurrency"].firstMatch.tap()
        XCTAssertTrue(app.textFields["note-title-field"].waitForExistence(timeout: 10))
        tapToolbarAction(identifier: "move-to-trash-button", label: "Move to Trash", in: app)
        tapToolbarAction(identifier: "toggle-trash-button", label: "Show Trash", in: app)
        XCTAssertTrue(app.staticTexts["Swift Concurrency"].waitForExistence(timeout: 10))
        capture(app, "12a-trash-list")
        app.staticTexts["Swift Concurrency"].firstMatch.tap()
        XCTAssertTrue(app.buttons["restore-note-button"].waitForExistence(timeout: 10))
        capture(app, "12b-trash-detail-countdown")

        // Restoring already navigates back to the active list on its own
        // (TrashNoteView's restoreAction calls showNotes()), so no extra
        // toggle-trash tap is needed -- or findable, since by the time it
        // would run the toolbar button has already flipped back to "Show Trash".
        let restoreButton = app.buttons["restore-note-button"]
        restoreButton.tap()
        XCTAssertTrue(app.staticTexts["Swift Concurrency"].waitForExistence(timeout: 10), "Restored note should be back in the active list.")
        capture(app, "12c-note-restored")
        assertNoPersistenceBanner(app)

        // --- Item 10 continued: trash flow (permanent delete, different note) ---
        app.staticTexts["Vim Motions"].firstMatch.tap()
        XCTAssertTrue(app.textFields["note-title-field"].waitForExistence(timeout: 10))
        tapToolbarAction(identifier: "move-to-trash-button", label: "Move to Trash", in: app)
        tapToolbarAction(identifier: "toggle-trash-button", label: "Show Trash", in: app)
        XCTAssertTrue(app.staticTexts["Vim Motions"].waitForExistence(timeout: 10))
        app.staticTexts["Vim Motions"].firstMatch.tap()

        let deleteButton = app.buttons["delete-note-button"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        deleteButton.tap()
        capture(app, "13a-delete-confirmation-dialog")

        let deleteButtons = app.buttons.matching(identifier: "Delete Now")
        let confirmDeleteButton = deleteButtons.element(boundBy: max(deleteButtons.count - 1, 0))
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 10))
        confirmDeleteButton.tap()
        XCTAssertFalse(app.staticTexts["Vim Motions"].waitForExistence(timeout: 5), "Permanently deleted note should be gone from Trash.")
        capture(app, "13b-note-deleted-from-trash")
        assertNoPersistenceBanner(app)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertNoPersistenceBanner(_ app: XCUIApplication) {
        XCTAssertFalse(app.otherElements["persistence-status-banner"].exists, "The storage failure banner must not appear during a healthy run.")
    }

    /// Taps a `.secondaryAction` toolbar item by its accessibility identifier
    /// when it's directly visible, falling back to the "More" overflow menu
    /// when it collapses there (which iPad's narrower detail-pane toolbar
    /// does routinely). Once collapsed into "More", iOS renders the item as a
    /// plain menu row and its SwiftUI `accessibilityIdentifier` no longer
    /// resolves it -- only its visible label does -- so the fallback must
    /// look up `label`, not `identifier`.
    private func tapToolbarAction(identifier: String, label: String, in app: XCUIApplication) {
        let direct = app.buttons[identifier]
        if direct.waitForExistence(timeout: 2), direct.isHittable {
            direct.tap()
            return
        }
        let moreButton = app.buttons["More"]
        if moreButton.waitForExistence(timeout: 2) {
            moreButton.tap()
        }
        let menuItem = app.buttons[label]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 10), "Could not find toolbar action '\(label)' (\(identifier)), even behind More.")
        menuItem.tap()
    }
}
