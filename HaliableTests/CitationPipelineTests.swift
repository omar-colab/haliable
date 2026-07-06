//
//  CitationPipelineTests.swift
//  HaliableTests
//
//  Citation Pipeline — the on-disk runner (docs/citations/SPEC.md). Proves the
//  daily loop works end-to-end on real files: scaffold → (research) → review →
//  commit to Citations.json — without fabricating any source.
//

import XCTest
@testable import Haliable

final class CitationPipelineTests: XCTestCase {

    private var tmp: URL!
    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("citpipe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmp) }

    private func cite(_ name: String) -> Citation {
        Citation(sourceName: name, reference: "https://example.test/\(name)",
                 date: "2026-06-27", tier: .standardBody,
                 paraphrase: "Test: \(name) states a position.")
    }

    /// Scaffolding creates a skeleton per actionable item, skips blocked ones, and
    /// never clobbers an existing file on a second run.
    func testScaffoldCreatesAndDoesNotClobber() throws {
        let items = Array(CitationBacklog.items.prefix(6))
        let first = try CitationPipeline.scaffold(items, into: tmp)
        XCTAssertEqual(first.count, items.filter { !$0.blocked }.count)
        let second = try CitationPipeline.scaffold(items, into: tmp)
        XCTAssertTrue(second.isEmpty, "re-scaffolding must not overwrite in-progress research")
    }

    /// A staged skeleton (no sources) previews as "won't clear" in the review sheet.
    func testReviewSheetPreviewsGate() {
        let staged = CitationCandidate(
            target: CandidateTarget(kind: .cell, subject: "gelatin", origin: "plant", position: "general"),
            proposed: [])
        let sheet = CitationPipeline.reviewSheet([staged])
        XCTAssertTrue(sheet.contains("✗"), "an empty candidate must preview as won't-clear")
        XCTAssertTrue(sheet.contains("gelatin"))
    }

    /// Full disk loop: an approved valid candidate is committed and written to
    /// Citations.json; a staged one is left out; re-running is idempotent.
    func testCommitFromDiskWritesAndIsIdempotent() throws {
        let enc = JSONEncoder()
        let candidatesDir = tmp.appendingPathComponent("candidates")
        try FileManager.default.createDirectory(at: candidatesDir, withIntermediateDirectories: true)

        let approved = CitationCandidate(
            target: CandidateTarget(kind: .cell, subject: "gelatin", origin: "plant", position: "general"),
            proposed: [cite("JAKIM MS1500"), cite("IFANCA Standard")], decision: .approved)
        let staged = CitationCandidate(
            target: CandidateTarget(kind: .cell, subject: "whey", origin: "unspecified", position: "general"),
            proposed: [cite("Some Source")], decision: .staged)
        try enc.encode(approved).write(to: candidatesDir.appendingPathComponent("a.json"))
        try enc.encode(staged).write(to: candidatesDir.appendingPathComponent("b.json"))

        let citationsURL = tmp.appendingPathComponent("Citations.json")
        let run = try CitationPipeline.commitFromDisk(candidatesDir: candidatesDir, citationsURL: citationsURL)
        XCTAssertEqual(run.report.committed, 1)
        XCTAssertEqual(run.report.skipped, 1)

        let written = try XCTUnwrap(CitationStore.decode(Data(contentsOf: citationsURL)))
        XCTAssertEqual(written.cells.count, 1)

        // Idempotent: a second run produces byte-identical content.
        let before = try Data(contentsOf: citationsURL)
        _ = try CitationPipeline.commitFromDisk(candidatesDir: candidatesDir, citationsURL: citationsURL)
        XCTAssertEqual(try Data(contentsOf: citationsURL), before)
    }

    /// Live commit runner: load the REAL approved candidates and write the REAL
    /// Citations.json. Guarded by env so normal/CI runs never touch the bundle.
    ///   TEST_RUNNER_HALIABLE_COMMIT=1
    ///   TEST_RUNNER_HALIABLE_CANDIDATES_DIR=<repo>/docs/citations/candidates
    ///   TEST_RUNNER_HALIABLE_CITATIONS_JSON=<repo>/Haliable/Resources/Citations.json
    ///   TEST_RUNNER_HALIABLE_AUDIT_PATH=<repo>/docs/citations/commit-audit.md (optional)
    func testLiveCommitWhenRequested() throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(env["HALIABLE_COMMIT"] == "1", "set HALIABLE_COMMIT=1 to write the real Citations.json")
        let candDir = URL(fileURLWithPath: try XCTUnwrap(env["HALIABLE_CANDIDATES_DIR"]))
        let jsonURL = URL(fileURLWithPath: try XCTUnwrap(env["HALIABLE_CITATIONS_JSON"]))
        let run = try CitationPipeline.commitFromDisk(candidatesDir: candDir, citationsURL: jsonURL)
        let audit = CitationPipeline.auditLog(run.report)
        if let auditPath = env["HALIABLE_AUDIT_PATH"] {
            try audit.write(toFile: auditPath, atomically: true, encoding: .utf8)
        }
        print(audit)
        print("Committed \(run.report.committed) → \(jsonURL.path)")
    }
}
