//
//  ScreenshotUITests.swift
//  HaliableUITests
//
//  Self-contained App Store screenshot capture (no fastlane snapshot dependency,
//  so the target always compiles). Drives the app through its main tabs and saves
//  each screen as a permanent XCTAttachment.
//
//  Run on a 6.9" simulator (iPhone 16/17 Pro Max → 1320×2868):
//    xcodebuild test -scheme Haliable \
//      -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
//      -only-testing:HaliableUITests/ScreenshotUITests -resultBundlePath screens.xcresult
//  Then extract:
//    xcrun xcresulttool export attachments --path screens.xcresult --output-path ./screenshots
//

import XCTest

final class ScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureMainScreens() {
        let app = XCUIApplication()
        app.launch()

        let home = app.buttons["dock.main"]
        guard home.waitForExistence(timeout: 8) else { return }
        capture(app, name: "01-Home")

        app.buttons["dock.find"].tap()
        dismissLocationAlert()
        capture(app, name: "02-Find")
        app.buttons["dock.reviews"].tap(); capture(app, name: "03-Reviews")
        app.buttons["dock.history"].tap(); capture(app, name: "04-History")
        app.buttons["dock.about"].tap(); capture(app, name: "05-About")

        // Verdict LAST, deliberately. It opens a sheet that is dismissed by dragging,
        // which is flaky — when the drag misses, every capture after it is the same
        // stuck sheet. Doing it last means a miss costs this one shot.
        home.tap()
        captureVerdict(app)
    }

    /// The standards picker on its own launch, so a missed sheet dismissal can't
    /// spoil the main set.
    func testCaptureStandardsPicker() {
        let app = XCUIApplication()
        app.launch()
        let pill = app.buttons["Halal standard: General Halal"]
        guard pill.waitForExistence(timeout: 8) else { return }
        pill.tap()
        Thread.sleep(forTimeInterval: 1.2)
        capture(app, name: "06-Standards")
    }

    /// A verdict is the app's whole point, so it belongs in the shot list. The camera
    /// can't scan in a simulator, so drive the manual-barcode path instead. The lookup is
    /// live (OpenFoodFacts/USDA), so this is best-effort: with no network the scan screen
    /// shows an error card and we capture that rather than failing the suite.
    private func captureVerdict(_ app: XCUIApplication) {
        let start = app.buttons["home.startScan"]
        guard start.waitForExistence(timeout: 5) else { return }
        start.tap()
        Thread.sleep(forTimeInterval: 1.2)
        capture(app, name: "01c-Scanning")

        let reveal = app.buttons["Enter barcode manually"]
        guard reveal.waitForExistence(timeout: 5) else { return }
        reveal.tap()

        let field = app.textFields["Barcode number"]
        guard field.waitForExistence(timeout: 3) else { return }
        field.tap()
        field.typeText("3017620422003")          // Nutella — long-standing OFF entry
        app.buttons["Look up barcode"].tap()

        // The verdict arrives as a sheet; wait for it, then let the reveal animate.
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 20)
        Thread.sleep(forTimeInterval: 2.5)
        capture(app, name: "01b-Verdict")
    }

    /// The Find tab triggers the system location prompt on first launch; it would
    /// otherwise sit on top of the map in the captured frame.
    private func dismissLocationAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 4) {
            allow.tap()
            // Let the map settle (permission grant kicks off a camera move).
            Thread.sleep(forTimeInterval: 3)
        }
    }

    private func capture(_ app: XCUIApplication, name: String) {
        // Brief settle so animations/content finish before the frame.
        _ = app.wait(for: .runningForeground, timeout: 2)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
