//
//  LabelTextReaderTests.swift
//  The "read the label instead" path: section trimming, the too-little-text
//  gate, and one real Vision read of a rendered label.
//

import XCTest
import UIKit
@testable import Haliable

final class LabelTextReaderTests: XCTestCase {

    func testKeepsTextFromIngredientsOn() {
        let ocr = "Nutrition Facts\nCalories 140\nINGREDIENTS: SUGAR, CORN SYRUP,\nGELATIN, CITRIC ACID\n"
        XCTAssertEqual(LabelTextReader.ingredientsSection(of: ocr), "INGREDIENTS: SUGAR, CORN SYRUP, GELATIN, CITRIC ACID")
    }

    func testStopsWhereThePanelOrAddressStarts() {
        let ocr = "INGREDIENTS: SUGAR, GELATIN, CITRIC ACID.\nDistributed by Acme Inc, Chicago IL\nNutrition Facts\nCalories 90"
        XCTAssertEqual(LabelTextReader.ingredientsSection(of: ocr), "INGREDIENTS: SUGAR, GELATIN, CITRIC ACID.")
        XCTAssertFalse(RulesEngine.looksIncomplete(LabelTextReader.ingredientsSection(of: ocr)))
    }

    func testWithoutTheWordKeepsEverything() {
        XCTAssertEqual(LabelTextReader.ingredientsSection(of: "sugar, gelatin\ncitric acid"), "sugar, gelatin citric acid")
    }

    func testFragmentsAskForARetake() {
        XCTAssertFalse(LabelTextReader.looksLikeAnIngredientList("GELATIN"))
        XCTAssertFalse(LabelTextReader.looksLikeAnIngredientList("Net wt 5 oz"))
        XCTAssertTrue(LabelTextReader.looksLikeAnIngredientList("Ingredients: sugar, corn syrup, gelatin"))
    }

    /// The point of the feature: a gelatin label read from a photo is flagged,
    /// never cleared.
    func testRenderedLabelIsReadAndFlagged() async throws {
        let label = "INGREDIENTS: SUGAR, CORN SYRUP, GELATIN, CITRIC ACID"
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1400, height: 160)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1400, height: 160))
            (label as NSString).draw(at: CGPoint(x: 20, y: 50),
                                     withAttributes: [.font: UIFont.systemFont(ofSize: 44, weight: .semibold),
                                                      .foregroundColor: UIColor.black])
        }
        let text = try await LabelTextReader.read(image)
        XCTAssertTrue(text.lowercased().contains("gelatin"), "read: \(text)")

        let product = Product(id: "label-test", name: "Ingredients from your photo", brand: nil,
                              rawIngredientsText: text, additivesENumbers: [])
        let verdict = RulesEngine().evaluate(product: product)
        XCTAssertNotEqual(verdict.overall, .halal)
    }

    func testFrenchLabelIsReadWithAccents() async throws {
        let label = "INGRÉDIENTS : SUCRE, GÉLATINE DE PORC, ARÔMES"
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1500, height: 160)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1500, height: 160))
            (label as NSString).draw(at: CGPoint(x: 20, y: 50),
                                     withAttributes: [.font: UIFont.systemFont(ofSize: 44, weight: .semibold),
                                                      .foregroundColor: UIColor.black])
        }
        let text = try await LabelTextReader.read(image)
        let product = Product(id: "label-fr", name: "x", brand: nil, rawIngredientsText: text, additivesENumbers: [])
        XCTAssertEqual(RulesEngine().evaluate(product: product).overallGrade, .haram, "read: \(text)")
    }
}
