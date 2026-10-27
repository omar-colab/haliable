//
//  VerdictShareCardTests.swift
//  The share image renders at 9:16 Story size.
//

import XCTest
import SwiftUI
@testable import Haliable

@MainActor
final class VerdictShareCardTests: XCTestCase {
    func testCardRendersAtStorySize() {
        let product = Product(id: "1", name: "Gummies", brand: "Acme",
                              rawIngredientsText: "sugar, gelatin", additivesENumbers: [])
        let verdict = RulesEngine().evaluate(product: product)
        let renderer = ImageRenderer(content: VerdictShareCard(verdict: verdict, standard: .general))
        renderer.scale = 1
        let image = renderer.uiImage
        XCTAssertEqual(image?.size, CGSize(width: 1080, height: 1920))
    }

    func testDisplayBrandDropsBrandThatRepeatsTheName() {
        func brand(_ name: String, _ brand: String?) -> String? {
            Product(id: "1", name: name, brand: brand, rawIngredientsText: nil, additivesENumbers: []).displayBrand
        }
        XCTAssertEqual(brand("Nutella", "Nutella, Ferrero"), "Ferrero")
        XCTAssertNil(brand("Nutella", "nutella"))
        XCTAssertNil(brand("Nutella", nil))
        XCTAssertEqual(brand("Gummies", "Acme"), "Acme")
    }
}
