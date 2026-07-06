//
//  GradingBehaviorTests.swift
//  HaliableTests
//
//  Phase 5 — behavioral coverage of the seeded grading model and the
//  certification overlay. These assert the DESIGN (divergence exists, origin
//  upgrades, overlay is haram-guarded), not specific draft fiqh numbers beyond
//  the spec's named anchor cases.
//

import XCTest
@testable import Haliable

final class GradingBehaviorTests: XCTestCase {

    private func makeRule(id: String, ingredient: String,
                          eNumber: String? = nil, verdict: Verdict = .doubtful) -> IngredientRule {
        IngredientRule(id: id, ingredient: ingredient, aliases: [ingredient.lowercased()],
                       eNumber: eNumber, verdict: verdict, reason: "",
                       source: Source(body: "X", title: "Y", url: "https://a", year: 2024))
    }

    // MARK: Per-standard divergence

    /// Carmine (E120): widely disapproved (4) for most, softened to safe (2) under lenient.
    func testCarmineDivergesByStandard() {
        let carmine = makeRule(id: "carmine", ingredient: "Carmine", eNumber: "E120")
        let general = MatchedIngredient(originalText: "carmine", matchedRule: carmine, standard: .general)
        let lenient = MatchedIngredient(originalText: "carmine", matchedRule: carmine, standard: .lenient)
        XCTAssertEqual(general.grade, .mashboohDisapproved)  // 4
        XCTAssertEqual(lenient.grade, .mashboohSafe)         // 2
        XCTAssertNotEqual(general.grade, lenient.grade)
    }

    /// Vanilla extract: contested (3) under general, disapproved (4) under zabiha.
    func testVanillaExtractDivergesByStandard() {
        let vanilla = makeRule(id: "vanilla-extract", ingredient: "Vanilla extract")
        let general = MatchedIngredient(originalText: "vanilla extract", matchedRule: vanilla, standard: .general)
        let zabiha  = MatchedIngredient(originalText: "vanilla extract", matchedRule: vanilla, standard: .zabiha)
        XCTAssertEqual(general.grade, .mashboohContested)    // 3
        XCTAssertEqual(zabiha.grade, .mashboohDisapproved)   // 4
    }

    // MARK: Phase 5 — full four-position divergence (one product, all positions)

    /// Helper: grade one rule across every position in a fixed strict→lenient order.
    private func gradesAcrossPositions(_ rule: IngredientRule, text: String) -> [GradeLevel] {
        [HalalStandard.zabiha, .hanafiStrict, .general, .lenient].map {
            MatchedIngredient(originalText: text, matchedRule: rule, standard: $0).grade
        }
    }

    /// Vanilla extract diverges 4 / 4 / 3 / 2 across zabiha · hanafiStrict · general · lenient.
    func testVanillaExtractDivergesAcrossAllFourPositions() {
        let vanilla = makeRule(id: "vanilla-extract", ingredient: "Vanilla extract")
        let grades = gradesAcrossPositions(vanilla, text: "vanilla extract")
        XCTAssertEqual(grades, [.mashboohDisapproved, .mashboohDisapproved,
                                .mashboohContested, .mashboohSafe])  // 4,4,3,2
    }

    /// Carmine (E120) diverges 4 / 4 / 4 / 2 across the four positions.
    func testCarmineDivergesAcrossAllFourPositions() {
        let carmine = makeRule(id: "carmine", ingredient: "Carmine", eNumber: "E120")
        let grades = gradesAcrossPositions(carmine, text: "carmine")
        XCTAssertEqual(grades, [.mashboohDisapproved, .mashboohDisapproved,
                                .mashboohDisapproved, .mashboohSafe])  // 4,4,4,2
    }

    // MARK: Phase 5 — fail-safes on seeded data

    /// Porcine is Haram under ALL four positions — the hard-haram pin, no softening.
    func testPorcineHaramUnderAllPositions() {
        for standard in HalalStandard.allCases {
            let pork = MatchedIngredient(originalText: "pork gelatin", matchedRule: nil, standard: standard)
            XCTAssertEqual(pork.grade, .haram, "porcine must be Haram under \(standard)")
        }
    }

