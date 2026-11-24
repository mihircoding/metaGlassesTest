import XCTest

/// A paced walk through the app for the demo video CI records (see the "Record demo video" step).
/// It favours being watchable over asserting: steps that can't find their control are skipped.
/// Food it logs is deleted again, so the shared demo account doesn't fill up.
final class DemoTour: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
    }

    func testDemo() throws {
        guard ProcessInfo.processInfo.environment["DEMO_BACKEND"] == "1" else {
            throw XCTSkip("No seeded backend configured (DEMO_BACKEND != 1)")
        }
        app.launch()
        signOutIfSignedIn()
        pause(3)  // welcome screen

        // Patient
        signIn("maria@nutravision.demo")
        let tabs = app.tabBars.firstMatch
        pause(4)  // dashboard
        app.swipeUp()
        pause(3)
        app.swipeDown()
        pause(1)

        tabs.buttons["Diary"].tap()
        pause(2)
        if app.buttons["Previous day"].exists {
            app.buttons["Previous day"].tap()  // the seed covers the 30 days before setup
            pause(3)
            app.swipeUp()
            pause(2)
            app.swipeDown()
            app.buttons["Next day"].tap()
            pause(2)
        }
        logAndRemoveBanana()

        tabs.buttons["Progress"].tap()
        pause(4)
        app.swipeUp()
        pause(3)

        tabs.buttons["More"].tap()
        pause(2)
        let careTeam = app.staticTexts["Care Team"].firstMatch
        if careTeam.exists {
            careTeam.tap()
            pause(4)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            pause(1)
        }
        signOutFromMore()

        // Doctor
        signIn("doctor@nutravision.demo")
        pause(4)  // patient list
        let maria = app.staticTexts["Maria Lopez"].firstMatch
        if maria.waitForExistence(timeout: 10) {
            maria.tap()
            pause(4)
            app.swipeUp()
            pause(3)
            for tab in ["Progress", "Plan & history"] where app.buttons[tab].exists {
                app.buttons[tab].tap()
                pause(3)
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            pause(1)
        }
        if app.tabBars.firstMatch.buttons["Requests"].exists {
            app.tabBars.firstMatch.buttons["Requests"].tap()
            pause(3)
        }
        signOutFromMore()
        pause(2)
    }

    // MARK: - steps

    /// Searches for a banana from today's Breakfast, opens it and logs it, then swipes it away.
    private func logAndRemoveBanana() {
        let addFood = app.buttons["Add Food"].firstMatch
        guard addFood.waitForExistence(timeout: 5) else { return }
        addFood.tap()
        let search = app.searchFields.firstMatch
        guard search.waitForExistence(timeout: 5) else { return }
        search.tap()
        search.typeText("banana\n")
        pause(4)
        let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'banana'")).firstMatch
        guard result.waitForExistence(timeout: 10) else { cancelSheet(); return }
        result.tap()
        pause(3)  // nutrition label and "Fit for you" verdict
        app.swipeUp()
        pause(2)
        let add = app.buttons["Add"].firstMatch
        guard add.waitForExistence(timeout: 5) else { cancelSheet(); return }
        add.tap()
        pause(3)  // back on the diary with the banana logged

        let logged = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'banana'")).firstMatch
        if logged.waitForExistence(timeout: 5) {
            logged.swipeLeft()
            pause(1)
            if app.buttons["Delete"].waitForExistence(timeout: 3) { app.buttons["Delete"].tap() }
            pause(2)
        }
    }

    private func cancelSheet() {
        let cancel = app.navigationBars.buttons["Cancel"].firstMatch
        if cancel.exists { cancel.tap() }
        pause(1)
    }

    private func signIn(_ email: String) {
        let open = app.buttons["Sign in"]
        guard open.waitForExistence(timeout: 20) else { return }
        open.tap()
        let emailField = app.textFields["Email"]
        guard emailField.waitForExistence(timeout: 5) else { return }
        emailField.tap()
        emailField.typeText(email)
        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("demo1234")  // supabase/seed.sql
        pause(1)
        _ = RelaunchTests.submitSignIn(in: app)
        let notNow = app.buttons["Not Now"]  // iOS offers to save the password
        if notNow.waitForExistence(timeout: 4) { notNow.tap() }
        let springboardNotNow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Not Now"]
        if springboardNotNow.exists { springboardNotNow.tap() }
    }

    private func signOutFromMore() {
        let tabs = app.tabBars.firstMatch
        guard tabs.exists else { return }
        tabs.buttons["More"].tap()
        let signOut = app.buttons["Sign out"]
        if !signOut.waitForExistence(timeout: 5) { app.swipeUp() }
        if signOut.exists { signOut.tap() }
        _ = app.buttons["Create account"].waitForExistence(timeout: 15)
    }

    private func signOutIfSignedIn() {
        let welcome = app.buttons["Create account"]
        let tabs = app.tabBars.firstMatch
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline && !welcome.exists && !tabs.exists && !app.buttons["Sign out"].exists { sleep(1) }
        if !tabs.exists && app.buttons["Sign out"].exists {
            app.buttons["Sign out"].tap()  // the loading screen's, on a slow network
        } else if tabs.exists {
            signOutFromMore()
        }
        _ = welcome.waitForExistence(timeout: 15)
    }

    private func pause(_ seconds: UInt32) { sleep(seconds) }
}
