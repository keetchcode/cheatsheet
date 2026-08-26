import Foundation
import XCTest

extension XCTestCase {
    var screenshotOutputDirectory: URL? {
        guard let path = ProcessInfo.processInfo.environment["CHEATSHEET_SCREENSHOT_DIR"],
              !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path, isDirectory: true)
    }

    @MainActor
    func captureScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let outputDirectory = screenshotOutputDirectory else { return }
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: outputDirectory.appending(path: "\(name).png"))
        } catch {
            XCTFail("Could not write \(name).png to \(outputDirectory.path): \(error)")
        }
    }
}
