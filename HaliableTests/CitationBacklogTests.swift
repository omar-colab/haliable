//
//  CitationBacklogTests.swift
//  HaliableTests
//
//  Citation Pipeline — Component 1 guarantee (docs/citations/SPEC.md §3.1): the
//  backlog must enumerate EXACTLY what the live engine grades on, so the worklist
//  can never drift from the matrix. Plus the dev writers for backlog.json /
//  backlog.md / progress.md (guarded by env so normal/CI runs never write).
//

import XCTest
@testable import Haliable

final class CitationBacklogTests: XCTestCase {

    /// Cell items cover every seeded cell, keyed exactly as CitationStore keys it.
    func testCellItemsMatchEverySeededCell() {
        let expected = Set(GradeMatrix.allSeededEntries.map {
            CitationStore.cellKey(subject: $0.subject.reviewLabel,
                                  origin: $0.origin.rawValue,
                                  position: $0.standard.rawValue)
        })
        let actual = CitationBacklog.cellItems.map(\.key)
        XCTAssertEqual(actual.count, Set(actual).count, "no duplicate cell items")
        XCTAssertEqual(Set(actual), expected, "backlog cells must equal the live seeded cells")
    }

    /// Certifier items = exactly the POSITIVE draft satisfaction claims.
    func testCertifierItemsMatchPositiveClaims() {
        let order: [HalalStandard] = [.zabiha, .hanafiStrict, .general, .lenient]
        var expected: Set<String> = []
        for body in CertificationBody.allCases {
            for std in order where SatisfactionClaim.make(body: body, standard: std).draftSatisfies {
                expected.insert(CitationStore.certKey(body: body.rawValue, position: std.rawValue))
            }
        }
        XCTAssertEqual(Set(CitationBacklog.certifierItems.map(\.key)), expected)
        XCTAssertFalse(expected.isEmpty, "there should be positive certifier claims to cite")
    }

    /// sourcesNeeded mirrors the real two-source rule (high-traffic OR lenient → 2).
    func testSourcesNeededMatchesGate() {
        for item in CitationBacklog.cellItems {
            guard let e = GradeMatrix.allSeededEntries.first(where: {
                $0.subject.reviewLabel == item.subject
                    && $0.origin.rawValue == item.origin
                    && $0.standard.rawValue == item.position
            }) else { return XCTFail("no engine entry for \(item.key)") }
            XCTAssertEqual(item.sourcesNeeded, e.cell.requiresTwoSources ? 2 : 1, "wrong sourcesNeeded for \(item.key)")
        }
    }

    /// Blocked items are exactly the origin-undeterminable, draft-halal cells that
    /// can never clear to halal (§8.4) — e.g. beeswax E901 at unspecified origin.
    func testBlockedItemsAreUndeterminableHalal() {
        let blocked = CitationBacklog.cellItems.filter(\.blocked)
        XCTAssertFalse(blocked.isEmpty, "at least one undeterminable-halal cell should be blocked (E901)")
        for it in blocked {
            XCTAssertEqual(it.origin, "unspecified")
            XCTAssertEqual(it.draftGrade, GradeLevel.halal.rawValue, "blocked = draft-halal")
        }
        XCTAssertTrue(blocked.contains { $0.subject == "E901" }, "E901 unspecified should be blocked")
    }

    /// A backlog item reads "cited" IF AND ONLY IF the live engine actually clears
    /// that cell — so the worklist's status can't drift from real clearance state.
    func testCitedStatusMatchesLiveEngine() {
        let citedLive = Set(GradeMatrix.allSeededEntries
            .filter { $0.cell.citationStatus == .cited }
            .map { CitationStore.cellKey(subject: $0.subject.reviewLabel,
                                         origin: $0.origin.rawValue,
                                         position: $0.standard.rawValue) })
        let citedBacklog = Set(CitationBacklog.cellItems.filter { $0.status == "cited" }.map(\.key))
        XCTAssertEqual(citedBacklog, citedLive, "backlog cited-status must match the engine")
    }

    /// backlog.json round-trips and preserves the item count.
    func testJSONRoundTrips() throws {
        let data = try CitationBacklog.json()
        let snap = try JSONDecoder().decode(CitationBacklog.Snapshot.self, from: data)
        XCTAssertEqual(snap.items.count, CitationBacklog.items.count)
        XCTAssertEqual(snap.totalItems, snap.items.count)
    }

    /// Dev convenience: write backlog.json + backlog.md + progress.md. Skipped
    /// unless HALIABLE_WRITE_CITATIONS=1. Set HALIABLE_CITATIONS_DIR or defaults
    /// next to SRCROOT/docs/citations.
    func testWriteArtifactsWhenRequested() throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(env["HALIABLE_WRITE_CITATIONS"] == "1",
                          "set HALIABLE_WRITE_CITATIONS=1 to write backlog/ledger files")
        let dir = env["HALIABLE_CITATIONS_DIR"]
            ?? (env["SRCROOT"].map { $0 + "/docs/citations" })
            ?? FileManager.default.currentDirectoryPath + "/docs/citations"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try CitationBacklog.json().write(to: URL(fileURLWithPath: dir + "/backlog.json"))
        try CitationBacklog.indexMarkdown().write(toFile: dir + "/backlog.md", atomically: true, encoding: .utf8)
        try CitationLedger.markdown().write(toFile: dir + "/progress.md", atomically: true, encoding: .utf8)
        print("Wrote backlog.json, backlog.md, progress.md → \(dir)")
    }
}
