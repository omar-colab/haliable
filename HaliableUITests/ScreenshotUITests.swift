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

        capture(app, name: "01-Scan")

        let tabs = app.tabBars.buttons
        guard tabs.count >= 4 else { return }
        tabs.element(boundBy: 1).tap()
        dismissLocationAlert()
        capture(app, name: "02-Find")
        tabs.element(boundBy: 2).tap(); capture(app, name: "03-Reviews")
        tabs.element(boundBy: 3).tap(); capture(app, name: "04-History")
        if tabs.count >= 5 {
            tabs.element(boundBy: 4).tap(); capture(app, name: "05-About")
        }

        // Verdict LAST, deliberately. It opens a sheet that has no close button and is
        // dismissed by dragging, which is flaky — when the drag misses, every capture
        // after it is the same stuck sheet. Doing it last means a miss costs this one
        // shot instead of silently corrupting the whole set.
        tabs.element(boundBy: 0).tap()
        captureVerdict(app)
    }

    /// A verdict is the app's whole point, so it belongs in the shot list. The camera
    /// can't scan in a simulator, so drive the manual-barcode path instead. The lookup is
    /// live (OpenFoodFacts/USDA), so this is best-effort: with no network the scan screen
    /// shows an error card and we capture that rather than failing the suite.
    private func captureVerdict(_ app: XCUIApplication) {
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
        Thread.sleep(forTimeInterval: 2)
        capture(app, name: "01b-Verdict")

        // The verdict sheet has no close button by design — it's dismissed by dragging it
        // down. Without this the sheet stays up and every later capture is the same frame.
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
            .press(forDuration: 0.1,
                   thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        Thread.sleep(forTimeInterval: 1.5)
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
