//
//  CitationTests.swift
//  HaliableTests
//
//  The clearance gate (Citation Protocol §8): a cell clears ONLY with a tier-1/2
//  well-formed citation; high-traffic and `lenient` cells need TWO independent
//  ones; origin-undeterminable cells can never clear to halal. Plus contested
//  (§1A/§12) and the standing disclosure (§12). Construction-level, deterministic.
//

import XCTest
@testable import Haliable

final class CitationTests: XCTestCase {

    private func cite(_ name: String, tier: SourceTier = .standardBody, date: String = "2019",
                      paraphrase: String = "Classifies the subject under this position.") -> Citation {
        Citation(sourceName: name, reference: "https://example.org/\(name)", date: date,
                 tier: tier, paraphrase: paraphrase)
    }

    private func makeCell(_ grade: GradeLevel, citations: [Citation],
                          highTraffic: Bool = false, position: HalalStandard = .general,
                          undeterminable: Bool = false) -> GradeCell {
        GradeCell(grade: grade, confidence: .medium, source: "s", citations: citations,
                  isHighTraffic: highTraffic, position: position, originUndeterminable: undeterminable)
    }

    // MARK: Tiers & well-formedness

    func testOnlyTier1And2CanClear() {
        XCTAssertTrue(SourceTier.standardBody.canClear)
        XCTAssertTrue(SourceTier.peerReviewed.canClear)
        XCTAssertFalse(SourceTier.secondary.canClear)
    }

    func testWellFormedRequiresAllFourFields() {
        XCTAssertTrue(cite("JAKIM").isWellFormed)
        XCTAssertFalse(Citation(sourceName: "", reference: "u", date: "2020", tier: .standardBody, paraphrase: "p").isWellFormed)
        XCTAssertFalse(Citation(sourceName: "X", reference: "", date: "2020", tier: .standardBody, paraphrase: "p").isWellFormed)
        XCTAssertFalse(Citation(sourceName: "X", reference: "u", date: " ", tier: .standardBody, paraphrase: "p").isWellFormed)
        XCTAssertFalse(Citation(sourceName: "X", reference: "u", date: "2020", tier: .standardBody, paraphrase: "").isWellFormed)
    }

    // MARK: §8.1 / §8.3 — no clearance without a valid citation

    func testNoCitationNoClearance() {
        let cell = makeCell(.mashboohContested, citations: [])
        XCTAssertTrue(cell.needsReview)
        XCTAssertEqual(cell.citationStatus, .pending)
    }

    func testTier3AloneDoesNotClear() {
        let cell = makeCell(.mashboohSafe, citations: [cite("Explainer", tier: .secondary)])
        XCTAssertTrue(cell.needsReview)
    }

    func testIncompleteCitationDoesNotClear() {
        let missingParaphrase = Citation(sourceName: "JAKIM", reference: "https://x", date: "2019",
                                         tier: .standardBody, paraphrase: "")
        XCTAssertTrue(makeCell(.mashboohSafe, citations: [missingParaphrase]).needsReview)
    }

    // MARK: §8.1 — one strong source clears a STANDARD cell

    func testOneSourceClearsStandardCell() {
        let cell = makeCell(.mashboohSafe, citations: [cite("JAKIM")], highTraffic: false, position: .general)
        XCTAssertFalse(cell.needsReview)
        XCTAssertEqual(cell.citationStatus, .cited)
    }

    // MARK: §8.2 — two independent sources for high-traffic / lenient

    func testHighTrafficNeedsTwoIndependentSources() {
        let oneSource = makeCell(.mashboohSafe, citations: [cite("JAKIM")], highTraffic: true)
        XCTAssertTrue(oneSource.needsReview)
        XCTAssertEqual(oneSource.citationStatus, .needsSecondSource)

        // Two citations but SAME organization → not independent → still pending.
        let sameOrg = makeCell(.mashboohSafe, citations: [cite("JAKIM", date: "2019"), cite("JAKIM", date: "2021")],
                               highTraffic: true)
        XCTAssertTrue(sameOrg.needsReview, "two citations from the same source are not independent")

        // Two distinct organizations → cleared.
        let twoIndependent = makeCell(.mashboohSafe, citations: [cite("JAKIM"), cite("MUI")], highTraffic: true)
        XCTAssertFalse(twoIndependent.needsReview)
        XCTAssertEqual(twoIndependent.independentSourceCount, 2)
    }

