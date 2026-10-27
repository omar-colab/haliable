//
//  MapUITests.swift
//  HaliableUITests
//
//  Smoke test for the Find map: it opens and, near Manhattan (set the
//  simulator's location first), shows places. Network-dependent, so it only
//  attaches a screenshot instead of asserting a pin count.
//

import XCTest

final class MapUITests: XCTestCase {
    func testFindMapOpens() throws {
        let app = XCUIApplication()
        app.launch()
        let find = app.buttons["dock.find"]
        XCTAssertTrue(find.waitForExistence(timeout: 10))
        find.tap()
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 3) { alert.buttons.element(boundBy: 1).tap() }
        Thread.sleep(forTimeInterval: 12)   // Atlas + OpenStreetMap + Apple Maps
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "find-map"; shot.lifetime = .keepAlways
        add(shot)
    }
}