    /// An unspecified-origin additive never resolves to Halal under any position —
    /// now exercised on a SEEDED row (E471, 4/4/3/3), not just the empty matrix.
    func testUnspecifiedAdditiveNeverHalalOnSeededData() {
        let e471 = makeRule(id: "mono-diglycerides", ingredient: "Mono- and diglycerides", eNumber: "E471")
        // Hermetic: assert the SEEDED (uncited) draft state, independent of whatever
        // real citations the pipeline has since committed to the bundled Citations.json.
        withCitationStore(CitationStore(cells: [], certifiers: [])) {
            for standard in HalalStandard.allCases {
                let item = MatchedIngredient(originalText: "mono- and diglycerides", matchedRule: e471, standard: standard)
                XCTAssertNotEqual(item.grade, .halal, "E471 (unspecified) must not be Halal under \(standard)")
                XCTAssertTrue(item.needsReview, "seeded E471 cell is a draft pending review")
            }
        }
    }

    /// Certification overlay upgrade PATH: the same Questionable product becomes
    /// Halal once a satisfying certifier is present on the label.
    func testCertOverlayUpgradePathOnceCertPresent() {
        let engine = RulesEngine()
        let uncertified = Product(id: "u", name: "X", brand: nil,
                                  rawIngredientsText: "mono- and diglycerides", additivesENumbers: ["E471"])
        let certified = Product(id: "c", name: "X", brand: nil,
                                rawIngredientsText: "mono- and diglycerides",
                                additivesENumbers: ["E471"], labels: ["en:ifanca"])
        withCitationStore(CitationStore(certifiers: [certEntry("ifanca", "general")])) {
            // No cert label → stays Questionable; IFANCA cited for general → upgrades to Halal.
            XCTAssertNotEqual(engine.evaluate(product: uncertified, standard: .general).overallGrade, .halal)
            XCTAssertEqual(engine.evaluate(product: certified, standard: .general).overallGrade, .halal)
        }
    }

    // MARK: Origin

    /// A named plant origin ("soy lecithin") upgrades to Halal; unspecified does not.
    func testNamedOriginUpgradesLecithin() {
        let lecithin = makeRule(id: "lecithin", ingredient: "Lecithin", eNumber: "E322", verdict: .halal)
        let soy   = MatchedIngredient(originalText: "soy lecithin", matchedRule: lecithin, standard: .general)
        let plain = MatchedIngredient(originalText: "lecithin", matchedRule: lecithin, standard: .general)
        XCTAssertEqual(soy.grade, .halal)            // named plant → 1
        XCTAssertEqual(plain.grade, .mashboohSafe)   // unspecified → 2, never Halal
        XCTAssertNotEqual(plain.grade, .halal)
    }

    /// An unspecified-origin contested additive never resolves to Halal, any standard.
    func testUnspecifiedContestedNeverHalal() {
        let glycerin = makeRule(id: "glycerin", ingredient: "Glycerin", eNumber: "E422")
        for standard in HalalStandard.allCases {
            let item = MatchedIngredient(originalText: "glycerin", matchedRule: glycerin, standard: standard)
            XCTAssertNotEqual(item.grade, .halal, "glycerin must not be Halal under \(standard)")
        }
    }

    // MARK: Worst-case rollup

    /// One haram ingredient forces the whole product to Haram.
    func testWorstCaseRollupForcesHaram() {
        let engine = RulesEngine()
        let product = Product(id: "1", name: "P", brand: nil,
                              rawIngredientsText: "lard, soy lecithin", additivesENumbers: [])
        XCTAssertEqual(engine.evaluate(product: product, standard: .general).overallGrade, .haram)
    }

    // MARK: Certification overlay (now citation-gated — Protocol §8)

    /// Run a block with an injected CitationStore, then restore the shared one.
    private func withCitationStore(_ store: CitationStore, _ body: () -> Void) {
        let saved = CitationStore.shared
        CitationStore.shared = store
        defer { CitationStore.shared = saved }
        body()
    }

    private func certEntry(_ body: String, _ position: String) -> CertifierCitationEntry {
        CertifierCitationEntry(body: body, position: position, citations: [
            Citation(sourceName: "\(body.uppercased()) recognition list",
                     reference: "https://example.org/\(body)/\(position)", date: "2024",
                     tier: .standardBody, paraphrase: "Body's published recognition for this position.")
        ])
    }

