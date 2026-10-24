//
//  IngredientCheckerTests.swift
//  HaliableTests
//
//  Real-label parsing and matching: the shapes Open Food Facts and USDA text
//  actually arrive in. Every test here guards one of two failures — a concern
//  the label names that we miss (false Halal), or a word that isn't the concern
//  at all (false Haram).
//

import XCTest
@testable import Haliable

final class IngredientCheckerTests: XCTestCase {

    private static let engine = RulesEngine()

    private func verdict(_ text: String, eNumbers: [String] = [], tags: [String] = [],
                         standard: HalalStandard = .general) -> ProductVerdict {
        Self.engine.evaluate(product: Product(id: "t", name: "T", brand: nil, rawIngredientsText: text,
                                              additivesENumbers: eNumbers, ingredientTags: tags),
                             standard: standard)
    }
    private func ids(_ v: ProductVerdict) -> Set<String> { Set(v.matched.compactMap(\.matchedRule?.id)) }
    private func item(_ v: ProductVerdict, _ id: String) -> MatchedIngredient? {
        v.matched.first { $0.matchedRule?.id == id }
    }

    // MARK: - Normalization

    func testENumberSpellingsCollapse() {
        let n = IngredientParser.normalize("E 471, E-472e, INS 322(i), e471i, E\u{2011}120, emulsifier (476, 442)")
        XCTAssertEqual(n, "e471, e472, e322, e471, e120, emulsifier (e476, e442)")
        // Not an additive: quantities and vitamin E.
        XCTAssertEqual(IngredientParser.normalize("vitamin e 400 iu, sugar 471g"), "vitamin e 400 iu, sugar 471g")
    }

    func testAccentsDashesQuotesBracketsAndOCR() {
        XCTAssertEqual(IngredientParser.normalize("GÉLATINE [BŒUF}, confectioner’s glaze, ge1atin, c0chineal"),
                       "gelatine (bœuf), confectioner's glaze, gelatin, cochineal")
    }

    func testParseNestsAndSplitsAllergenStatements() {
        let items = IngredientParser.parse(IngredientParser.normalize(
            "Chocolate (sugar, cocoa butter, soy lecithin), gelatin (beef). CONTAINS: MILK, SOY."))
        XCTAssertEqual(items.first?.own, "chocolate")
        XCTAssertEqual(items.first?.children.map(\.own), ["sugar", "cocoa butter", "soy lecithin"])
        XCTAssertEqual(items[1].fullText, "gelatin (beef)")
        XCTAssertTrue(items.contains { $0.own == "soy" })   // its own item, not gelatin's
    }

    func testUnbalancedBracketsDoNotLeakIntoDriverText() {
        // HANDOFF sweep: the driver string read "enzymes]".
        let v = verdict("Cheese (milk, salt, enzymes]), whey")
        XCTAssertEqual(item(v, "rennet")?.originalText, "enzymes")
        XCTAssertFalse(v.matched.contains { $0.originalText.contains("]") || $0.originalText.contains(")") })
    }

    // MARK: - Origin attaches to the right ingredient

    /// A plant word next to gelatin in the same list item must not make the gelatin plant.
    func testPlantWordOnlyResolvesItsOwnPhrase() {
        let v = verdict("sugar, gelatin and soy lecithin")
        XCTAssertEqual(item(v, "gelatin")?.resolvedOrigin, .unspecified)
        XCTAssertNotEqual(item(v, "gelatin")?.grade, .halal)
        XCTAssertEqual(item(v, "lecithin")?.grade, .halal)
    }

    func testAllergenStatementSoyDoesNotResolveGelatin() {
        let v = verdict("sugar, gelatin\nCONTAINS: SOY")
        XCTAssertNotEqual(item(v, "gelatin")?.grade, .halal)
    }

    func testParentheticalSourcesTakeTheStrictest() {
        XCTAssertEqual(verdict("gelatin (beef, pork)").overallGrade, .haram)
        XCTAssertEqual(verdict("gelatin (beef and/or porcine)").overallGrade, .haram)
        XCTAssertEqual(item(verdict("gelatin (beef)"), "gelatin")?.resolvedOrigin, .animalNonZabiha)
        // "and/or beef" may be beef: never softer than an undisclosed source.
        XCTAssertGreaterThanOrEqual(verdict("mono- and diglycerides (from soybean and/or beef tallow)").overallGrade,
                                    verdict("mono and diglycerides").overallGrade)
    }

    /// The same concern twice: the worse mention decides.
    func testRepeatedIngredientKeepsTheWorstMention() {
        XCTAssertEqual(verdict("gelatin, sugar, marshmallow (gelatin (pork))").overallGrade, .haram)
    }

