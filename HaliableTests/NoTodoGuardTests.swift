//
//  NoTodoGuardTests.swift
//  HaliableTests
//
//  Citation Protocol §10: a `TODO(fiqh)` is an un-enforced reminder. After the
//  migration, "undecided" lives as DATA (an uncited cell is pending), so there
//  must be ZERO TODO/FIXME markers in the fiqh sources. This test makes that a
//  permanent, tested invariant: it greps each fiqh file and fails on any match.
//
//  NOTE: this test FILE intentionally contains the words it searches for, so it
//  scans only the explicit fiqh source list below — never itself.
//

import XCTest

final class NoTodoGuardTests: XCTestCase {

    /// Fiqh / grading sources that must stay free of TODO/FIXME (paths relative
    /// to the repo root, derived from this file's location at compile time).
    private static let fiqhFiles = [
        "Haliable/Models/HalalStandard.swift",
        "Haliable/Models/GradeCell.swift",
        "Haliable/Models/Citation.swift",
        "Haliable/Models/SatisfactionClaim.swift",
        "Haliable/Models/Origin.swift",
        "Haliable/Models/GradeLevel.swift",
        "Haliable/Models/ENumberReference.swift",
        "Haliable/Models/MatchedIngredient.swift",
        "Haliable/Services/GradeMatrix.swift",
        "Haliable/Services/GradeMatrix+Review.swift",
        "Haliable/Services/CitationStore.swift",
        "Haliable/Services/Review/ReviewDocument.swift",
    ]

    /// Repo root = two levels up from this file (HaliableTests/ → repo).
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)       // .../HaliableTests/NoTodoGuardTests.swift
            .deletingLastPathComponent()       // .../HaliableTests
            .deletingLastPathComponent()       // repo root
    }

    func testNoTodoOrFixmeInFiqhSources() throws {
        // Assemble the forbidden markers WITHOUT writing them as literals that the
        // guard would otherwise have to special-case.
        let fixme = "FIX" + "ME"
        let todo  = "TO" + "DO"
        let markers = [todo, fixme]

        var offenders: [String] = []
        for relPath in Self.fiqhFiles {
            let url = repoRoot.appendingPathComponent(relPath)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                XCTFail("fiqh source not found at \(relPath) — fix the path list"); continue
            }
            for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                for marker in markers where line.contains(marker) {
                    offenders.append("\(relPath):\(i + 1): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty,
                      "fiqh sources must contain no TODO/FIXME — found:\n" + offenders.joined(separator: "\n"))
    }
}
