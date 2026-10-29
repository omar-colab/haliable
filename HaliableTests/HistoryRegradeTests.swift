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

    /// Label checks are saved (one row per list), named by their first items,
    /// and re-graded from their own text — they have no cached product.
    func testLabelCheckIsSavedOnceAndRegraded() async throws {
        let container = try ModelContainer(for: ScanRecord.self, CachedProduct.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let text = "sugar, gelatin (porcine), water, salt"
        let verdict = RulesEngine().evaluate(product: LabelScanView.product(text), standard: .general)
        ScanRecord.saveLabelCheck(text, verdict: verdict, standard: .general, in: context)
        ScanRecord.saveLabelCheck(text, verdict: verdict, standard: .general, in: context)

        let rows = try context.fetch(FetchDescriptor<ScanRecord>())
        XCTAssertEqual(rows.count, 1)
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.productName, "Label: sugar, gelatin (porcine), water…")
        XCTAssertEqual(row.overallVerdict, .haram)

        row.overallVerdict = .halal
        let suite = "HistoryRegradeTests.label"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        await HistoryRegrade.run(context: context, engine: RulesEngine(), stamp: "v2", defaults: defaults)
        XCTAssertEqual(row.overallVerdict, .haram)
    }
}
