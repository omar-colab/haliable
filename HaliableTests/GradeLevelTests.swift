//
//  GradeLevelTests.swift
//  HaliableTests
//
//  Phase 1 structural checks for the new grading scale. These assert the bridge
//  and safety invariants ONLY — no fiqh values are tested here (those arrive with
//  the seeded GradeMatrix in Phase 2 / Phase 5).
//

import XCTest
@testable import Haliable

final class GradeLevelTests: XCTestCase {

    /// The 5→3 bridge that keeps every legacy `Verdict` call site working.
    func testCoarseBridge() {
        XCTAssertEqual(GradeLevel.halal.coarse, .halal)
        XCTAssertEqual(GradeLevel.haram.coarse, .haram)
        XCTAssertEqual(GradeLevel.mashboohSafe.coarse, .doubtful)
        XCTAssertEqual(GradeLevel.mashboohContested.coarse, .doubtful)
        XCTAssertEqual(GradeLevel.mashboohDisapproved.coarse, .doubtful)
    }

    /// Lifting a legacy verdict then coarsening must return the original verdict
    /// (the interim path can't change any existing ruling).
    func testLiftedRoundTripsThroughCoarse() {
        for v in Verdict.allCases {
            XCTAssertEqual(GradeLevel.lifted(from: v).coarse, v,
                           "lift(\(v)).coarse must equal \(v)")
        }
    }

    /// Higher grade = worse, so worst-case rollup via `max` still holds.
    func testSeverityOrderingSupportsWorstCaseRollup() {
        XCTAssertGreaterThan(GradeLevel.haram.severity, GradeLevel.mashboohDisapproved.severity)
        XCTAssertGreaterThan(GradeLevel.mashboohDisapproved.severity, GradeLevel.mashboohContested.severity)
        XCTAssertGreaterThan(GradeLevel.mashboohSafe.severity, GradeLevel.halal.severity)
        XCTAssertEqual([GradeLevel.halal, .haram, .mashboohSafe].max()?.rawValue, 5)
    }

}
