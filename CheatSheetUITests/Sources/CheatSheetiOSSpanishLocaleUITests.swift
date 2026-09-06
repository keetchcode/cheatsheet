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

    private func launchAppInSpanish(
        showOnboarding: Bool = false,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-cheatsheet-ui-testing",
            showOnboarding ? "-cheatsheet-reset-onboarding" : "-cheatsheet-skip-onboarding",
            "-AppleLanguages", "(es-ES)",
            "-AppleLocale", "es_ES"
        ] + extraArguments
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

    /// Exercises the empty-Trash string under a Spanish locale.
    ///
    /// This asserts a translated *string*, so it launches straight into Trash
    /// rather than driving the toolbar. The toggle lives in the secondary-action
    /// group, which iOS collapses into a system "More" overflow at compact
    /// widths -- and a collapsed item becomes a plain menu row that no longer
    /// resolves by accessibility identifier, so navigating there was a
    /// width- and OS-dependent coin flip.
    func testTrashEmptyStateRendersInSpanish() throws {
        let app = launchAppInSpanish(extraArguments: ["-cheatsheet-show-trash"])

        XCTAssertTrue(
            app.staticTexts["La papelera está vacía"].waitForExistence(timeout: 10),
            "Expected the empty Trash state to render in Spanish."
        )
    }
}
