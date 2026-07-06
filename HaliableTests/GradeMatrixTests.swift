//
//  GradeMatrixTests.swift
//  HaliableTests
//
//  Phase 2 — safety invariants of the SEEDED matrix. These lock the load-bearing
//  fail-safes (unknown → never halal; porcine/khamr → always haram). The
//  contestable per-standard grades are DRAFT (needsReview) and are intentionally
//  NOT asserted here until scholar review (Phase 5).
//

import XCTest
@testable import Haliable

final class GradeMatrixTests: XCTestCase {

    /// Unknown / unseeded subjects must never come back halal (the fail-safe).
    func testUnknownSubjectFallsBackNonHalal() {
        let matrix = GradeMatrix()
        let unknown: [GradeMatrix.Subject] = [
            .category(.other), .category(.seafoodNonFish),
            .named("not-a-real-subject"), .eNumber("E000")
        ]
        for subject in unknown {
            for origin in Origin.allCases {
                for standard in HalalStandard.allCases {
                    let cell = matrix.cell(for: subject, origin: origin, standard: standard)
                    XCTAssertNotEqual(cell.grade, .halal,
                        "unknown \(subject)/\(origin)/\(standard) must not grade halal")
                    XCTAssertTrue(cell.needsReview)
                }
            }
        }
    }

    /// The conservative fallback helper, per standard.
    func testFallbackHelperIsNonHalal() {
        for standard in HalalStandard.allCases {
            let cell = GradeMatrix.fallback(standard: standard)
            XCTAssertNotEqual(cell.grade, .halal)
            XCTAssertTrue(cell.needsReview)
        }
    }

    /// Hard-haram (porcine) is pinned to Haram under EVERY standard — no standard,
    /// not even lenient, may soften it.
    func testPorcineIsPinnedToHaramForEveryStandard() {
        let pork = IngredientRule(
            id: "pork", ingredient: "Pork", aliases: ["pork"], eNumber: nil,
            verdict: .haram, reason: "",
            source: Source(body: "X", title: "Y", url: "https://a", year: 2024))
        for standard in HalalStandard.allCases {
            let item = MatchedIngredient(originalText: "pork", matchedRule: pork, standard: standard)
            XCTAssertEqual(item.grade, .haram, "porcine must be haram under \(standard)")
            XCTAssertEqual(item.verdict, .haram)
        }
    }

    /// An unknown ingredient (no rule) stays Questionable, never Halal.
    func testUnknownIngredientNeverHalal() {
        for standard in HalalStandard.allCases {
            let item = MatchedIngredient(originalText: "mystery", matchedRule: nil, standard: standard)
            XCTAssertNotEqual(item.grade, .halal)
            XCTAssertEqual(item.verdict, .doubtful)
        }
    }
}
