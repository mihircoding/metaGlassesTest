import XCTest

/// Signs up a throwaway account, deletes it from More, and checks it can no longer sign in.
/// Runs against the real demo backend (DEMO_BACKEND=1), so it exercises `delete_my_account` too.
/// A doctor account is used because it lands straight on the tabs, with no onboarding.
final class AccountDeletionTests: XCTestCase {
    private let app = XCUIApplication()

    func testDeleteAccount() throws {
        guard ProcessInfo.processInfo.environment["DEMO_BACKEND"] == "1" else {
            throw XCTSkip("No seeded backend configured (DEMO_BACKEND != 1)")
        }
        continueAfterFailure = false
        app.launchArguments += ["-UITests"]  // a plain password field the test can type into
        app.launch()
        signOutIfSignedIn()

        let email = "ci-delete-\(UUID().uuidString.prefix(8).lowercased())@nutravision.test"
        let password = "delete-me-\(UUID().uuidString.prefix(6))"
        app.buttons["Create account"].tap()
        XCTAssertTrue(app.navigationBars["Create account"].waitForExistence(timeout: 5))
        app.buttons["Doctor"].tap()
        type(email: email, password: password)
        let fullName = app.textFields["Full name"]
        fullName.tap()
        fullName.typeText("Deletion Test")
        let specialty = app.textFields["Specialty"]
        if specialty.exists { specialty.tap(); specialty.typeText("Testing") }
        let license = app.textFields["License #"]
        if license.exists { license.tap(); license.typeText("TEST123") }
        // The form's own button (the welcome screen's "Create account" may still be in the hierarchy).
        let submit = app.collectionViews.buttons["Create account"].firstMatch
        XCTAssertTrue(submit.waitForExistence(timeout: 5), "no Create account button in the form")
        if !submit.isEnabled {
            snap("account-deletion-form-invalid")
            print("DELETE-DEBUG form not valid:\n\(app.debugDescription)")
        }
        submit.tap()
        dismissSavePassword()  // can appear before the tabs and cover them
        if !app.tabBars.firstMatch.waitForExistence(timeout: 90) {
            snap("account-deletion-signup-stuck")
            print("DELETE-DEBUG sign-up did not finish:\n\(app.debugDescription)")
            XCTFail("sign-up did not reach the doctor tabs")
            return
        }
        dismissSavePassword()

        app.tabBars.firstMatch.buttons["More"].tap()
        let delete = app.buttons["Delete account"]
        if !delete.waitForExistence(timeout: 5) { app.swipeUp() }
        delete.tap()
        let confirm = app.buttons["Delete account and all data"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "no confirmation before deleting")
        confirm.tap()
        XCTAssertTrue(app.buttons["Create account"].waitForExistence(timeout: 90), "deleting did not return to the welcome screen")

        // The account is gone, so signing in with it must fail.
        app.buttons["Sign in"].tap()
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(password)
        app.buttons.matching(identifier: "Sign in").allElementsBoundByIndex.last?.tap()
        XCTAssertFalse(app.tabBars.firstMatch.waitForExistence(timeout: 20), "a deleted account could still sign in")
    }

    private func type(email: String, password: String) {
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields["Password (8+ characters)"]
        passwordField.tap()
        passwordField.typeText(password)
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
        let deadline = Date().addingTimeInterval(6)
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
            signOut.tap()  // the loading screen's
        } else if tabs.exists {
            tabs.buttons["More"].tap()
            if !signOut.waitForExistence(timeout: 5) { app.swipeUp() }
            signOut.tap()
        }
        XCTAssertTrue(welcome.waitForExistence(timeout: 15))
    }
}
