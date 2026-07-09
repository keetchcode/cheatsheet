import XCTest

final class CheatSheetiOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsOnboardingOrMainSurface() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let onboardingTitle = app.staticTexts["CheatSheet"]
        let mainNavigationTitle = app.navigationBars["CheatSheet"]
        let createNoteButton = app.buttons["Create Note"]
        let newNoteButton = app.buttons["New Note"]

        let didShowKnownSurface =
            onboardingTitle.waitForExistence(timeout: 5)
            || mainNavigationTitle.exists
            || createNoteButton.exists
            || newNoteButton.exists

        XCTAssertTrue(didShowKnownSurface, "Expected CheatSheet to launch into onboarding or the main notes surface.")
    }
}
