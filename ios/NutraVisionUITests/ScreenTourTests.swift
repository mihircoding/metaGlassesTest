import XCTest

/// Walks the app's main screens and saves a PNG of each to $SCREENSHOT_DIR
/// (CI sets it; when unset, screenshots are only attached to the test result).
/// The signed-in tours use the seed.sql demo accounts and run only when CI sets
/// DEMO_BACKEND=1, i.e. when the app was built against a seeded Supabase project.
final class ScreenTourTests: XCTestCase {
    private let app = XCUIApplication()
    private let demoPassword = "demo1234"  // supabase/seed.sql

    override func setUp() {
        continueAfterFailure = false
        app.launch()
        signOutIfNeeded()
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

    func testPatientScreens() throws {
        try requireBackend()
        signIn("maria@nutravision.demo")
        let tabs = app.tabBars.firstMatch

        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 20))
        sleep(4)
        snap("20-patient-dashboard")
        app.swipeUp()
        sleep(1)
        snap("21-patient-dashboard-lower")

        tabs.buttons["Diary"].tap()
        sleep(3)
        snap("22-patient-diary")
        // Seed data covers the 30 days before setup, so show yesterday's full diary too.
        if app.buttons["Previous day"].exists {
            app.buttons["Previous day"].tap()
            sleep(3)
            snap("22b-patient-diary-yesterday")
        }

        tabs.buttons["Progress"].tap()
        sleep(4)
        snap("23-patient-progress")

        tabs.buttons["Add"].tap()
        XCTAssertTrue(app.buttons["Search food"].waitForExistence(timeout: 5))
        snap("24-patient-add-sheet")
        checkAddFoodCancel()