    func testVeganAndPlantBasedQualifiersResolve() {
        XCTAssertEqual(item(verdict("vegan gelatin (agar)"), "gelatin")?.grade, .halal)
        XCTAssertEqual(item(verdict("plant-based gelatin"), "gelatin")?.grade, .halal)
        XCTAssertEqual(item(verdict("sunflower lecithin"), "lecithin")?.grade, .halal)
    }

    // MARK: - False negatives (must flag)

    func testHardHaramForms() {
        for text in ["porcine gelatin", "pork gelatin", "PORK GELATIN", "lard", "pig skin", "bacon bits",
                     "gélatine de porc", "manteca de cerdo", "lemak babi", "domuz jelatini",
                     "schweinegelatine", "rum flavor", "beer batter", "whiskey", "خنزير"] {
            XCTAssertEqual(verdict("sugar, \(text), salt").overallGrade, .haram, text)
        }
    }

    /// Spirits are khamr like wine: pinned under every standard, lenient included.
    func testSpiritsArePinnedUnderEveryStandard() {
        for std in HalalStandard.allCases {
            XCTAssertEqual(verdict("rum", standard: std).overallGrade, .haram, "\(std)")
            XCTAssertEqual(verdict("brandy", standard: std).overallGrade, .haram, "\(std)")
        }
    }

    func testDoubtfulFormsAreNeverHalal() {
        for text in ["mono and diglycerides", "Mono- and Diglycerides", "mono\u{2013} and diglycerides",
                     "monoglyceride", "mono & diglycerides", "L-cysteine", "carmine", "cochineal extract",
                     "shellac", "confectioner’s glaze", "vanilla extract", "natural cherry flavor",
                     "natural and artificial flavor", "glycerin", "vegetable glycerin", "beef gelatin",
                     "enzyme", "whey", "lactosérum", "chicken broth", "beef stock", "collagen peptides",
                     "parmesan cheese", "emulsifier (E471)", "emulsifier (471)", "INS 471", "e-120",
                     "disodium inosinate", "bone phosphate", "gelatina", "E1105"] {
            XCTAssertNotEqual(verdict("sugar, \(text), water").overall, .halal, text)
        }
    }

    func testMeatSignalGradesOnTheCitedMeatRow() {
        let chicken = verdict("chicken broth").matched.first
        XCTAssertNil(chicken?.matchedRule)
        XCTAssertEqual(chicken?.grade, .mashboohDisapproved)
        XCTAssertTrue(chicken?.explanation.contains("slaughter") ?? false)
        XCTAssertEqual(verdict("chicken broth", standard: .zabiha).overallGrade, .haram)
    }

    func testFreeTextENumbersUseTheENumberPath() {
        let v = verdict("emulsifier: E471, colour (E120), flavour enhancer (E621)")
        XCTAssertTrue(ids(v).isSuperset(of: ["mono-diglycerides", "carmine"]))
        XCTAssertTrue(v.matched.contains { $0.originalText == "E621 (monosodium glutamate)" && $0.verdict == .doubtful })
    }

    func testNonEnglishTextFallsBackOnEnglishTags() {
        let v = verdict("سكر، جيلاتين بقري", tags: ["en:sugar", "en:beef-gelatin"])
        XCTAssertTrue(ids(v).contains("gelatin"))
        XCTAssertNotEqual(v.overall, .halal)
    }

    func testUnreadableScriptIsQuestionableNotHalal() {
        let v = verdict("砂糖、水あめ、ゼラチン、酸味料")
        XCTAssertEqual(v.overall, .doubtful)
        XCTAssertTrue(v.flagged.first?.explanation.contains("script") ?? false)
    }

    func testTagsNeverOverrideWhatTheTextSays() {
        // Text resolves the lecithin to soy; a bare tag can't undo that.
        let v = verdict("soy lecithin", tags: ["en:lecithin"])
        XCTAssertEqual(item(v, "lecithin")?.grade, .halal)
    }

    // MARK: - False positives (must NOT flag)

