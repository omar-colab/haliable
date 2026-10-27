//
//  IngredientCheckerUITests.swift
//  HaliableUITests
//
//  The ingredient checker works with no barcode, no network and no AI: type a
//  list on Home and the live check flags what the bundled rules flag, then the
//  full result opens.
//

import XCTest

final class IngredientCheckerUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testTypedListIsCheckedLive() throws {
        let app = XCUIApplication()
        app.launch()
        let open = app.buttons["home.checkIngredients"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()

        let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("sugar, pork gelatin, water")
        attach(app, "checker-live")
        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["Overall"].waitForExistence(timeout: 5), "typed text is trusted → overall grade shows")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'pork'")).firstMatch.exists,
                      "pork is flagged live")

        app.buttons["See the full result"].tap()
        let verdict = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Ingredients you checked'")).firstMatch
        XCTAssertTrue(verdict.waitForExistence(timeout: 8), "verdict opens after the checker closes")
        attach(app, "checker-verdict")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name; a.lifetime = .keepAlways
        add(a)
    }
}
