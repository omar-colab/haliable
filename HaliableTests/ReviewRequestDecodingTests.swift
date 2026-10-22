//
//  ReviewRequestDecodingTests.swift
//  HaliableTests
//
//  A completed review row carries its sources in `evidence` (review-decide
//  writes the verified ones, each with an extra `verified` flag). If that
//  stopped decoding, every review refresh would fail, not just the sources.
//

import XCTest
@testable import Haliable

final class ReviewRequestDecodingTests: XCTestCase {
    private func decode(_ json: String) throws -> ReviewRequest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ReviewRequest.self, from: Data(json.utf8))
    }

    private let base = """
        "id": "A1B2C3D4-0000-4000-8000-000000000009", "user_id": "u", "product_name": "Test",
        "barcode": null, "notes": null, "photo_paths": ["u/1.jpg"], "created_at": "2026-10-22T12:00:00Z"
        """

    func testCompletedRowDecodesVerdictAndSources() throws {
        let r = try decode("""
            { \(base), "status": "completed", "verdict": "doubtful", "verdict_reason": "Read the sources.",
              "reviewed_at": "2026-10-22T13:00:00Z",
              "evidence": [{ "name": "IFANCA", "url": "https://ifanca.org/x", "tier": 1,
                             "quote": "gelatin of unstated origin is not certified", "verified": true }] }
            """)
        XCTAssertEqual(r.verdict, .doubtful)
        XCTAssertEqual(r.sources?.first?.name, "IFANCA")
        XCTAssertEqual(r.sources?.first?.tier, 1)
    }

    func testPendingRowWithoutEvidenceDecodes() throws {
        let r = try decode("""
            { \(base), "status": "pending", "verdict": null, "verdict_reason": null, "reviewed_at": null, "evidence": null }
            """)
        XCTAssertEqual(r.status, .pending)
        XCTAssertNil(r.sources)
    }
}