    /// With NO citation on file, the overlay does NOT upgrade — an uncited
    /// satisfaction claim can't produce a confident Halal (everything stays pending).
    func testCertOverlayDoesNotUpgradeWithoutCitation() {
        let engine = RulesEngine()
        let certified = Product(id: "2", name: "X", brand: nil, rawIngredientsText: "lecithin",
                                additivesENumbers: [], labels: ["en:hmc"])
        // Hermetic empty store → HMC/zabiha is uncited → stays Questionable. (Does not
        // depend on the bundled Citations.json, which the pipeline now populates.)
        withCitationStore(CitationStore(cells: [], certifiers: [])) {
            XCTAssertEqual(engine.evaluate(product: certified, standard: .zabiha).overallGrade, .mashboohSafe)
        }
    }

    /// Once the body's satisfaction of the standard is CITED, the overlay upgrades
    /// a non-haram product to Halal.
    func testCertOverlayUpgradesWhenSatisfactionCited() {
        let engine = RulesEngine()
        let certified = Product(id: "2", name: "X", brand: nil, rawIngredientsText: "lecithin",
                                additivesENumbers: [], labels: ["en:hmc"])
        let uncertified = Product(id: "3", name: "X", brand: nil, rawIngredientsText: "lecithin",
                                  additivesENumbers: [])
        withCitationStore(CitationStore(certifiers: [certEntry("hmc", "zabiha")])) {
            XCTAssertEqual(engine.evaluate(product: certified, standard: .zabiha).overallGrade, .halal)
            // No cert label → no claim → stays Questionable (lecithin unspecified = 2).
            XCTAssertEqual(engine.evaluate(product: uncertified, standard: .zabiha).overallGrade, .mashboohSafe)
        }
    }

    /// The overlay never upgrades past a haram ingredient, cited or not.
    func testCertOverlayNeverUpgradesHaram() {
        let engine = RulesEngine()
        let product = Product(id: "4", name: "X", brand: nil, rawIngredientsText: "lard",
                              additivesENumbers: [], labels: ["en:hmc"])
        withCitationStore(CitationStore(certifiers: [certEntry("hmc", "zabiha")])) {
            XCTAssertEqual(engine.evaluate(product: product, standard: .zabiha).overallGrade, .haram)
        }
    }

    /// The overlay only fires for the cited (body, standard) pairing: IFANCA cited
    /// for general upgrades general, but not zabiha (which it doesn't satisfy / isn't cited).
    func testCertOverlayRespectsCitedPairing() {
        let engine = RulesEngine()
        let product = Product(id: "5", name: "X", brand: nil, rawIngredientsText: "lecithin",
                              additivesENumbers: [], labels: ["en:ifanca"])
        withCitationStore(CitationStore(certifiers: [certEntry("ifanca", "general")])) {
            XCTAssertEqual(engine.evaluate(product: product, standard: .general).overallGrade, .halal)
            XCTAssertEqual(engine.evaluate(product: product, standard: .zabiha).overallGrade, .mashboohSafe)
        }
    }

    // MARK: Multi-word origin capture (segment-based)

    /// An origin qualifier ANYWHERE in the ingredient's list-segment resolves —
    /// before the term, after it, or inside parentheses.
    func testMultiWordOriginCapture() {
        let engine = RulesEngine()
        let labels = [
            "lecithin (soya)",
            "emulsifier: lecithin from soybeans",
            "sunflower lecithin",
            "water, sugar, soy lecithin, salt",
        ]
        for text in labels {
            let product = Product(id: "x", name: "X", brand: nil,
                                  rawIngredientsText: text, additivesENumbers: [])
            let pv = engine.evaluate(product: product, standard: .general)
            let lecithin = pv.matched.first { $0.matchedRule?.id == "lecithin" }
            XCTAssertEqual(lecithin?.grade, .halal,
                           "named plant origin in '\(text)' should upgrade lecithin to Halal")
        }
    }

    /// A qualifier on a DIFFERENT ingredient must not bleed across segments.
    func testOriginDoesNotBleedAcrossSegments() {
        let engine = RulesEngine()
        // "soy" qualifies lecithin, NOT gelatin — gelatin stays unspecified (zabiha haram).
        let product = Product(id: "y", name: "X", brand: nil,
                              rawIngredientsText: "soy lecithin, gelatin", additivesENumbers: [])
        let pv = engine.evaluate(product: product, standard: .zabiha)
        let gelatin = pv.matched.first { $0.matchedRule?.id == "gelatin" }
        XCTAssertEqual(gelatin?.grade, .haram, "unqualified gelatin under zabiha stays haram")
    }
}
