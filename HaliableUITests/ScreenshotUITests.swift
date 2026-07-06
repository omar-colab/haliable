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
