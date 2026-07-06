//
//  ReviewDocumentTests.swift
//  HaliableTests
//
//  Launch-gate guarantee (Final Spec §C): the generated REVIEW.md must cover
//  EVERY seeded cell and EVERY `needsReview` cell, so no flagged item can be
//  left out of scholar review. These tests lock that, plus the presence of the
//  four open levers and the sign-off block. They assert COVERAGE, not the draft
//  fiqh numbers (those are the scholar's to confirm).
//

import XCTest
@testable import Haliable

final class ReviewDocumentTests: XCTestCase {

    private lazy var doc = ReviewDocument.generate()

    /// EVERY seeded cell appears in the document (by its hidden signature).
    func testCoversEverySeededCell() {
        let entries = GradeMatrix.allSeededEntries
        XCTAssertFalse(entries.isEmpty, "matrix must have seeded cells to review")
        for e in entries {
            XCTAssertTrue(doc.contains(ReviewDocument.signature(e)),
                          "REVIEW.md is missing seeded cell: \(e.key)")
        }
    }

    /// EVERY `needsReview` cell is present — the load-bearing gate. As the citation
    /// pipeline clears cells, not all remain pending, but every still-pending cell
    /// must appear; this fails loudly if a flagged cell is ever dropped.
    func testCoversEveryNeedsReviewCell() {
        let flagged = GradeMatrix.allSeededEntries.filter { $0.cell.needsReview }
        XCTAssertFalse(flagged.isEmpty, "there are still pending cells to review")
        for e in flagged {
            XCTAssertTrue(doc.contains(ReviewDocument.signature(e)),
                          "needsReview cell omitted from REVIEW.md: \(e.key)")
        }
    }

    /// The number of rendered worksheet rows equals the number of seeded cells.
    func testWorksheetRowCountMatchesSeededCells() {
        let signatureCount = doc.components(separatedBy: "<!--cell:").count - 1
        XCTAssertEqual(signatureCount, GradeMatrix.allSeededEntries.count)
    }

    /// The worksheet exposes the Protocol §11 columns.
    func testWorksheetHasProtocolColumns() {
        for col in ["Subject", "Origin", "Position", "Governing body", "Current grade",
                    "Citation status", "Paraphrase"] {
            XCTAssertTrue(doc.contains(col), "worksheet missing column: \(col)")
        }
    }

    /// The doc's CITED count tracks the live engine, and uncited cells render
    /// PENDING. (Cited cells appear only once a real citation has cleared them.)
    func testUncitedCellsRenderPending() {
        XCTAssertTrue(doc.contains("PENDING"))
        let citedInDoc = doc.components(separatedBy: "| CITED |").count - 1
        let citedLive = GradeMatrix.allSeededEntries.filter { $0.cell.citationStatus == .cited }.count
        XCTAssertEqual(citedInDoc, citedLive, "REVIEW.md CITED count must match the live engine")
        for e in GradeMatrix.allSeededEntries where e.cell.citationStatus == .cited {
            XCTAssertFalse(e.cell.clearingCitations.isEmpty, "a CITED cell must carry a real citation: \(e.key)")
        }
    }

    /// All four OPEN levers are surfaced at the top (now ordinary pending cells).
    func testAllFourOpenLeversPresentAtTop() {
        let levers = GradeMatrix.openLevers
        XCTAssertEqual(levers.count, 4)
        for lever in levers {
            XCTAssertTrue(doc.contains("<!--lever:\(lever.id)-->"),
                          "open lever missing from REVIEW.md: \(lever.id)")
        }
        // The levers section must come before the per-cell worksheet.
        let leverIdx = doc.range(of: "OPEN LEVERS")?.lowerBound
        let tableIdx = doc.range(of: "Per-cell research worksheet")?.lowerBound
        XCTAssertNotNil(leverIdx); XCTAssertNotNil(tableIdx)
        if let l = leverIdx, let t = tableIdx { XCTAssertTrue(l < t, "open levers must be at the top") }
    }

    /// "Report, don't rule" framing + the standing disclosure are in the document.
    func testDocReportsNotRulesAndCarriesDisclosure() {
        XCTAssertTrue(doc.contains("REPORT, DON'T RULE"))
        XCTAssertTrue(doc.contains("Clearance gate"))
        XCTAssertTrue(doc.contains("2 INDEPENDENT sources"))
        XCTAssertTrue(doc.contains(HaliableDisclosure.standing),
                      "standing disclosure must appear in the worksheet")
    }

    /// High-traffic cells are starred and sort first; a most-requested subject
    /// heads the worksheet among them.
    func testHighTrafficFirstOrdering() {
        XCTAssertTrue(doc.contains("★"), "high-traffic cells must be starred")
        let ranked = ReviewDocument.generate(requestCounts: ["natural flavors": 99])
        guard let firstCell = ranked.range(of: "<!--cell:")?.lowerBound else {
            return XCTFail("no worksheet rows rendered")
        }
        let firstSig = ranked[firstCell...].prefix(60)
        XCTAssertTrue(firstSig.contains("natural flavors"),
                      "the most-requested high-traffic subject should head the worksheet")
    }

    /// The governing-body map is shown per position.
    func testGoverningBodyShown() {
        for body in ["HMC / HFSAA", "JAKIM / MUI / ESMA", "IFANCA / ISNA"] {
            XCTAssertTrue(doc.contains(body), "missing governing body label: \(body)")
        }
    }

    /// Every certifier × position pairing is in the satisfaction table.
    func testCoversEveryCertifierPairing() {
        for row in GradeMatrix.certifierReviewRows {
            XCTAssertTrue(doc.contains("<!--cert:\(row.body.rawValue)::\(row.standard.rawValue)-->"),
                          "certifier pairing omitted: \(row.body.rawValue)/\(row.standard.rawValue)")
        }
    }

    /// The contested/divergence appendix surfaces the consequential split cells.
    func testContestedAppendixIncludesKnownSplits() {
        let diverging = Set(GradeMatrix.divergentRows.map { $0.subject.reviewLabel })
        XCTAssertTrue(diverging.contains("vanilla extract"))
        XCTAssertTrue(diverging.contains("E120"))   // carmine
        XCTAssertTrue(diverging.contains("enzyme"))  // rennet (animal vs microbial)
        XCTAssertTrue(doc.contains("Contested & cross-position appendix"))
    }

    /// The researcher sourcing log is present (reframed from scholar sign-off).
    func testResearcherLogPresent() {
        XCTAssertTrue(doc.contains("Researcher:"))
        XCTAssertTrue(doc.contains("Sources consulted"))
        XCTAssertTrue(doc.contains("Items still pending"))
    }

    /// Dev convenience: regenerate the committed REVIEW.md from code. Skipped
    /// unless HALIABLE_WRITE_REVIEW=1 so normal/CI runs never write. Set
    /// HALIABLE_REVIEW_PATH to an absolute path, or it defaults next to SRCROOT.
    func testRegenerateAndWriteFileWhenRequested() throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(env["HALIABLE_WRITE_REVIEW"] == "1",
                          "set HALIABLE_WRITE_REVIEW=1 to rewrite REVIEW.md")
        let path = env["HALIABLE_REVIEW_PATH"]
            ?? (env["SRCROOT"].map { $0 + "/REVIEW.md" })
            ?? FileManager.default.currentDirectoryPath + "/REVIEW.md"
        try ReviewDocument.generate().write(toFile: path, atomically: true, encoding: .utf8)
        print("Wrote REVIEW.md → \(path)")
    }
}
