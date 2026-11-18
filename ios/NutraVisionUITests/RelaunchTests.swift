import XCTest

/// Reproduces the launch hang seen in the screen tour: relaunched while signed in, the app sometimes
/// stays on the loading spinner. Relaunches several times and, on a hang, keeps watching for 90s to
/// record whether it ever recovers (an error banner after ~60s would point at a stalled request).
final class RelaunchTests: XCTestCase {
    private let app = XCUIApplication()

    func testRelaunchWhileSignedIn() throws {
        guard ProcessInfo.processInfo.environment["DEMO_BACKEND"] == "1" else {
            throw XCTSkip("No seeded backend configured (DEMO_BACKEND != 1)")
        }
        continueAfterFailure = true
        app.launch()
        let tabBar = app.tabBars.firstMatch
        let welcome = app.buttons["Create account"]
        _ = tabBar.waitForExistence(timeout: 20) || welcome.waitForExistence(timeout: 1)
        if !tabBar.exists { signInAsMaria() }
        // Without a session every relaunch lands on the welcome screen, which would read as a hang.
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("could not sign in, even after a retry")
            return
        }

        for attempt in 1...15 {
            print("RELAUNCH-DEBUG attempt \(attempt): launching at \(Self.clock())")
            app.launch()  // terminates and relaunches with the stored session
            let started = Date()
            print("RELAUNCH-DEBUG attempt \(attempt): launch returned at \(Self.clock())")
            if !tabBar.waitForExistence(timeout: 3) {
                // Slow start: record what is on screen, then keep waiting.
                print("RELAUNCH-DEBUG attempt \(attempt): no tabs at \(Self.clock()), on screen:\n\(app.debugDescription)")
            }
            if tabBar.waitForExistence(timeout: 12) {
                print("RELAUNCH-DEBUG attempt \(attempt): tabs after \(Int(Date().timeIntervalSince(started)))s at \(Self.clock())")
                continue
            }
            snap("relaunch-\(attempt)-stuck")
            var outcome = "still loading after 90s"
            while Date().timeIntervalSince(started) < 90 {
                if tabBar.exists { outcome = "tabs appeared"; break }
                if welcome.exists { outcome = "signed out (welcome screen)"; break }
                if app.buttons["Retry"].exists { outcome = "error banner appeared"; break }
                sleep(1)
            }
            let seconds = Int(Date().timeIntervalSince(started))
            snap("relaunch-\(attempt)-after-\(seconds)s")
            print("RELAUNCH-DEBUG attempt \(attempt): \(outcome) at \(seconds)s\n\(app.debugDescription)")
            XCTFail("Relaunch \(attempt) hung on the loading screen: \(outcome) at \(seconds)s")
            break
        }
    }

    /// Wall-clock time in UTC, to line up with the app's unified log.
    private static func clock() -> String {
        let format = DateFormatter()
        format.dateFormat = "HH:mm:ss.SSS"
        format.timeZone = TimeZone(identifier: "UTC")
        return format.string(from: Date())
    }

    private func signInAsMaria() {
        app.buttons["Sign in"].tap()
        let email = app.textFields["Email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("maria@nutravision.demo")  // supabase/seed.sql
        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("demo1234")
        XCTAssertTrue(Self.submitSignIn(in: app), "sign-in did not reach the tab bar, even after a retry")
    }

    /// Taps the sign-in form's button and waits for the tab bar, retrying once if the request fails.
    /// CI's simulator sometimes loses its TLS connection to Supabase (NSURLErrorDomain -1200), and
    /// a failed request can take up to iOS's 60s timeout to report. While the request runs, the form's
    /// button shows a spinner instead of "Sign in", so wait past that timeout before tapping again.
    static func submitSignIn(in app: XCUIApplication) -> Bool {
        let tabBar = app.tabBars.firstMatch
        for attempt in 1...2 {
            app.buttons.matching(identifier: "Sign in").allElementsBoundByIndex.last?.tap()
            if tabBar.waitForExistence(timeout: 70) { return true }
            print("SIGNIN-DEBUG attempt \(attempt) failed")
        }
        return false
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
