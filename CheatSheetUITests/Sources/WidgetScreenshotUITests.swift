import XCTest

/// Adds the CheatSheet widget to the Home Screen and captures it.
///
/// The widget reads the pinned note out of the shared App Group, so
/// `Scripts/capture-widget-screenshot.sh` seeds that store with a signed build
/// before this runs. Driving SpringBoard is inherently version-sensitive, so
/// every stage writes a `debug-*` capture to make failures diagnosable.
@MainActor
final class WidgetScreenshotUITests: XCTestCase {
    private var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let isMissingOutputDirectory = screenshotOutputDirectory == nil
        try XCTSkipIf(
            isMissingOutputDirectory,
            "Screenshot capture only runs when CHEATSHEET_SCREENSHOT_DIR is set."
        )
    }

    func testCaptureHomeScreenWidget() throws {
        XCUIDevice.shared.press(.home)
        settle()
        springboard.activate()
        settle()

        enterJiggleMode()
        captureScreenshot(named: "debug-01-jiggle")

        openWidgetGallery()
        captureScreenshot(named: "debug-02-gallery")

        chooseCheatSheetWidget()
        captureScreenshot(named: "debug-03-widget-page")

        selectMediumSize()
        captureScreenshot(named: "debug-04-medium")

        addWidget()
        settle()

        leaveJiggleMode()
        settle()
        settle()

        captureScreenshot(named: "02-widget")
    }

    // MARK: - Home Screen flow

    private func enterJiggleMode() {
        // Long-pressing empty wallpaper is the only entry point that does not
        // depend on where icons happen to sit.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            .press(forDuration: 1.6)
        settle()
    }

    private func openWidgetGallery() {
        // iOS 18+ puts an "Edit" button top-left that opens a menu containing
        // "Add Widget"; earlier releases show a bare "+" that opens the gallery.
        let editButton = springboard.buttons["Edit"]
        if editButton.waitForExistence(timeout: 5), editButton.isHittable {
            editButton.tap()
            settle()

            let addWidget = springboard.buttons["Add Widget"]
            if addWidget.waitForExistence(timeout: 5), addWidget.isHittable {
                addWidget.tap()
                settle()
                settle()
                return
            }
        }

        for identifier in ["Add Widget", "Add", "plus"] {
            let button = springboard.buttons[identifier]
            if button.exists, button.isHittable {
                button.tap()
                settle()
                return
            }
        }

        XCTFail("Could not open the widget gallery from jiggle mode.")
    }

    private func chooseCheatSheetWidget() {
        // The gallery populates asynchronously; its rows exist in the hierarchy
        // before they are laid out and hittable.
        let searchField = springboard.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 10) {
            searchField.tap()
            searchField.typeText("CheatSheet")
            settle()
        }

        let result = springboard.cells.staticTexts["CheatSheet"].firstMatch
        let target = result.waitForExistence(timeout: 5)
            ? result
            : springboard.staticTexts["CheatSheet"].firstMatch

        XCTAssertTrue(target.waitForExistence(timeout: 10), "CheatSheet is missing from the widget gallery.")
        captureScreenshot(named: "debug-02b-results")
        tap(target)
        settle()
    }

    /// Taps through the element's centre when hittability never settles —
    /// SpringBoard sheets often report rows as non-hittable mid-animation.
    private func tap(_ element: XCUIElement) {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline, !element.isHittable {
            Thread.sleep(forTimeInterval: 0.5)
        }

        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// The gallery opens on the small size; one swipe lands on medium, which
    /// shows enough of the note to be worth a screenshot.
    private func selectMediumSize() {
        let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.55))
        let end = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: end)
        settle()
    }

    private func addWidget() {
        let labelled = springboard.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Add Widget")
        ).firstMatch

        if labelled.waitForExistence(timeout: 5), labelled.isHittable {
            labelled.tap()
            return
        }

        // The confirm button sits at the bottom of the sheet on every release
        // that has shipped this flow.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.945)).tap()
    }

    private func leaveJiggleMode() {
        let doneButton = springboard.buttons["Done"]
        if doneButton.exists, doneButton.isHittable {
            doneButton.tap()
            return
        }

        XCUIDevice.shared.press(.home)
    }

    private func settle() {
        Thread.sleep(forTimeInterval: 1.6)
    }

}
