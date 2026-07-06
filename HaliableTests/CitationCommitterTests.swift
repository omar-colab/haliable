//
//  CitationCommitterTests.swift
//  HaliableTests
//
//  Citation Pipeline — the proven vertical slice (docs/citations/SPEC.md §3.4 + §5).
//  Demonstrates the full research → approve → commit → FLIP loop end-to-end on real
//  high-traffic cells, and proves the gate rejects weak candidates — all with
//  clearly test-only citations, so the shipping Citations.json stays empty.
//

import XCTest
@testable import Haliable

final class CitationCommitterTests: XCTestCase {

    // Restore the global citation store after any test that swaps it.
    private var savedStore: CitationStore!
    override func setUp() { savedStore = CitationStore.shared }
    override func tearDown() { CitationStore.shared = savedStore }

    // Test-only sources — fixtures, never committed to the shipping JSON.
    private func cite(_ name: String, tier: SourceTier = .standardBody) -> Citation {
        Citation(sourceName: name,
                 reference: "https://example.test/\(name)#clause",
                 date: "2026-06-27", tier: tier,
                 paraphrase: "Test paraphrase: \(name) states a position on this subject.")
    }

    private func cellCandidate(subject: String, origin: String, position: String,
                               _ proposed: [Citation],
                               decision: CandidateDecision = .approved) -> CitationCandidate {
        CitationCandidate(target: CandidateTarget(kind: .cell, subject: subject,
                                                  origin: origin, position: position),
                          proposed: proposed, decision: decision)
    }

    private let empty = CitationFile(version: 1, cells: [], certifiers: [])

    /// Two independent tier-1 sources clear a high-traffic cell, and committing
    /// them flips the cell to `cited` IN THE LIVE ENGINE.
    func testVerticalSliceFlipsCellsInLiveEngine() {
        let candidates = [
            cellCandidate(subject: "gelatin", origin: "plant", position: "general",
                          [cite("JAKIM MS1500:2019"), cite("IFANCA Halal Standard")]),
            cellCandidate(subject: "natural flavors", origin: "unspecified", position: "general",
                          [cite("MUI Fatwa 2011"), cite("AMJA Resolution")]),
        ]
        let report = CitationCommitter.commit(candidates, into: empty)
        XCTAssertEqual(report.committed, 2, report.outcomes.map(\.reason).joined(separator: " | "))
        XCTAssertEqual(report.rejected, 0)

        // Swap in the committed citations and ask the LIVE engine.
        CitationStore.shared = CitationStore(cells: report.file.cells,
                                             certifiers: report.file.certifiers ?? [])
        func status(_ subject: String, _ origin: String, _ position: String) -> CitationStatus? {
            GradeMatrix.allSeededEntries.first {
                $0.subject.reviewLabel == subject && $0.origin.rawValue == origin
                    && $0.standard.rawValue == position
            }?.cell.citationStatus
        }
        XCTAssertEqual(status("gelatin", "plant", "general"), .cited)
        XCTAssertEqual(status("natural flavors", "unspecified", "general"), .cited)
    }

    /// A high-traffic cell with only ONE strong source is rejected (needs 2).
    func testSingleSourceHighTrafficRejected() {
        let c = cellCandidate(subject: "gelatin", origin: "plant", position: "general",
                              [cite("JAKIM MS1500:2019")])
        let report = CitationCommitter.commit([c], into: empty)
        XCTAssertEqual(report.committed, 0)
        XCTAssertEqual(report.rejected, 1)
        XCTAssertTrue(report.file.cells.isEmpty, "nothing written on rejection")
    }

    /// Tier-3 (secondary) sources never clear, however many.
    func testTierThreeRejected() {
        let c = cellCandidate(subject: "natural flavors", origin: "unspecified", position: "general",
                              [cite("Wikipedia", tier: .secondary), cite("A blog", tier: .secondary)])
        XCTAssertEqual(CitationCommitter.commit([c], into: empty).rejected, 1)
    }

    /// Non-approved candidates are skipped, not committed.
    func testUnapprovedSkipped() {
        let c = cellCandidate(subject: "gelatin", origin: "plant", position: "general",
                              [cite("JAKIM MS1500:2019"), cite("IFANCA Halal Standard")],
                              decision: .staged)
        let report = CitationCommitter.commit([c], into: empty)
        XCTAssertEqual(report.skipped, 1)
        XCTAssertEqual(report.committed, 0)
    }

    /// Re-committing the same candidate is a no-op (idempotent keyed merge).
    func testCommitIsIdempotent() {
        let c = cellCandidate(subject: "gelatin", origin: "plant", position: "general",
                              [cite("JAKIM MS1500:2019"), cite("IFANCA Halal Standard")])
        let once = CitationCommitter.commit([c], into: empty).file
        let twice = CitationCommitter.commit([c], into: once).file
        XCTAssertEqual(once.cells.count, twice.cells.count)
        XCTAssertEqual(once.cells, twice.cells)
    }

    /// A positive certifier claim clears with one tier-1 source and flips cited.
    func testCertifierClaimClears() throws {
        let item = try XCTUnwrap(CitationBacklog.certifierItems.first)
        let cand = CitationCandidate(
            target: CandidateTarget(kind: .certifier, subject: item.subject,
                                    origin: nil, position: item.position),
            proposed: [cite("\(item.subject.uppercased()) accreditation doc")],
            decision: .approved)
        let report = CitationCommitter.commit([cand], into: empty)
        XCTAssertEqual(report.committed, 1, report.outcomes.map(\.reason).joined())

        CitationStore.shared = CitationStore(cells: report.file.cells,
                                             certifiers: report.file.certifiers ?? [])
        let body = try XCTUnwrap(CertificationBody(rawValue: item.subject))
        let std = try XCTUnwrap(HalalStandard(rawValue: item.position))
        XCTAssertTrue(SatisfactionClaim.make(body: body, standard: std).isClearedSatisfaction)
    }

    /// The committed file encodes to the same shape Citations.json uses.
    func testEncodesToCitationsJSONShape() throws {
        let c = cellCandidate(subject: "gelatin", origin: "plant", position: "general",
                              [cite("JAKIM MS1500:2019"), cite("IFANCA Halal Standard")])
        let data = try CitationCommitter.encode(CitationCommitter.commit([c], into: empty).file)
        let decoded = try XCTUnwrap(CitationStore.decode(data))
        XCTAssertEqual(decoded.cells.count, 1)
    }
}
