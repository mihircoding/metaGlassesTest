import XCTest

/// Walks the screens reachable without a backend and saves a PNG of each to $SCREENSHOT_DIR
/// (CI sets it; when unset, screenshots are only attached to the test result).
final class ScreenTourTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launch()
    }

    func testSignedOutScreens() {
        XCTAssertTrue(app.buttons["Create account"].waitForExistence(timeout: 20))
        snap("10-welcome")

        app.buttons["Create account"].tap()
        XCTAssertTrue(app.navigationBars["Create account"].waitForExistence(timeout: 5))
        snap("11-sign-up-patient")

        app.buttons["Doctor"].tap()
        XCTAssertTrue(app.staticTexts["CREDENTIALS"].waitForExistence(timeout: 5)
                      || app.staticTexts["Credentials"].exists)
        snap("12-sign-up-doctor")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 5))
        app.buttons["Sign in"].tap()
        sleep(1)
        snap("13-sign-in")
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