    func testLenientAlwaysNeedsTwoSourcesEvenIfNotHighTraffic() {
        let one = makeCell(.mashboohSafe, citations: [cite("Scholar A", tier: .peerReviewed)],
                           highTraffic: false, position: .lenient)
        XCTAssertTrue(one.needsReview, "lenient is a synthesized stance — needs two published positions")
        let two = makeCell(.mashboohSafe, citations: [cite("Scholar A", tier: .peerReviewed),
                                                      cite("MUI Fatwa")], position: .lenient)
        XCTAssertFalse(two.needsReview)
    }

    // MARK: §8.4 — origin-undeterminable can't clear to halal

    func testOriginUndeterminableCannotClearToHalal() {
        let halal = makeCell(.halal, citations: [cite("JAKIM")], undeterminable: true)
        XCTAssertTrue(halal.needsReview, "a citation can't supply origin data the label lacks")
        // The same undeterminable cell CAN clear to a non-halal grade.
        let doubtful = makeCell(.mashboohSafe, citations: [cite("JAKIM")], undeterminable: true)
        XCTAssertFalse(doubtful.needsReview)
    }

    // MARK: The invariant, stated directly

    func testClearedImpliesValidCitations() {
        let cells = [
            makeCell(.halal, citations: []),
            makeCell(.mashboohSafe, citations: [cite("JAKIM")]),
            makeCell(.mashboohSafe, citations: [cite("JAKIM"), cite("MUI")], highTraffic: true),
        ]
        for cell in cells where !cell.needsReview {
            XCTAssertFalse(cell.clearingCitations.isEmpty)
            XCTAssertTrue(cell.clearingCitations.allSatisfy { $0.tier.canClear && $0.isWellFormed })
            if cell.requiresTwoSources { XCTAssertGreaterThanOrEqual(cell.independentSourceCount, 2) }
        }
    }

    /// Live matrix: nothing is cited yet (Citations.json ships empty) → all pending.
    /// Integrity invariant: a cell is cleared IF AND ONLY IF it carries clearing
    /// citations that pass the §8 gate. (As the citation pipeline fills
    /// Citations.json, some cells legitimately clear — but never without a source.)
    func testLiveMatrixClearedOnlyWithCitations() {
        let entries = GradeMatrix.allSeededEntries
        XCTAssertFalse(entries.isEmpty)
        for e in entries where !e.cell.needsReview {
            XCTAssertFalse(e.cell.clearingCitations.isEmpty, "cleared without citation: \(e.key)")
            XCTAssertTrue(e.cell.isCleared, "cleared cell must pass the §8 gate: \(e.key)")
        }
        // Anything without a clearing citation must still be pending.
        for e in entries where e.cell.clearingCitations.isEmpty {
            XCTAssertTrue(e.cell.needsReview, "uncited cell must stay pending: \(e.key)")
        }
    }

    // MARK: Contested (§1A / §12)

    func testContestedHoldsMultipleCitations() {
        let contested = makeCell(.mashboohContested, citations: [cite("HMC"), cite("Scholar B", tier: .peerReviewed)])
        XCTAssertTrue(contested.isContested)
        XCTAssertEqual(contested.citationSummaries.count, 2)
    }

    func testSingleCitationIsNotContested() {
        XCTAssertFalse(makeCell(.mashboohContested, citations: [cite("HMC")]).isContested)
    }

    // MARK: Disclosure (§12)

    func testStandingDisclosureWording() {
        XCTAssertFalse(HaliableDisclosure.standing.isEmpty)
        XCTAssertTrue(HaliableDisclosure.standing.contains("verify with a scholar you trust"))
        XCTAssertTrue(HaliableDisclosure.standing.contains("for your situation"))
    }

    // MARK: CitationStore JSON round-trip (§9)

    func testCitationStoreDecodesEntries() {
        let json = """
        { "version": 1, "cells": [
          { "subject": "E120", "origin": "unspecified", "position": "lenient",
            "citations": [
              { "sourceName": "MUI Fatwa No. 11/2011", "reference": "https://mui/x", "date": "2011", "tier": 1, "paraphrase": "Cochineal permitted." },
              { "sourceName": "J. Halal Sci 2020", "reference": "https://scholar/y", "date": "2020", "tier": 2, "paraphrase": "Reviews the fatwa basis." }
            ] }
        ] }
        """.data(using: .utf8)!
        let store = CitationStore(entries: CitationStore.decode(json)?.cells ?? [])
        let cites = store.citations(subject: "E120", origin: "unspecified", position: "lenient")
        XCTAssertEqual(cites.count, 2)
        XCTAssertEqual(store.totalCitationCount, 2)
        // Those two independent tier-1/2 sources would clear an E120/lenient cell.
        let cell = makeCell(.mashboohSafe, citations: cites, highTraffic: true, position: .lenient)
        XCTAssertFalse(cell.needsReview)
    }
}