    func testWordsThatOnlyLookLikeConcerns() {
        let clean = ["graham flour", "durum wheat semolina", "colour (iron oxide pigment)", "liquorice extract",
                     "hamburger bun (wheat flour, water, yeast)", "rump", "plantain chips", "porcini mushrooms",
                     "sugar alcohol (erythritol)", "root beer extract", "ginger", "vinegar", "collard greens",
                     "suitable for babies", "product of turkey", "goat's milk", "lamb's lettuce",
                     "egg whites from chicken eggs", "blood orange juice", "coconut meat"]
        for text in clean {
            let v = verdict(text)
            XCTAssertFalse(v.matched.contains { $0.grade == .haram }, text)
            XCTAssertFalse(v.matched.contains { $0.matchedRule?.id == "wine" || $0.matchedRule?.id == "pork" }, text)
        }
        XCTAssertFalse(verdict("coconut meat").matched.contains { $0.categoryHint == .meat })
    }

    /// Negations can only STOP a false match — they never clear anything else.
    func testNegationsStopFalseMatchesOnly() {
        for text in ["alcohol-free", "non-alcoholic", "no pork", "pork-free", "gelatin-free", "free from gelatin",
                     "sans alcool", "no added alcohol"] {
            XCTAssertEqual(verdict("sugar, water (\(text))").overall, .halal, text)
        }
        // A negation elsewhere doesn't clear a real concern.
        XCTAssertEqual(verdict("gelatin (pork-free)").overall, .doubtful)
        XCTAssertEqual(verdict("alcohol-free, rum").overallGrade, .haram)
        XCTAssertEqual(verdict("pork-free recipe, lard").overallGrade, .haram)
    }

    func testTurkeyBaconIsMeatNotPork() {
        let v = verdict("turkey bacon (turkey, salt)")
        XCTAssertNotEqual(v.overallGrade, .haram)
        XCTAssertEqual(v.overall, .doubtful)
    }

    // MARK: - Driver determinism (HANDOFF sweep #2)

    func testDriverIsStableAndInLabelOrderOnTies() {
        let text = "Enriched corn meal, vegetable oil, cheese seasoning (whey, cheddar cheese (milk, cheese cultures, salt, enzymes), maltodextrin, natural flavor)"
        let first = verdict(text).flagged.first?.displayName
        for _ in 0..<25 { XCTAssertEqual(verdict(text).flagged.first?.displayName, first) }
        let drivers = verdict(text).flagged.map(\.displayName)
        XCTAssertEqual(drivers.first, "Whey")   // earliest on the label among the tied
    }

    // MARK: - Performance

