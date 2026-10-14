//
//  RulesEngineTests.swift
//  HaliableTests
//
//  Guards the product's soul: ambiguous or unverifiable input must NEVER be
//  reported as Halal. These tests don't depend on the bundled rules JSON.
//

import XCTest
@testable import Haliable

final class RulesEngineTests: XCTestCase {

    // An ingredient we don't have a rule for falls to Questionable, not Halal.
    func testUnknownIngredientIsQuestionable() {
        let item = MatchedIngredient(originalText: "mystery additive", matchedRule: nil)
        XCTAssertEqual(item.verdict, .doubtful)
        XCTAssertFalse(item.explanation.isEmpty)
    }

    // A product with NO ingredient data cannot be confirmed halal.
    func testNoIngredientDataYieldsQuestionable() {
        let engine = RulesEngine()
        let blank = Product(id: "000", name: "Unknown", brand: nil,
                            rawIngredientsText: nil, additivesENumbers: [])
        XCTAssertEqual(engine.evaluate(product: blank).overall, .doubtful)
    }

    // Worst-case ordering: haram outranks Questionable outranks Halal.
    func testSeverityOrdering() {
        XCTAssertGreaterThan(Verdict.haram.severity, Verdict.doubtful.severity)
        XCTAssertGreaterThan(Verdict.doubtful.severity, Verdict.halal.severity)
    }

    // The flagged list drops halal items and sorts worst-first.
    func testFlaggedExcludesHalalAndSortsWorstFirst() {
        let haramRule = IngredientRule(id: "h", ingredient: "Lard", aliases: [], eNumber: nil,
            verdict: .haram, reason: "pork", source: Source(body: "X", title: "Y", url: "https://a", year: 2024))
        let halalRule = IngredientRule(id: "l", ingredient: "Lecithin", aliases: [], eNumber: nil,
            verdict: .halal, reason: "plant", source: Source(body: "X", title: "Y", url: "https://a", year: 2024))
        let pv = ProductVerdict(
            product: Product(id: "1", name: "P", brand: nil, rawIngredientsText: "x", additivesENumbers: []),
            matched: [
                MatchedIngredient(originalText: "lecithin", matchedRule: halalRule),
                MatchedIngredient(originalText: "unknown", matchedRule: nil),  // questionable
                MatchedIngredient(originalText: "lard", matchedRule: haramRule)
            ],
            overallGrade: .haram
        )
        XCTAssertEqual(pv.flagged.count, 2)                  // halal lecithin excluded
        XCTAssertEqual(pv.flagged.first?.verdict, .haram)    // worst first
    }

    func testQuestionableDisplayName() {
        XCTAssertEqual(Verdict.doubtful.displayName, "Questionable")
    }

    // Regression: aliases matched as bare substrings, so "rum" (wine rule) fired
    // inside French "lactoserum" and Nutella (3017620422003, its real OFF text)
    // came out haram for wine.
    func testAliasDoesNotMatchInsideAnotherWord() {
        let nutella = Product(id: "3017620422003", name: "Nutella", brand: "Ferrero",
            rawIngredientsText: "Sucre, huile de palme, NOISETTES 13%, cacao maigre 7,4%, LAIT écrémé en poudre 6,6%, LACTOSERUM en poudre, émulsifiants: lécithines [SOJA), vanilline. Sans gluten.",
            additivesENumbers: [])
        let ids = RulesEngine().evaluate(product: nutella).matched.compactMap(\.matchedRule?.id)
        XCTAssertFalse(ids.contains("wine"))
        XCTAssertFalse(RulesEngine.mentions("ham", in: "graham flour, champignons"))
    }

    // Safety: anchoring only the word START keeps prefix forms matching, and the
    // flagged segment is the real one, not an earlier substring hit.
    func testAliasStillMatchesAtWordStart() {
        let p = Product(id: "2", name: "P", brand: nil,
            rawIngredientsText: "graham flour, lardons fumés, smoked ham", additivesENumbers: [])
        let matched = RulesEngine().evaluate(product: p).matched
        XCTAssertTrue(matched.contains { $0.matchedRule?.id == "lard" })
        XCTAssertEqual(matched.first { $0.matchedRule?.id == "pork" }?.originalText, "smoked ham")
    }
}
