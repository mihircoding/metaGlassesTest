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
        app.launchArguments += ["-UITests"]  // a plain password field the test can type into
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
        scrollTo(app.buttons["Next"]).tap()  // below the condition list

        // Step 3: targets.
        XCTAssertTrue(app.navigationBars["Step 3 of 3"].waitForExistence(timeout: 5))
        snap("16-onboarding-targets")
        scrollTo(app.buttons["Finish"]).tap()
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 60), "onboarding did not reach the dashboard")
        snap("17-new-patient-dashboard")

        // Clean up: delete the account from More.
        app.tabBars.firstMatch.buttons["More"].tap()
        scrollTo(app.buttons["Delete account"]).tap()
        let confirm = app.buttons["Delete account and all data"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["Create account"].waitForExistence(timeout: 90), "deleting did not return to the welcome screen")
    }

    /// Forms load rows lazily, so a button below the fold doesn't exist until it's scrolled to.
    @discardableResult
    private func scrollTo(_ element: XCUIElement) -> XCUIElement {
        for _ in 0..<8 where !(element.exists && element.isHittable) { app.swipeUp() }
        XCTAssertTrue(element.exists, "could not scroll to \(element)")
        return element
    }

    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "missing field \(field)")
        // The keyboard from the previous field can leave this one reported as not hittable.
        let done = app.toolbars.buttons["Done"].firstMatch
        if !field.isHittable && done.exists { done.tap() }
        if field.isHittable { field.tap() } else { field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        field.typeText(text)
    }

    /// A failure part-way leaves the new account signed in on onboarding, which would start the
    /// next test there; sign it out (the account itself stays on the demo backend).
    override func tearDownWithError() throws {
        let signOut = app.buttons["Sign out"]
        if app.state == .runningForeground && !app.tabBars.firstMatch.exists && signOut.exists { signOut.tap() }
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
