//
//  FieldValidationTests.swift
//  HaliableTests
//
//  The field-validation log (Citation Protocol §4): record scans, count subject
//  traffic, export/merge between scanners (deduped), and feed the worksheet order.
//

import XCTest
@testable import Haliable

final class FieldValidationTests: XCTestCase {

    private func entry(_ gtin: String, subjects: [String], scanner: String = "omar",
                       id: UUID = UUID(), grade: GradeLevel = .mashboohContested) -> FieldScanEntry {
        FieldScanEntry(id: id, gtin: gtin, productName: "Product \(gtin)", position: .general,
                       computedGrade: grade, subjects: subjects, scannerId: scanner)
    }

    /// In-memory log (no file persistence) for deterministic tests.
    private func log() -> FieldValidationLog { FieldValidationLog(fileURL: nil) }

    // MARK: Recording + counts

    func testSubjectCountsAggregatePerScan() {
        let l = log()
        l.record(entry("1", subjects: ["E471", "gelatin"]))
        l.record(entry("2", subjects: ["E471"]))
        l.record(entry("3", subjects: ["E471", "natural flavors"]))
        let counts = l.subjectCounts()
        XCTAssertEqual(counts["E471"], 3)
        XCTAssertEqual(counts["gelatin"], 1)
        XCTAssertEqual(counts["natural flavors"], 1)
    }

    func testRecordIsIdempotentById() {
        let l = log()
        let e = entry("1", subjects: ["E471"])
        l.record(e); l.record(e)
        XCTAssertEqual(l.entries.count, 1)
    }

    // MARK: Export / round-trip

    func testExportRoundTrips() throws {
        let l = log()
        l.record(entry("1", subjects: ["E471"]))
        l.record(entry("2", subjects: ["gelatin"]))
        let data = try l.exportData()

        let imported = log()
        let added = imported.merge(data)
        XCTAssertEqual(added, 2)
        XCTAssertEqual(imported.subjectCounts(), l.subjectCounts())
    }

    // MARK: Pooling (two scanners)

    func testPoolingTwoScannersSumsCounts() throws {
        let omar = log()
        omar.record(entry("1", subjects: ["E471"], scanner: "omar"))
        omar.record(entry("2", subjects: ["E471"], scanner: "omar"))

        let friend = log()
        friend.record(entry("3", subjects: ["E471"], scanner: "friend"))
        friend.record(entry("4", subjects: ["gelatin"], scanner: "friend"))

        // Pool the friend's export into omar's log.
        let added = omar.merge(try friend.exportData())
        XCTAssertEqual(added, 2)
        XCTAssertEqual(omar.subjectCounts()["E471"], 3)
        XCTAssertEqual(omar.subjectCounts()["gelatin"], 1)

        // Merging the SAME export again is idempotent (dedup by id).
        let addedAgain = omar.merge(try friend.exportData())
        XCTAssertEqual(addedAgain, 0)
        XCTAssertEqual(omar.entries.count, 4)
    }

    // MARK: record(verdict:)

    func testRecordFromVerdictExtractsSubjects() {
        let l = log()
        let engine = RulesEngine()
        let product = Product(id: "0123", name: "Cookies", brand: nil,
                              rawIngredientsText: "gelatin, soy lecithin", additivesENumbers: [])
        let verdict = engine.evaluate(product: product, standard: .zabiha)
        let e = l.record(verdict: verdict, scannerId: "omar", lookedRight: true)
        XCTAssertEqual(e.gtin, "0123")
        XCTAssertTrue(e.subjects.contains("gelatin"), "flagged gelatin should be counted")
        XCTAssertEqual(l.subjectCounts()["gelatin"], 1)
    }

    // MARK: Feeds the worksheet order

    func testGenerateFromFieldLogOrdersByScans() {
        let l = log()
        // Scan "natural flavors" a lot → it should head the worksheet.
        for i in 0..<5 { l.record(entry("\(i)", subjects: ["natural flavors"])) }
        let doc = ReviewDocument.generate(fieldLog: l)
        guard let firstCell = doc.range(of: "<!--cell:")?.lowerBound else {
            return XCTFail("no worksheet rows rendered")
        }
        XCTAssertTrue(doc[firstCell...].prefix(60).contains("natural flavors"),
                      "the most-scanned subject should head the worksheet")
    }
}
