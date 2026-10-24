//
//  HistoryRegradeTests.swift
//  A History row saved as Halal must not stay Halal after the rules learn
//  that its product contains something they now flag.
//

import XCTest
import SwiftData
@testable import Haliable

@MainActor
final class HistoryRegradeTests: XCTestCase {
    func testStaleHalalRowIsRegraded() async throws {
        let container = try ModelContainer(for: ScanRecord.self, CachedProduct.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let product = Product(id: "123", name: "Gummies", brand: nil,
                              rawIngredientsText: "sugar, gelatin (porcine), citric acid", additivesENumbers: [])
        context.insert(CachedProduct(product))
        let row = ScanRecord(barcode: "123", productName: "Gummies", overallVerdict: .halal, standard: .general, score: 100)
        context.insert(row)

        let defaults = UserDefaults(suiteName: "HistoryRegradeTests")!
        defaults.removePersistentDomain(forName: "HistoryRegradeTests")
        await HistoryRegrade.run(context: context, engine: RulesEngine(), stamp: "v2", defaults: defaults)

        XCTAssertEqual(row.overallVerdict, .haram)
        XCTAssertLessThan(row.score ?? 100, 100)

        // Same version again: nothing re-runs.
        row.overallVerdict = .halal
        await HistoryRegrade.run(context: context, engine: RulesEngine(), stamp: "v2", defaults: defaults)
        XCTAssertEqual(row.overallVerdict, .halal)
    }
}
