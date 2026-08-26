import UIKit
import XCTest

/// Captures the App Store screenshot set from the real app UI.
///
/// Every image here is a native-resolution capture of the running app — the
/// only thing the launch arguments change is the note content, so the shots
/// stay honest about what the app actually does. Raw PNGs are written to the
/// directory named by `CHEATSHEET_SCREENSHOT_DIR` and also attached to the test
/// result as a fallback.
///
/// Run with `Scripts/capture-app-store-screenshots.sh`.
@MainActor
final class AppStoreScreenshotUITests: XCTestCase {
    private func isPad(_ app: XCUIApplication) -> Bool {
        app.frame.width >= 700
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let isMissingOutputDirectory = screenshotOutputDirectory == nil
        try XCTSkipIf(
            isMissingOutputDirectory,
            "Screenshot capture only runs when CHEATSHEET_SCREENSHOT_DIR is set."
        )
    }

    // MARK: - Dark set

    func testCaptureAppStoreScreenshots() throws {
        let app = launchApp()

        if isPad(app) {
            // Regular width opens straight into sidebar + editor, so the hero
            // shot and the list shot are the same screen.
            captureScreenshot(named: "01-hero")
        } else {
            captureScreenshot(named: "03-list")
            openNote("Git Rescue", in: app)
            captureScreenshot(named: "01-hero")
            goBackToList(in: app)
        }

        openNote("Ship Checklist", in: app)
        dismissWidgetHint(in: app)
        captureScreenshot(named: "04-checklist")
        goBackToList(in: app)

        // Styling reads best as a finished note rather than an open menu: a
        // menu covers the palette it is meant to advertise.
        openNote("Xcode Shortcuts", in: app)
        dismissWidgetHint(in: app)
        chooseFont("Serif", in: app)
        captureScreenshot(named: "05-style")

        app.terminate()

        let onboardingApp = launchApp(showOnboarding: true)
        XCTAssertTrue(
            onboardingApp.buttons["onboarding-done-button"].waitForExistence(timeout: 20),
            "Expected onboarding on a reset launch."
        )
        settle()
        captureScreenshot(named: "07-open-source")
    }

    // MARK: - Light set

    /// Run separately, with the simulator flipped to light appearance, so the
    /// store set shows the app in both appearances instead of seven dark frames.
    func testCaptureLightAppearance() throws {
        let app = launchApp()

        if isPad(app) {
            captureScreenshot(named: "06-light")
        } else if search(for: "git", in: app) {
            captureScreenshot(named: "06-search")
        } else {
            XCTFail("Expected the iPhone search field to be available.")
        }
    }

    // MARK: - App lifecycle

    private func launchApp(showOnboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-cheatsheet-ui-testing",
            "-cheatsheet-demo-content",
            showOnboarding ? "-cheatsheet-reset-onboarding" : "-cheatsheet-skip-onboarding"
        ]
        app.launch()
        clearRunnerBreadcrumb(in: app)

        if !showOnboarding {
            XCTAssertTrue(
                app.buttons["new-note-button"].waitForExistence(timeout: 20),
                "Expected the notes surface to load."
            )
        }

        settle()
        return app
    }

    /// An app launched by the test runner shows a "back to runner" breadcrumb in
    /// the status bar. Going home and reactivating from SpringBoard clears it,
    /// so captures show the status bar a real user sees.
    private func clearRunnerBreadcrumb(in app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.0)
        app.activate()
        Thread.sleep(forTimeInterval: 1.0)
    }

    // MARK: - Navigation

    private func openNote(_ title: String, in app: XCUIApplication) {
        let cell = app.cells.containing(.staticText, identifier: title).firstMatch
        var target = cell.exists ? cell : app.staticTexts[title]

        if !isPad(app) {
            for _ in 0..<4 where !target.isHittable {
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.35)
                target = cell.exists ? cell : app.staticTexts[title]
            }
        }

        XCTAssertTrue(target.waitForExistence(timeout: 10) && target.isHittable, "Expected a visible row for \(title).")
        target.tap()
        settle()
    }

    private func goBackToList(in app: XCUIApplication) {
        guard !isPad(app) else { return }

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists, backButton.isHittable {
            backButton.tap()
        }
        settle()
    }

    /// The widget hint only renders above unpinned notes. Hiding it keeps the
    /// later shots focused on the note itself.
    private func dismissWidgetHint(in app: XCUIApplication) {
        let hideButton = app.buttons["Hide"]
        if hideButton.waitForExistence(timeout: 3), hideButton.isHittable {
            hideButton.tap()
            settle()
        }
    }

    /// Applies a font from the note's font menu and leaves the menu closed.
    private func chooseFont(_ name: String, in app: XCUIApplication) {
        let fontButton = app.buttons["Note font"]
        XCTAssertTrue(fontButton.waitForExistence(timeout: 10), "Expected the font picker.")
        fontButton.tap()
        settle()

        let item = app.buttons[name]
        if item.waitForExistence(timeout: 3), item.isHittable {
            item.tap()
        } else {
            app.tap()
        }
        settle()
    }

    /// Returns false when the platform gives no reachable search field, so the
    /// run keeps its other captures instead of failing the whole set.
    private func search(for query: String, in app: XCUIApplication) -> Bool {
        var field = app.searchFields.firstMatch

        if !field.waitForExistence(timeout: 5) {
            // A navigation-bar drawer can be collapsed until the list is
            // pulled down on newer iOS releases.
            app.swipeDown()
            settle()
            field = app.searchFields.firstMatch
        }

        if !field.exists {
            let searchButton = app.buttons["Search"]
            if searchButton.waitForExistence(timeout: 3), searchButton.isHittable {
                searchButton.tap()
                settle()
                field = app.searchFields.firstMatch
            }
        }

        if !field.exists {
            let moreButton = app.buttons["More"]
            if moreButton.waitForExistence(timeout: 3), moreButton.isHittable {
                moreButton.tap()
                let searchButton = app.buttons["Search"]
                if searchButton.waitForExistence(timeout: 3), searchButton.isHittable {
                    searchButton.tap()
                    settle()
                    field = app.searchFields.firstMatch
                }
            }
        }

        guard field.waitForExistence(timeout: 5) else { return false }

        field.tap()
        field.typeText(query)
        settle()

        // Dismiss the keyboard so the results fill the shot.
        if app.keyboards.count > 0 {
            app.typeText("\n")
            settle()
        }

        return true
    }

    private func settle() {
        Thread.sleep(forTimeInterval: 1.4)
    }

}
