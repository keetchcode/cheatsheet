import XCTest

/// Captures App Store screenshots against the curated demo content.
///
/// Deliberately separate from `CheatSheetiOSUITests`: that suite's QA sweep
/// creates a throwaway "QA Sweep Note" with placeholder body text, so every
/// capture after its third checkpoint shows test data. Apple treats
/// placeholder content in a store listing as grounds for rejection, so
/// marketing captures need their own path that only ever shows
/// `ScreenshotDemoContent`.
///
/// Not a correctness gate — it asserts only enough to know a capture is of the
/// screen it claims. CI skips it; run it on demand:
///   xcodebuild test -scheme CheatSheetiOSUI \
///     -only-testing:CheatSheetiOSUITests/MarketingScreenshotTests
@MainActor
final class MarketingScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true   // one awkward state must not cost the rest of the set
    }

    private func launchSeeded(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-cheatsheet-ui-testing",
            "-cheatsheet-skip-onboarding",
            "-cheatsheet-seed-screenshot-demo",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ] + extra
        app.launch()
        return app
    }

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private var isPad: Bool { XCUIApplication().collectionViews["Sidebar"].exists }

    func testCaptureMarketingSet() throws {
        let app = launchSeeded()

        // M1 — the library. Real developer reference notes, colour-coded.
        XCTAssertTrue(app.staticTexts["Git Rescue"].waitForExistence(timeout: 20))
        shoot(app, "M1-library")

        // M2 — a real note open: heading, commands, checkboxes, monospace.
        app.staticTexts["Git Rescue"].firstMatch.tap()
        XCTAssertTrue(app.textFields["note-title-field"].waitForExistence(timeout: 15))
        shoot(app, "M2-note-open")

        // M3 — the palette + font controls sit above the editor on a real note.
        shoot(app, "M3-style-controls")

        // M4 — font menu open over real content.
        let fontPicker = app.buttons["font-style-picker"].firstMatch
        if fontPicker.waitForExistence(timeout: 10), fontPicker.isHittable {
            fontPicker.tap()
            _ = app.buttons["Serif"].waitForExistence(timeout: 5)
            shoot(app, "M4-font-menu")
            // Leave the note on its default Mono rather than mutating it.
            if app.buttons["Mono"].firstMatch.exists { app.buttons["Mono"].firstMatch.tap() }
        }
    }

    func testCaptureSearch() throws {
        let app = launchSeeded()
        XCTAssertTrue(app.staticTexts["Git Rescue"].waitForExistence(timeout: 20))

        var field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 3) {
            app.swipeDown()
            field = app.searchFields.firstMatch
        }
        if !field.waitForExistence(timeout: 3) {
            let sidebar = app.collectionViews["Sidebar"]
            if sidebar.waitForExistence(timeout: 3) { sidebar.swipeDown() }
            field = app.searchFields.firstMatch
        }
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10))
        field.typeText("git")
        _ = app.staticTexts["Git Rescue"].waitForExistence(timeout: 10)
        shoot(app, "M5-search")
    }

    func testCaptureTrash() throws {
        // Trash needs an archived note. Archive a demo note, then show Trash --
        // so the shot carries real content instead of an empty state.
        let app = launchSeeded()
        XCTAssertTrue(app.staticTexts["Vim Motions"].waitForExistence(timeout: 20))
        app.staticTexts["Vim Motions"].firstMatch.tap()
        XCTAssertTrue(app.textFields["note-title-field"].waitForExistence(timeout: 15))

        let trashButton = app.buttons["move-to-trash-button"].firstMatch
        if trashButton.waitForExistence(timeout: 5), trashButton.isHittable {
            trashButton.tap()
        } else if app.buttons["More"].firstMatch.waitForExistence(timeout: 5) {
            app.buttons["More"].firstMatch.tap()
            app.buttons["Move to Trash"].firstMatch.tap()
        }

        let toggle = app.buttons["toggle-trash-button"].firstMatch
        if toggle.waitForExistence(timeout: 5), toggle.isHittable {
            toggle.tap()
        } else if app.buttons["More"].firstMatch.waitForExistence(timeout: 5) {
            app.buttons["More"].firstMatch.tap()
            app.buttons["Show Trash"].firstMatch.tap()
        }

        XCTAssertTrue(app.staticTexts["Vim Motions"].waitForExistence(timeout: 15))
        shoot(app, "M6-trash-list")

        app.staticTexts["Vim Motions"].firstMatch.tap()
        if app.buttons["restore-note-button"].waitForExistence(timeout: 10) {
            shoot(app, "M7-trash-detail")
        }
    }
}
