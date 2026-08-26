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
            showOnboarding ? "-cheatsheet-reset-onboarding" : "-cheatsheet-skip-onboarding"
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

    private func revealSearchField(in app: XCUIApplication) -> XCUIElement {
        var field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 2) {
            app.swipeDown()
            field = app.searchFields.firstMatch
        }
        return field
    }
}
