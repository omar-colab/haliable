//
//  CitedCellReachabilityTests.swift
//  Every cited (subject, origin) cell in Citations.json must be reachable from
//  a real label wording. Otherwise the approved research never reaches a user.
//

import XCTest
@testable import Haliable

final class CitedCellReachabilityTests: XCTestCase {
    private let engine = RulesEngine()

    /// A label wording for every cited cell, keyed "subject/origin".
    private let samples: [String: String] = [
        "E120/unspecified": "sugar, carmine",
        "E153/unspecified": "sugar, vegetable carbon (E153)",
        "E322/plant": "cocoa butter, soy lecithin",
        "E322/unspecified": "cocoa butter, lecithin",
        "E422/unspecified": "sugar, glycerin",
        "E470/unspecified": "dextrose, magnesium stearate",
        "E471/unspecified": "flour, mono and diglycerides",
        "E472/unspecified": "flour, emulsifier (E472)",
        "E542/unspecified": "sugar, bone phosphate (E542)",
        "E570/unspecified": "dextrose, stearic acid (E570)",
        "E627/unspecified": "salt, disodium guanylate (E627)",
        "E631/unspecified": "salt, disodium inosinate (E631)",
        "E904/unspecified": "sugar, shellac",
        "E920/animal": "flour, l-cysteine (animal)",
        "E920/synthetic": "flour, l-cysteine (synthetic)",
        "E920/unspecified": "flour, l-cysteine",
        "alcohol/unspecified": "water, ethyl alcohol",
        "enzyme/animal": "milk, salt, animal rennet",
        "enzyme/microbial": "milk, salt, microbial enzymes",
        "enzyme/unspecified": "milk, salt, enzymes",
        "flavor ethanol carrier/unspecified": "sugar, natural flavor (ethyl alcohol)",
        "gelatin/animalNonZabiha": "sugar, beef gelatin",
        "gelatin/microbial": "sugar, microbial gelatin",
        "gelatin/plant": "sugar, plant-based gelatin",
        "gelatin/unspecified": "sugar, gelatin",
        "meat/animalNonZabiha": "beef, salt",
        "meat/unspecified": "chicken, salt",
        "natural flavors/unspecified": "sugar, natural flavors",
        "vanilla extract/unspecified": "sugar, vanilla extract",
        "vitamin d3/unspecified": "milk, vitamin d3",
        "whey/unspecified": "sugar, whey",
    ]

    func testEveryCitedCellHasALabelPath() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "Citations", withExtension: "json"))
        let file = try JSONDecoder().decode(CitationFile.self, from: Data(contentsOf: url))
        let cited = Set(file.cells.filter { !$0.citations.isEmpty }.map { "\($0.subject)/\($0.origin)" })
        for key in cited.sorted() {
            guard let text = samples[key] else { XCTFail("no sample label for cited cell \(key)"); continue }
            let v = engine.evaluate(product: Product(id: "t", name: "t", brand: nil, rawIngredientsText: text, additivesENumbers: []))
            let hit = v.matched.contains { m in
                let o = GradeMatrix.resolveOrigin(for: m)
                let rowKey = "\(GradeMatrix.subjectLabel(for: m))/\(o.rawValue)"
                return (rowKey == key || "\(GradeMatrix.subjectLabel(for: m))/unspecified" == key) && !m.citations.isEmpty
            }
            XCTAssertTrue(hit, "\(key) not reached by \"\(text)\": " + v.matched.map {
                "\($0.displayName)→\(GradeMatrix.subjectLabel(for: $0))/\(GradeMatrix.resolveOrigin(for: $0).rawValue) cites=\($0.citations.count)"
            }.joined(separator: "; "))
        }
    }
}
