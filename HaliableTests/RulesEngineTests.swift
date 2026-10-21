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
        XCTAssertEqual(pv.clearedScore, 0)                   // haram → 0, not 1-of-3
        let doubtful = ProductVerdict(product: pv.product, matched: Array(pv.matched.prefix(2)), overallGrade: .mashboohContested)
        XCTAssertEqual(doubtful.clearedScore, 50)            // 1 of 2 cleared
        let empty = ProductVerdict(product: pv.product, matched: [], overallGrade: .halal)
        XCTAssertEqual(empty.clearedScore, 100)
    }

    // The History score counts the whole label, so one flagged item in four is 75.
    func testClearedScoreUsesWholeLabel() {
        XCTAssertEqual(ProductVerdict.ingredientCount("Flour, sugar, gelatin (beef, pork); water."), 4)
        XCTAssertEqual(ProductVerdict.ingredientCount("  "), 0)
        let pv = ProductVerdict(
            product: Product(id: "1", name: "P", brand: nil,
                             rawIngredientsText: "flour, sugar, gelatin, water", additivesENumbers: []),
            matched: [MatchedIngredient(originalText: "gelatin", matchedRule: nil)],
            overallGrade: .mashboohContested)
        XCTAssertEqual(pv.clearedScore, 75)
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

    // MARK: - Gum (TestFlight feedback, Oct 17)

    /// OFF sub-variant tags collapse to the base code the tables key on, once each.
    func testENumberSubVariantsNormalizeAndDedupe() {
        XCTAssertEqual(
            RulesEngine.normalizedENumbers(["en:e322", "en:e322i", "en:e472e", "en:e150d", "en:e1442", "E471"]),
            ["E322", "E472", "E150", "E1442", "E471"])
        XCTAssertEqual(RulesEngine.normalizeENumber("en:e500ii"), "E500")
        XCTAssertEqual(RulesEngine.normalizeENumber("not-an-e-number"), "NOT-AN-E-NUMBER")
    }

    /// Extra Spearmint (022000112484), its real Open Food Facts record. Before the
    /// fix, soy lecithin arrived as E322 AND as an unknown "E322I" (Questionable).
    /// After: lecithin once, resolved to plant (halal). The product is STILL
    /// Questionable — glycerol and natural flavors are cited, owner-approved
    /// contested cells — and that must not change without a citation (rule 3).
    func testGumLecithinResolvesOnceAndCitedDriversRemain() {
        let gum = Product(id: "022000112484", name: "Spearmint sugar free gum", brand: "Extra",
            rawIngredientsText: "Sorbitol, gum base, glycerol, natural and artificial flavors, less than 2% of: hydrogenated starch hydrolysate, aspartame, mannitol, acesulfame k, soy lecithin, bht (to maintain freshness), colors (turmeric, blue 1 lake).",
            additivesENumbers: ["en:e133", "en:e321", "en:e322", "en:e322i", "en:e420", "en:e421", "en:e422", "en:e950", "en:e951"])
        let verdict = RulesEngine().evaluate(product: gum, standard: .general)

        XCTAssertFalse(verdict.matched.contains { $0.originalText.uppercased().contains("E322I") })
        let lecithin = verdict.matched.filter { $0.matchedRule?.id == "lecithin" }
        XCTAssertEqual(lecithin.count, 1)
        XCTAssertEqual(lecithin.first?.grade, .halal)

        let ids = Set(verdict.matched.compactMap(\.matchedRule?.id))
        XCTAssertTrue(ids.contains("glycerin"))
        XCTAssertTrue(ids.contains("natural-flavors"))
        XCTAssertEqual(verdict.overallGrade, .mashboohContested)
    }

    /// Naming an additive (e-numbers.json) is display only: an uncited additive
    /// still grades Questionable and is never silently Halal.
    func testNamedButUncitedAdditiveStaysQuestionable() {
        let p = Product(id: "3", name: "P", brand: nil, rawIngredientsText: "sorbitol",
                        additivesENumbers: ["en:e420"])
        let item = RulesEngine().evaluate(product: p).matched.first { $0.originalText.hasPrefix("E420") }
        XCTAssertEqual(item?.originalText, "E420 (sorbitol)")
        XCTAssertEqual(item?.verdict, .doubtful)
    }
}
