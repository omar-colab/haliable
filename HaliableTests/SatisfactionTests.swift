//
//  SatisfactionTests.swift
//  HaliableTests
//
//  The certifier "meets your standard?" claim obeys the SAME citation gate as a
//  grade cell (Citation Protocol §8): a confident positive claim requires ≥1
//  tier-1/2 well-formed citation; uncited positive claims are pending. Mirrors
//  CitationTests at the certifier level.
//

import XCTest
@testable import Haliable

final class SatisfactionTests: XCTestCase {

    private func cite(_ name: String, tier: SourceTier = .standardBody) -> Citation {
        Citation(sourceName: name, reference: "https://example.org/\(name)", date: "2024",
                 tier: tier, paraphrase: "Body's published recognition for this position.")
    }

    private func claim(_ satisfies: Bool, _ citations: [Citation]) -> SatisfactionClaim {
        SatisfactionClaim(body: .hmc, standard: .zabiha, draftSatisfies: satisfies, citations: citations)
    }

    // MARK: Invariant — no confident claim without a citation

    func testPositiveClaimPendingWithoutCitation() {
        let c = claim(true, [])
        XCTAssertTrue(c.needsReview)
        XCTAssertFalse(c.isClearedSatisfaction)
    }

    func testTier3DoesNotClearClaim() {
        XCTAssertTrue(claim(true, [cite("Explainer", tier: .secondary)]).needsReview)
    }

    func testIncompleteCitationDoesNotClearClaim() {
        let bad = Citation(sourceName: "HMC", reference: "", date: "2024", tier: .standardBody, paraphrase: "p")
        XCTAssertTrue(claim(true, [bad]).needsReview)
    }

    func testCitedPositiveClaimClears() {
        let c = claim(true, [cite("HMC recognition list")])
        XCTAssertFalse(c.needsReview)
        XCTAssertTrue(c.isClearedSatisfaction)
    }

    /// A negative claim (body doesn't satisfy the standard) is the conservative
    /// direction — it needs no citation and never reads as "meets your standard".
    func testNegativeClaimNeedsNoCitation() {
        let c = claim(false, [])
        XCTAssertFalse(c.needsReview)
        XCTAssertFalse(c.isClearedSatisfaction)
    }

    // MARK: evaluate() ↔ the store

    private func withStore(_ store: CitationStore, _ body: () -> Void) {
        let saved = CitationStore.shared
        CitationStore.shared = store
        defer { CitationStore.shared = saved }
        body()
    }

    /// Empty store → every drafted-positive pairing renders as pendingCitation,
    /// never meetsYourStandard.
    func testEmptyStoreMakesAllPositiveClaimsPending() {
        withStore(CitationStore(certifiers: [])) {
            for body in CertificationBody.allCases {
                for std in HalalStandard.allCases where body.confidentlySatisfies.contains(std) {
                    XCTAssertEqual(StandardSatisfaction.evaluate(body: body, against: std), .pendingCitation,
                                   "\(body)/\(std) must be pending until cited")
                }
            }
        }
    }

    /// A cited pairing reads as meetsYourStandard; an uncited one stays pending.
    func testCitedPairingMeetsStandard() {
        let entry = CertifierCitationEntry(body: "hmc", position: "zabiha",
                                           citations: [cite("HMC recognition list")])
        withStore(CitationStore(certifiers: [entry])) {
            XCTAssertEqual(StandardSatisfaction.evaluate(body: .hmc, against: .zabiha), .meetsYourStandard)
            // A different pairing on the same body is still pending.
            XCTAssertEqual(StandardSatisfaction.evaluate(body: .hmc, against: .hanafiStrict), .pendingCitation)
        }
    }

    /// A body that doesn't draft-satisfy the standard reads as looser, regardless.
    func testNonSatisfyingBodyIsLooser() {
        withStore(CitationStore(certifiers: [])) {
            // IFANCA does not satisfy zabiha in the draft map.
            XCTAssertEqual(StandardSatisfaction.evaluate(body: .ifanca, against: .zabiha), .looserThanYours)
        }
    }

    func testNoBodyIsUnknown() {
        XCTAssertEqual(StandardSatisfaction.evaluate(body: nil, against: .general), .unknown)
    }
}
