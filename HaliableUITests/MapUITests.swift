//
//  MapUITests.swift
//  HaliableUITests
//
//  The Find map opens on Connecticut and its bundled places show without any
//  network or keys: a place opens to its card with hours/directions, and its
//  menu when the place has one online.
//

import XCTest

final class MapUITests: XCTestCase {
    func testFindMapShowsConnecticutPlaces() throws {
        let app = XCUIApplication()
        app.launch()
        let find = app.buttons["dock.find"]
        XCTAssertTrue(find.waitForExistence(timeout: 10))
        find.tap()
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 3) { alert.buttons.element(boundBy: 1).tap() }

        let count = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'in view'")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        XCTAssertFalse(count.label.hasPrefix("0 "), count.label)

        app.buttons["List"].firstMatch.tap()
        let first = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Hours, photos'")).firstMatch.waitForExistence(timeout: 5))

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "find-place"; shot.lifetime = .keepAlways
        add(shot)
    }
}
