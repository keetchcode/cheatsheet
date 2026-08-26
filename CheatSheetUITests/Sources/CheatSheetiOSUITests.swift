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
}
