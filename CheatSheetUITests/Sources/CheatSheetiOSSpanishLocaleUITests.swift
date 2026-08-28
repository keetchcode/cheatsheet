import XCTest

/// Runs a subset of the standard UI flow with the device language forced to
/// Spanish, so a regression that leaves a raw String Catalog key on screen (or
/// crashes while resolving a Spanish plural/format string) is caught in CI. The
/// main `CheatSheetiOSUITests` suite intentionally asserts on rendered English
/// text and stays locale-coupled by design (see its comments); this suite
/// exists specifically to exercise the Spanish translations end to end.
@MainActor
final class CheatSheetiOSSpanishLocaleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchAppInSpanish(showOnboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-cheatsheet-ui-testing",
            showOnboarding ? "-cheatsheet-reset-onboarding" : "-cheatsheet-skip-onboarding",
            "-AppleLanguages", "(es-ES)",
            "-AppleLocale", "es_ES"
        ]
        app.launch()
        return app
    }

    /// Accessibility identifiers are stable across locales, so the core surface
    /// must still be reachable purely by identifier under Spanish.
    func testCoreSurfaceIsReachableByAccessibilityIdentifierInSpanish() throws {
        let app = launchAppInSpanish()

        XCTAssertTrue(
            app.buttons["new-note-button"].waitForExistence(timeout: 10),
            "Expected the notes surface to load under a Spanish locale."
        )

        app.buttons["new-note-button"].tap()
        XCTAssertTrue(
            app.textFields["note-title-field"].waitForExistence(timeout: 10),
            "Expected the note editor to open under a Spanish locale."
        )
        XCTAssertTrue(
            app.textViews["note-body-editor"].waitForExistence(timeout: 10),
            "Expected the note body editor to be present under a Spanish locale."
        )
    }

    /// Confirms the Spanish String Catalog entries actually load and render,
    /// not just that the app avoids crashing.
    func testSeededStarterNoteRendersInSpanish() throws {
        let app = launchAppInSpanish()

        XCTAssertTrue(app.buttons["new-note-button"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["Demostración de formato del widget"].waitForExistence(timeout: 10),
            "Expected the seeded starter note title to render in Spanish."
        )
        XCTAssertFalse(
            app.staticTexts["Widget Formatting Demo"].exists,
            "The starter note title should not still be in English under a Spanish locale."
        )
    }

    /// Onboarding is the first thing a new Spanish-speaking user sees; make sure
    /// none of its String Catalog keys leak onto screen untranslated.
    func testOnboardingRendersTranslatedTextInSpanish() throws {
        let app = launchAppInSpanish(showOnboarding: true)

        XCTAssertTrue(
            app.staticTexts["Ten a mano los comandos de programación que usas cada día."].waitForExistence(timeout: 10),
            "Expected the onboarding subtitle to render in Spanish."
        )

        let doneButton = app.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()

        XCTAssertTrue(app.buttons["new-note-button"].waitForExistence(timeout: 10))
    }

    /// Exercises the empty-Trash string under a Spanish locale. The toggle button
    /// lives in the toolbar's secondary-action group, which iOS may collapse
    /// into a "More" overflow button depending on available width.
    func testTrashEmptyStateRendersInSpanish() throws {
        let app = launchAppInSpanish()

        XCTAssertTrue(app.buttons["new-note-button"].waitForExistence(timeout: 10))
        tapToggleTrashButton(in: app)

        XCTAssertTrue(
            app.staticTexts["La papelera está vacía"].waitForExistence(timeout: 10),
            "Expected the empty Trash state to render in Spanish."
        )
    }

    /// The overflow button itself is system-provided chrome, so under a Spanish
    /// process locale it renders as "Más" rather than "More" -- accept either,
    /// since which one appears can depend on the OS version under test.
    private func tapToggleTrashButton(in app: XCUIApplication) {
        let directButton = app.buttons["toggle-trash-button"]
        if directButton.waitForExistence(timeout: 2), directButton.isHittable {
            directButton.tap()
            return
        }

        let moreButton = app.buttons.matching(NSPredicate(format: "label == 'More' OR label == 'Más'")).firstMatch
        XCTAssertTrue(moreButton.waitForExistence(timeout: 10))
        moreButton.tap()
        XCTAssertTrue(directButton.waitForExistence(timeout: 10))
        directButton.tap()
    }
}