    func testLongLabelEvaluatesFast() {
        let long = Array(repeating: "Sugar, glucose syrup, gelatin (beef), modified corn starch, citric acid, natural and artificial flavors, colour (E120, E133), carnauba wax, beeswax, soy lecithin, mono- and diglycerides (soybean oil), whey powder, salt, emulsifier (471, 322)", count: 12).joined(separator: ", ")
        measure { _ = verdict(long, eNumbers: ["en:e120", "en:e133", "en:e322", "en:e471", "en:e901", "en:e903"]) }
        let start = Date()
        _ = verdict(long)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.25)
    }

    func testRulesThatFailedToLoadNeverReadAsHalal() {
        let v = RulesEngine(rules: []).evaluate(product: Product(id: "t", name: "T", brand: nil,
            rawIngredientsText: "sugar, pork gelatin", additivesENumbers: []))
        XCTAssertNotEqual(v.overall, .halal)
    }

    /// Omar's ruling, Oct 23: wine vinegar stays haram (the wine is named on the label).
    func testRedWineVinegarStaysHaram() {
        XCTAssertEqual(verdict("red wine vinegar, salt").overallGrade, .haram)
        XCTAssertNotEqual(verdict("vinegar, salt").overallGrade, .haram)
    }

    /// Found running the engine over 314 real Open Food Facts labels (Oct 23).
    func testRealLabelFalseHarams() {
        for text in ["sugar, chocolate liquor, cocoa butter, soy lecithin",
                     "milk, madagascar bourbon vanilla (vanilla extract, vanilla bean specks)",
                     "harina de trigo, agua, sal. 1 porcion = 30 g"] {
            XCTAssertNotEqual(verdict(text).overallGrade, .haram, text)
        }
        XCTAssertEqual(verdict("pork, salt").overallGrade, .haram)
        XCTAssertEqual(verdict("porc, sel").overallGrade, .haram)
        XCTAssertEqual(verdict("bourbon whiskey, sugar").overallGrade, .haram)
    }

    func testNutritionPanelOrMarketingTextIsNotClean() {
        XCTAssertNotEqual(verdict("Contains A BIOENGINEERED FOOD INGREDIENT MADE IN MEXICO").overall, .halal)
        XCTAssertNotEqual(verdict("Nutrition Facts 3 servings per container, Calories 140").overall, .halal)
        XCTAssertEqual(verdict("whole grain rolled oats").overall, .halal)
        XCTAssertEqual(verdict("Italian whole peeled tomatoes, olive oil, onions, salt, garlic, basil").overall, .halal)
    }

    /// Found running the engine over 301 FR/DE/TR/MY/UK/ES labels (Oct 23).
    func testForeignLabelFalseHarams() {
        for text in ["haferflocken, wasser, salz. trocken lagern.",
                     "zucker, kakao. enthält kein schweinefett.",
                     "un, seker. mamullerimizin hiçbir çeşidinde alkol ve domuz yağı kullanılmamaktadır.",
                     "un, seker. Mamullerimizin Hiçbir Çeşidinde Alkol, Domuz Yağı ve Katkıları Yoktur.",
                     "un. Ürünlerimizin Hiçbir Çeşidine Alkol, Domuz Yağı ve Türevleri Katılmamıştır."] {
            XCTAssertNotEqual(verdict(text).overallGrade, .haram, text)
        }
        XCTAssertFalse(verdict("erbsenprotein, hühnereiweißpulver").matched.contains { $0.categoryHint == .meat })
        // The negation only covers its own clause.
        XCTAssertEqual(verdict("schweinefleisch, salz").overallGrade, .haram)
        XCTAssertEqual(verdict("un, domuz yağı, seker").overallGrade, .haram)
        XCTAssertEqual(verdict("hiçbir katkı yok. domuz yağı").overallGrade, .haram)
    }

    /// Codes Open Food Facts tags that had no name: E428 is gelatine and must
    /// grade as the gelatin rule; a named additive shows its name, not a bare code.
    func testNewlyNamedENumbers() {
        XCTAssertEqual(item(verdict("sugar", eNumbers: ["en:e428"]), "gelatin")?.matchedRule?.id, "gelatin")
        XCTAssertNotEqual(verdict("water", eNumbers: ["en:e1510"]).overall, .halal)
        XCTAssertTrue(verdict("water", eNumbers: ["en:e375"]).matched.contains { $0.displayName.contains("niacin") })
    }

    /// Found on Gulf / Indonesian / US gummy labels (Oct 23).
    func testHalalAssuranceStatementsAreNotIngredients() {
        let v = verdict("wheat flour, sugar, soya lecithin (e322). our products do not contain any alcohol or pork based ingredients.")
        XCTAssertNotEqual(v.overallGrade, .haram)
        XCTAssertNotEqual(item(v, "lecithin")?.resolvedOrigin, .animalPork)
        XCTAssertNotEqual(verdict("sugar, cocoa. contains no pork or alcohol.").overallGrade, .haram)
        XCTAssertNotEqual(verdict("sucre, gousses de vanille bourbon").overallGrade, .haram)
        XCTAssertEqual(item(verdict("sugar, modified corn gelatin"), "gelatin")?.resolvedOrigin, .plant)
        XCTAssertNotEqual(verdict("دقيق القمح، سكر. لا تحتوي منتجاتنا على الكحول أو مكونات مشتقة من لحم الخنزير").overallGrade, .haram)
        XCTAssertEqual(verdict("دقيق القمح، دهن الخنزير، سكر").overallGrade, .haram)
        // Pork outside the statement is still pork.
        XCTAssertEqual(verdict("pork gelatin, sugar. does not contain alcohol.").overallGrade, .haram)
    }

    func testBareEnzymesAreNotCalledRennet() {
        XCTAssertEqual(item(verdict("milk, salt, enzymes"), "rennet")?.displayName, "Enzymes (may be rennet)")
        XCTAssertEqual(item(verdict("milk, salt, animal rennet"), "rennet")?.displayName, "Rennet")
        XCTAssertEqual(item(verdict("water, mirin, soy sauce"), "wine")?.displayName, "Alcoholic drink")
        XCTAssertEqual(item(verdict("beef, red wine, salt"), "wine")?.displayName, "Wine")
    }

    /// "What would make it halal" only names origins whose Halal cell is cited.
    func testCitedHalalOriginsForGelatin() throws {
        let gelatin = try XCTUnwrap(item(verdict("sugar, gelatin"), "gelatin"))
        let origins = GradeMatrix.citedHalalOrigins(for: gelatin)
        for o in origins {
            XCTAssertNotEqual(o, .unspecified)
            XCTAssertNotEqual(o, .animalPork)
        }
        let porcine = try XCTUnwrap(item(verdict("sugar, gelatin (porcine)"), "gelatin"))
        XCTAssertTrue(GradeMatrix.citedHalalOrigins(for: porcine).isEmpty)
        print("gelatin cited-halal origins:", origins)
    }
}
