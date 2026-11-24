import XCTest

/// A brand-new patient: sign up, the three onboarding steps, the dashboard, then delete the account
/// again so the demo backend doesn't collect test users. Screenshots of each step go to $SCREENSHOT_DIR.
final class OnboardingTests: XCTestCase {
    private let app = XCUIApplication()

    func testNewPatientOnboarding() throws {
        guard ProcessInfo.processInfo.environment["DEMO_BACKEND"] == "1" else {
            throw XCTSkip("No seeded backend configured (DEMO_BACKEND != 1)")
        }
        continueAfterFailure = false
        app.launch()
        signOutIfSignedIn()

        app.buttons["Create account"].tap()
        XCTAssertTrue(app.navigationBars["Create account"].waitForExistence(timeout: 5))
        type("Onboarding Test", into: app.textFields["Full name"])
        type("ci-onboard-\(UUID().uuidString.prefix(8).lowercased())@nutravision.test", into: app.textFields["Email"])
        type("onboard-\(UUID().uuidString.prefix(8))", into: app.secureTextFields["Password (8+ characters)"])
        let submit = app.collectionViews.buttons["Create account"].firstMatch
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()
        dismissSavePassword()

        // Step 1: body. The fields save on Done/focus loss, so Next stays disabled until then.
        XCTAssertTrue(app.navigationBars["Step 1 of 3"].waitForExistence(timeout: 90), "sign-up did not reach onboarding")
        dismissSavePassword()
        type("168", into: app.textFields["Height in centimeters"])
        type("72", into: app.textFields["Weight in kilograms"])
        let done = app.toolbars.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3), "no Done button above the number pad")
        done.tap()
        snap("14-onboarding-body")
        let next = app.buttons["Next"]
        XCTAssertTrue(next.isEnabled, "Next stayed disabled after entering height and weight")
        next.tap()

        // Step 2: conditions and goal.
        XCTAssertTrue(app.navigationBars["Step 2 of 3"].waitForExistence(timeout: 5))
        snap("15-onboarding-conditions")
        app.buttons["Next"].tap()

        // Step 3: targets.
        XCTAssertTrue(app.navigationBars["Step 3 of 3"].waitForExistence(timeout: 5))
        snap("16-onboarding-targets")
        let finish = app.buttons["Finish"]
        if !finish.isHittable { app.swipeUp() }
        finish.tap()
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 60), "onboarding did not reach the dashboard")
        snap("17-new-patient-dashboard")

        // Clean up: delete the account from More.
        app.tabBars.firstMatch.buttons["More"].tap()
        let delete = app.buttons["Delete account"]
        for _ in 0..<3 where !(delete.exists && delete.isHittable) { app.swipeUp() }
        delete.tap()
        let confirm = app.buttons["Delete account and all data"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["Create account"].waitForExistence(timeout: 90), "deleting did not return to the welcome screen")
    }

    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "missing field \(field)")
        field.tap()
        field.typeText(text)
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

    private func dismissSavePassword() {
        let deadline = Date().addingTimeInterval(5)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        while Date() < deadline {
            for owner in [app, springboard] where owner.buttons["Not Now"].exists {
                owner.buttons["Not Now"].tap()
                return
            }
            usleep(250_000)
        }
    }

    private func signOutIfSignedIn() {
        let welcome = app.buttons["Create account"]
        let tabs = app.tabBars.firstMatch
        let signOut = app.buttons["Sign out"]
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline && !welcome.exists && !tabs.exists && !signOut.exists { usleep(250_000) }
        if !tabs.exists && signOut.exists {
            signOut.tap()  // the loading screen's (or onboarding's)
        } else if tabs.exists {
            tabs.buttons["More"].tap()
            if !signOut.waitForExistence(timeout: 5) { app.swipeUp() }
            signOut.tap()
        }
        XCTAssertTrue(welcome.waitForExistence(timeout: 15))
    }
}