        app.buttons["Search food"].tap()
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("oatmeal\n")
            sleep(6)
            snap("25-patient-food-search")
        }
        swipeAwaySheets()

        tabs.buttons["More"].tap()
        sleep(2)
        snap("26-patient-more")
        if app.buttons["Care Team"].exists || app.staticTexts["Care Team"].exists {
            app.staticTexts["Care Team"].firstMatch.tap()
            sleep(3)
            snap("27-patient-care-team")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        let vitals = app.buttons["Vitals"].firstMatch
        if vitals.waitForExistence(timeout: 3) || app.staticTexts["Vitals"].exists {
            (vitals.exists ? vitals : app.staticTexts["Vitals"].firstMatch).tap()
            sleep(3)
            snap("28-patient-vitals")
            let log = app.navigationBars["Vitals"].buttons["Log a reading"]
            if log.waitForExistence(timeout: 3) { log.tap() }
            if app.buttons["Blood pressure"].waitForExistence(timeout: 3) {
                app.buttons["Blood pressure"].tap()
                sleep(1)
                let systolic = app.textFields["Systolic in millimeters of mercury"]
                if systolic.waitForExistence(timeout: 3) {
                    systolic.tap()
                    systolic.typeText("185")
                    app.textFields["Diastolic in millimeters of mercury"].tap()
                    app.textFields["Diastolic in millimeters of mercury"].typeText("112")
                    let done = app.toolbars.buttons["Done"].firstMatch
                    if done.exists { done.tap() }  // the advice sits under the keyboard
                    sleep(1)
                    snap("29-patient-log-blood-pressure")  // crisis advice; cancelled, never saved
                }
                app.buttons["Cancel"].tap()
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        // A digestive condition, with its recipe ideas.
        let conditions = app.buttons["Conditions"].firstMatch
        if conditions.waitForExistence(timeout: 3) {
            conditions.tap()
            let ibd = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "IBD")).firstMatch
            if !ibd.waitForExistence(timeout: 3) { app.swipeUp() }
            if ibd.exists {
                ibd.tap()
                sleep(1)
                // Scroll until the first recipe is on screen, then a little more to show the list.
                // The row is one combined link element, so match on its label.
                let firstRecipe = app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label BEGINSWITH %@", "Chicken Meatballs")).firstMatch
                for _ in 0..<6 where !(firstRecipe.exists && firstRecipe.isHittable) { app.swipeUp() }
                app.swipeUp()
                sleep(1)
                snap("29b-condition-recipes")
            }
        }
    }

    func testDoctorScreens() throws {
        try requireBackend()
        signIn("doctor@nutravision.demo")
        let tabs = app.tabBars.firstMatch

        XCTAssertTrue(app.navigationBars["Patients"].waitForExistence(timeout: 20))
        sleep(4)
        snap("30-doctor-patients")

        let maria = app.staticTexts["Maria Lopez"].firstMatch
        if maria.waitForExistence(timeout: 5) {
            maria.tap()
            sleep(4)
            snap("31-doctor-patient-detail")
            app.swipeUp()
            sleep(1)
            snap("32-doctor-patient-detail-lower")
            app.buttons["Body"].tap()
            sleep(4)
            snap("34-doctor-patient-vitals")
            app.buttons["Notes"].tap()
            sleep(2)
            snap("35-doctor-patient-notes")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        let james = app.staticTexts["James Carter"].firstMatch
        if james.waitForExistence(timeout: 5) {
            james.tap()
            sleep(3)
            app.buttons["Body"].tap()
            sleep(4)
            snap("36-doctor-patient-blood-pressure")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        tabs.buttons["Requests"].tap()
        sleep(2)
        snap("33-doctor-requests")
    }

    // MARK: - helpers

    private func requireBackend() throws {
        guard ProcessInfo.processInfo.environment["DEMO_BACKEND"] == "1" else {
            throw XCTSkip("No seeded backend configured (DEMO_BACKEND != 1)")
        }
    }

    private func signIn(_ email: String) {
        XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 20))
        app.buttons["Sign in"].tap()
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(demoPassword)
        XCTAssertTrue(RelaunchTests.submitSignIn(in: app), "sign-in did not reach the tab bar, even after a retry")
        dismissSavePasswordPrompt()
    }

    /// Opens Search food from the Add menu, taps the sheet's Cancel and checks we're back on the
    /// Add menu. Logs the sheet's navigation bar so a failure shows what the button really is.
    private func checkAddFoodCancel() {
        app.buttons["Search food"].tap()
        let bar = app.navigationBars.matching(NSPredicate(format: "identifier BEGINSWITH 'Add to'")).firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "Add Food sheet did not open")
        print("ADDFOOD-DEBUG bar:\n\(bar.debugDescription)")
        let cancel = bar.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3), "No Cancel button in the Add Food bar")
        cancel.tap()
        let closed = app.buttons["Search food"].waitForExistence(timeout: 5) && !bar.exists
        snap("25a-after-add-food-cancel")
        XCTAssertTrue(closed, "Cancel did not close the Add Food sheet")
    }

    /// Drags open sheets down from the top until the tab bar is reachable again.
    private func swipeAwaySheets() {
        for _ in 0..<5 {
            let sheetOpen = app.navigationBars["Add"].exists
                || app.navigationBars.matching(NSPredicate(format: "identifier BEGINSWITH 'Add to'")).count > 0
                || app.searchFields.count > 0
            if !sheetOpen { return }
            let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            top.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
            sleep(1)
        }
    }

    /// iOS offers to save the password after a sign-in; the prompt covers the screen until dismissed.
    private func dismissSavePasswordPrompt() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            for owner in [app, springboard] where owner.buttons["Not Now"].exists {
                owner.buttons["Not Now"].tap()
                sleep(1)
                return
            }
            usleep(250_000)
        }
    }

    /// The Supabase session survives relaunches, so a previous test may leave the app signed in.
    /// Loading that session can stall for a minute or more when CI's simulator loses its connection
    /// to Supabase (see RelaunchTests). After 8s the loading screen offers Sign out, which clears the
    /// session on the device without waiting for the network, so use it when it shows.
    private func signOutIfNeeded() {
        let welcome = app.buttons["Create account"]
        let tabBar = app.tabBars.firstMatch
        let loadingSignOut = app.buttons["Sign out"]  // with no tab bar, only the loading screen has one
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline && !welcome.exists && !tabBar.exists && !loadingSignOut.exists { usleep(250_000) }
        if !welcome.exists && !tabBar.exists {
            snap("00-slow-launch-\(name.filter(\.isLetter))")
            print("LAUNCH-DEBUG no welcome or tabs after relaunch:\n\(app.debugDescription)")
        }
        if loadingSignOut.exists && !tabBar.exists {
            loadingSignOut.tap()
            XCTAssertTrue(welcome.waitForExistence(timeout: 10), "the loading screen's Sign out did not reach the welcome screen")
            return
        }
        guard tabBar.exists else { return }
        tabBar.buttons["More"].tap()
        let signOut = app.buttons["Sign out"]
        if !signOut.waitForExistence(timeout: 5) { app.swipeUp() }
        signOut.tap()
        XCTAssertTrue(welcome.waitForExistence(timeout: 15), "sign-out did not return to the welcome screen")
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
